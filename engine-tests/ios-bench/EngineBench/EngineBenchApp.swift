import SwiftUI
import Darwin

struct BenchResult: Identifiable {
    let id = UUID()
    let name: String
    let seconds: Double
    let peakMB: Double
    let thermal: String
    let ok: Bool
}

func peakMemoryMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return kr == KERN_SUCCESS ? Double(info.ledger_phys_footprint_peak) / 1_048_576 : -1
}

func machineName() -> String {
    var size = 0
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var buf = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.machine", &buf, &size, nil, 0)
    return String(cString: buf)
}

func thermalName() -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: "nominal"
    case .fair: "fair"
    case .serious: "serious"
    case .critical: "critical"
    @unknown default: "unknown"
    }
}

func runPlan(_ plan: String, width: Int, out: URL) -> Bool {
    let path = Bundle.main.path(forResource: plan, ofType: "lua", inDirectory: "Plans")!
    let args = ["run", path, "--out", out.path, "--width", String(width)]
    var cStrings = args.map { strdup($0) }
    defer { cStrings.forEach { free($0) } }
    let argv = cStrings.map { UnsafePointer($0) }
    return argv.withUnsafeBufferPointer { easel_run_c(Int32(args.count), $0.baseAddress) } == 0
}

/// One line per thread: name, current/base Mach priority (QoS band), cumulative user+system CPU seconds.
func threadSnapshot() -> [String] {
    var list: thread_act_array_t?
    var count: mach_msg_type_number_t = 0
    guard task_threads(mach_task_self_, &list, &count) == KERN_SUCCESS, let threads = list else { return [] }
    defer {
        for i in 0..<Int(count) { mach_port_deallocate(mach_task_self_, threads[i]) }
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threads)), vm_size_t(Int(count) * MemoryLayout<thread_t>.size))
    }
    var out: [String] = []
    for i in 0..<Int(count) {
        var info = thread_extended_info_data_t()
        var n = mach_msg_type_number_t(MemoryLayout<thread_extended_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(n)) {
                thread_info(threads[i], thread_flavor_t(THREAD_EXTENDED_INFO), $0, &n)
            }
        }
        guard kr == KERN_SUCCESS else { continue }
        let name = withUnsafeBytes(of: info.pth_name) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        let cpu = Double(info.pth_user_time + info.pth_system_time) / 1e9
        out.append(String(format: "%@|cur=%d|base=%d|cpu=%.2f|run=%d", name.isEmpty ? "t\(i)" : name, info.pth_curpri, info.pth_priority, cpu, info.pth_run_state))
    }
    return out
}

@MainActor
final class Bench: ObservableObject {
    @Published var results: [BenchResult] = []
    @Published var status = "starting"
    @Published var image: UIImage?

    func start() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // Launch environment: BENCH_LABEL names the log files; BENCH_PLANS="a,b" and
        // BENCH_REPS=N pick the jobs (default: parity run P0, both plans x3, interleaved).
        // EASEL_THREADS / EASEL_QOS are read by the engine itself.
        let env = ProcessInfo.processInfo.environment
        let label = env["BENCH_LABEL"] ?? "P0"
        let plans = (env["BENCH_PLANS"] ?? "v7_park_icecream,bench_v3c").split(separator: ",").map(String.init)
        let reps = Int(env["BENCH_REPS"] ?? "3") ?? 3
        let jobs: [(String, Int, Int)] = (1...reps).flatMap { rep in plans.map { ($0, 512, rep) } }
        // Per-chunk timings go to stderr; keep them in Documents.
        freopen(docs.appendingPathComponent("stderr-\(label).log").path, "a", stderr)
        setvbuf(stderr, nil, _IOLBF, 0)
        // Sample every thread once a second: priority (QoS band) and CPU time.
        let sampleURL = docs.appendingPathComponent("threads-\(label).log")
        FileManager.default.createFile(atPath: sampleURL.path, contents: nil)
        let sampler = Thread {
            let h = try! FileHandle(forWritingTo: sampleURL)
            let start = Date()
            while true {
                let t = Date().timeIntervalSince(start)
                let block = threadSnapshot().map { String(format: "%.1f %@ %@", t, thermalName(), $0) }.joined(separator: "\n") + "\n"
                h.write(block.data(using: .utf8)!)
                Thread.sleep(forTimeInterval: 1)
            }
        }
        sampler.name = "bench-sampler"
        sampler.start()
        Task.detached(priority: .userInitiated) {
            var lines = ["device=\(machineName()) cores=\(ProcessInfo.processInfo.activeProcessorCount) callerQoS=\(qos_class_self().rawValue) label=\(label) EASEL_THREADS=\(env["EASEL_THREADS"] ?? "-") EASEL_QOS=\(env["EASEL_QOS"] ?? "-")"]
            for (plan, width, rep) in jobs {
                let name = "\(plan)-\(width)-r\(rep)"
                await MainActor.run { self.status = "painting \(name)…" }
                fputs("=== \(name) start thermal=\(thermalName())\n", stderr)
                let out = docs.appendingPathComponent("\(name).png")
                let t0 = Date()
                let ok = runPlan(plan, width: width, out: out)
                let r = BenchResult(name: name, seconds: Date().timeIntervalSince(t0), peakMB: peakMemoryMB(), thermal: thermalName(), ok: ok)
                fputs("=== \(name) end seconds=\(r.seconds) thermal=\(r.thermal)\n", stderr)
                let line = String(format: "%@ ok=%@ seconds=%.2f peakMB=%.0f thermal=%@", name, ok ? "true" : "false", r.seconds, r.peakMB, r.thermal)
                print("BENCH \(line)")
                lines.append(line)
                try? lines.joined(separator: "\n").write(to: docs.appendingPathComponent("results-\(label).txt"), atomically: true, encoding: .utf8)
                await MainActor.run {
                    self.results.append(r)
                    self.image = UIImage(contentsOfFile: out.path)
                }
            }
            print("BENCH done"); exit(0)
            await MainActor.run { self.status = "done" }
        }
    }
}

@main
struct EngineBenchApp: App {
    /// Launched with BENCH_LABEL (devicectl / xctrace): the benchmark. Otherwise: paint from a prompt.
    private let benchMode = ProcessInfo.processInfo.environment["BENCH_LABEL"] != nil
    var body: some Scene {
        WindowGroup {
            if benchMode { BenchView() } else { PaintView() }
        }
    }
}

struct BenchView: View {
    @StateObject private var bench = Bench()
    var body: some View {
            VStack(spacing: 12) {
                Text("Engine bench").font(.headline)
                Text(bench.status).foregroundStyle(.secondary)
                if let img = bench.image {
                    Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 360)
                }
                ForEach(bench.results) { r in
                    Text(String(format: "%@  %.2f s  %.0f MB  %@", r.name, r.seconds, r.peakMB, r.thermal))
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding()
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                bench.start()
            }
    }
}
