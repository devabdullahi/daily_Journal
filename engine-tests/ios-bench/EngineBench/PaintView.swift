import SwiftUI
import Darwin

/// Runs `easel run <args>` in-process; returns the engine's exit code (0 = ok).
func runEngine(_ args: [String]) -> Int32 {
    var cStrings = (["run"] + args).map { strdup($0) }
    defer { cStrings.forEach { free($0) } }
    let argv = cStrings.map { UnsafePointer($0) }
    return argv.withUnsafeBufferPointer { easel_run_c(Int32(argv.count), $0.baseAddress) }
}

@MainActor
final class Painter: ObservableObject {
    enum Phase: Equatable { case idle, reading, planning(attempt: Int), painting, done, failed(String) }

    @Published var phase: Phase = .idle
    @Published var frame: UIImage?
    @Published var progress = ""
    @Published var finalURL: URL?
    @Published var planText = ""

    private let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private lazy var errLog = docs.appendingPathComponent("paint-stderr.log")
    private var stderrRedirected = false

    @Published var reading = ""

    var busy: Bool {
        switch phase { case .reading, .planning, .painting: true; default: false }
    }

    /// On-device: the Apple model reads the entry, the tested template paints it.
    /// `scene`: "auto" lets the model pick the setting; otherwise it overrides it.
    func paintOnDevice(prompt: String, scene: String = "auto") {
        guard !busy else { return }
        let dir = prepare(prompt)
        Task {
            phase = .reading
            var r: Reading
            do { r = try await Reader.read(prompt) } catch {
                phase = .failed(error.localizedDescription); return
            }
            if let forced = Setting(rawValue: scene) { r.setting = forced }
            reading = "“\(r.title)” · " + Composer.summary(r)
            let plan = Composer.plan(for: r, entry: prompt)
            planText = plan
            let planURL = dir.appendingPathComponent("plan.lua")
            try? plan.write(to: planURL, atomically: true, encoding: .utf8)
            if let error = await runAndWatch(plan: planURL, in: dir, chunks: plan.components(separatedBy: "--@ chunk").count - 1) {
                phase = .failed("The engine stopped:\n\(error)"); return
            }
            finish(dir)
        }
    }

    private func finish(_ dir: URL) {
        finalURL = dir.appendingPathComponent("painting.png")
        if let img = UIImage(contentsOfFile: finalURL!.path) { frame = img }
        phase = .done
    }

    /// Fresh state and a folder for this painting (prompt saved in it).
    private func prepare(_ prompt: String) -> URL {
        if !stderrRedirected {
            // the engine reports errors on stderr: keep them to show and to send back for a fix
            freopen(errLog.path, "a", stderr)
            setvbuf(stderr, nil, _IOLBF, 0)
            stderrRedirected = true
        }
        frame = nil; finalURL = nil; progress = ""; planText = ""; reading = ""
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let dir = docs.appendingPathComponent("paintings/\(stamp)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? prompt.write(to: dir.appendingPathComponent("prompt.txt"), atomically: true, encoding: .utf8)
        return dir
    }

    /// Free-form: DeepSeek writes the whole Lua plan (fixes it from the engine's error, up to twice).
    func paint(prompt: String, apiKey: String, model: String) {
        guard !busy else { return }
        let dir = prepare(prompt)
        let writer = PlanWriter(apiKey: apiKey, model: model)

        Task {
            var messages: [[String: String]] = [["role": "user", "content": "Paint this:\n\n\(prompt)"]]
            // up to 3 plans: the first, then two fixes from the engine's error
            for attempt in 1...3 {
                phase = .planning(attempt: attempt)
                let plan: String
                do { plan = try await writer.write(messages) } catch {
                    phase = .failed(error.localizedDescription); return
                }
                planText = plan
                let planURL = dir.appendingPathComponent("plan.lua")
                try? plan.write(to: planURL, atomically: true, encoding: .utf8)
                let error = await runAndWatch(plan: planURL, in: dir, chunks: plan.components(separatedBy: "--@ chunk").count - 1)
                guard let error else { finish(dir); return }
                if attempt == 3 { phase = .failed("The engine rejected the plan:\n\(error)"); return }
                messages.append(["role": "assistant", "content": "```lua\n\(plan)```"])
                messages.append(["role": "user", "content": "The engine stopped with this error. Send the whole corrected plan, same rules:\n\n\(error)"])
            }
        }
    }

    /// Paints the plan, showing the newest frame as it's written. Returns the engine's error, or nil.
    private func runAndWatch(plan: URL, in dir: URL, chunks: Int) async -> String? {
        phase = .painting
        let frames = dir.appendingPathComponent("frames")
        try? FileManager.default.removeItem(at: frames)
        let out = dir.appendingPathComponent("painting.png")
        try? FileManager.default.removeItem(at: out)
        let logStart = (try? FileManager.default.attributesOfItem(atPath: errLog.path)[.size] as? Int) ?? 0
        let args = [plan.path, "--out", out.path, "--width", "512",
                    "--frames-every", "20", "--frames-dir", frames.path, "--frame-width", "512"]
        let started = Date()
        let watcher = Task { @MainActor in
            var shown = ""
            while !Task.isCancelled {
                if let names = try? FileManager.default.contentsOfDirectory(atPath: frames.path) {
                    let pngs = names.filter { $0.hasSuffix(".png") && Int($0.dropLast(4)) != nil }.sorted()
                    if let last = pngs.last, last != shown,
                       let img = UIImage(contentsOfFile: frames.appendingPathComponent(last).path) {
                        frame = img; shown = last
                    }
                }
                let done = (try? String(contentsOf: frames.appendingPathComponent("frames.tsv"), encoding: .utf8))?
                    .split(separator: "\n").last?.split(separator: "\t").dropFirst(3).first.flatMap { Int($0) } ?? 0
                progress = String(format: "chunk %d of %d · %.0f s", min(done + 1, chunks), chunks, Date().timeIntervalSince(started))
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
        let code = await Task.detached(priority: .userInitiated) { runEngine(args) }.value
        watcher.cancel()
        progress = String(format: "painted in %.0f s", Date().timeIntervalSince(started))
        if code == 0 { return nil }
        // the engine's own words since this run started
        let data = (try? Data(contentsOf: errLog)) ?? Data()
        let text = String(decoding: data.dropFirst(logStart), as: UTF8.self)
        let lines = text.split(separator: "\n").filter { !$0.hasPrefix("replay ") && !$0.hasPrefix("  chunk ") }
        return lines.suffix(25).joined(separator: "\n")
    }
}

struct PaintView: View {
    @StateObject private var painter = Painter()
    @State private var prompt = ""
    @State private var apiKey = Keychain.read("deepseek-key") ?? ""
    @AppStorage("deepseek-model") private var model = "deepseek-v4-pro"
    /// "apple": on-device reading + tested template; "deepseek": free-form plan from DeepSeek
    @AppStorage("planner") private var planner = "apple"
    private var needsKey: Bool { planner == "deepseek" && apiKey.isEmpty }
    @State private var showSettings = false
    @State private var showPlan = false
    @AppStorage("scene") private var scene = "auto"
    // the user's painter (set at random on first launch by PainterStyle.ensure)
    @AppStorage("style-brush") private var styleBrush = "lively"
    @AppStorage("style-temper") private var styleTemper = "neutral"
    @AppStorage("style-light") private var styleLight = "natural"
    @AppStorage("style-ground") private var styleGround = "white"
    init() { PainterStyle.ensure() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    canvas
                    status
                    if planner == "apple" {
                        Picker("Scene", selection: $scene) {
                            Text("Auto").tag("auto")
                            ForEach(Setting.allCases, id: \.self) { Text("\($0.rawValue.capitalized)").tag($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                        .disabled(painter.busy)
                    }
                    TextField("What should it paint? e.g. a rainy walk home, the sky was orange", text: $prompt, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                        .disabled(painter.busy)
                    Button {
                        if planner == "apple" { painter.paintOnDevice(prompt: prompt, scene: scene) }
                        else { painter.paint(prompt: prompt, apiKey: apiKey, model: model) }
                    } label: {
                        Label(painter.busy ? "Painting…" : "Paint", systemImage: "paintbrush.pointed.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(painter.busy || prompt.trimmingCharacters(in: .whitespaces).isEmpty || needsKey)
                    if needsKey {
                        Text("Add your DeepSeek API key in Settings first.").font(.footnote).foregroundStyle(.secondary)
                    }
                    if !painter.planText.isEmpty {
                        DisclosureGroup("Plan", isExpanded: $showPlan) {
                            Text(painter.planText).font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Easel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                if let url = painter.finalURL {
                    ToolbarItem(placement: .topBarLeading) { ShareLink(item: url) }
                }
            }
            .sheet(isPresented: $showSettings) { settings }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }

    private var canvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground))
            if let img = painter.frame {
                Image(uiImage: img).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "paintpalette").font(.system(size: 48)).foregroundStyle(.tertiary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder private var status: some View {
        switch painter.phase {
        case .idle: EmptyView()
        case .reading:
            Label("Reading your entry…", systemImage: "text.magnifyingglass").foregroundStyle(.secondary)
        case .planning(let attempt):
            Label(attempt == 1 ? "Planning the painting…" : "Fixing the plan (try \(attempt))…", systemImage: "text.badge.star")
                .foregroundStyle(.secondary)
        case .painting:
            if !painter.reading.isEmpty { Text(painter.reading).font(.footnote) }
            Label(painter.progress.isEmpty ? "Painting…" : painter.progress, systemImage: "paintbrush")
                .foregroundStyle(.secondary).monospacedDigit()
            Text("Keep the app open while it paints.").font(.footnote).foregroundStyle(.tertiary)
        case .done:
            if !painter.reading.isEmpty { Text(painter.reading).font(.footnote) }
            Label(painter.progress, systemImage: "checkmark.circle").foregroundStyle(.green)
        case .failed(let message):
            Text(message).font(.footnote).foregroundStyle(.red).textSelection(.enabled)
        }
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Planner", selection: $planner) {
                        Text("Apple, on this iPhone").tag("apple")
                        Text("DeepSeek, free-form").tag("deepseek")
                    }
                } footer: {
                    Text(planner == "apple"
                         ? "The on-device Apple model reads your entry (mood, time, weather, place) and a tested template paints it. Nothing leaves the phone."
                         : "DeepSeek writes the whole paint plan. More varied, less reliable; your text is sent to DeepSeek.")
                }
                Section {
                    Picker("Brushwork", selection: $styleBrush) {
                        Text("Smooth, blended").tag("smooth"); Text("Lively").tag("lively"); Text("Bold, broken colour").tag("bold")
                    }
                    Picker("Palette", selection: $styleTemper) {
                        Text("Warm").tag("warm"); Text("Neutral").tag("neutral"); Text("Cool").tag("cool")
                    }
                    Picker("Light", selection: $styleLight) {
                        Text("Bright").tag("high"); Text("Natural").tag("natural"); Text("Dark").tag("low")
                    }
                    Picker("Canvas tone", selection: $styleGround) {
                        Text("White").tag("white"); Text("Ochre").tag("ochre"); Text("Red earth").tag("red")
                    }
                } header: { Text("Your painter") } footer: {
                    Text("Chosen at random when you first opened the app, so your paintings have their own hand. Change it any time; every painting uses it.")
                }
                Section {
                    SecureField("sk-…", text: $apiKey).textContentType(.password).autocorrectionDisabled()
                } header: { Text("DeepSeek API key") } footer: {
                    Text("Stored in this iPhone's Keychain. Your prompts are sent to DeepSeek to write the paint plan; the painting itself is made on this phone.")
                }
                Section("Model") {
                    TextField("deepseek-v4-pro", text: $model).autocorrectionDisabled().textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        Keychain.save(apiKey, for: "deepseek-key")
                        showSettings = false
                    }
                }
            }
        }
    }
}
