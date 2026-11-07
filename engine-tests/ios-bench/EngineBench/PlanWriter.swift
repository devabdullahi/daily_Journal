import Foundation

/// Asks DeepSeek (OpenAI-compatible chat completions) to write an easel Lua plan for a prompt.
struct PlanWriter {
    let apiKey: String
    let model: String

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static func resource(_ name: String, _ ext: String) -> String {
        guard let path = Bundle.main.path(forResource: name, ofType: ext, inDirectory: "Plans"),
              let text = try? String(contentsOfFile: path, encoding: .utf8) else { return "" }
        return text
    }

    /// The engine-9 header every plan must start with (taken from the tested example).
    static let header: String = resource("v7_park_icecream", "lua")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .prefix { $0.hasPrefix("--@ ") && !$0.hasPrefix("--@ chunk") }
        .joined(separator: "\n")

    static let systemPrompt: String = """
    You paint oil paintings with "the easel", a physical oil-paint simulator driven by Lua. \
    You get a short text (a journal entry or an idea) and answer with ONE complete Lua plan that paints it.

    Hard rules:
    1. Answer with the plan only, inside a single ```lua code block. No other text.
    2. The plan starts with exactly these header lines, unchanged:
    \(header)
    3. Then a few `--` comment lines: the entry, your reading of its mood, the strongest image, the composition.
    4. Split the plan into chunks with `--@ chunk` lines, 6 to 10 chunks. The first chunk is only the `canvas{...}` call, \
    with size=300, aspect=1 (copy the example's canvas call, change only the seed and ground colour).
    5. Coordinates are 0..1000 on both axes, y down. Use only the functions, hands, options and tube names the guide documents. \
    Tube names must match the tube box exactly.
    6. Keep the amount of painting close to the examples (similar number of `work` calls, coverage and stroke lengths): \
    the painting must finish in about 30 seconds on a phone.
    7. Paint big shapes first (sky/background, ground), then the main subject, then a few accents. \
    Reserve the main subject's shape so background paint doesn't muddy it (as the example does).
    8. Follow the colour rules. No text, letters or numbers in the painting.

    # Colour rules
    \(resource("color_rules", "md"))

    # Example plan 1 (tested, paints well)
    ```lua
    \(resource("v7_park_icecream", "lua"))
    ```

    # Example plan 2 (tested, paints well)
    ```lua
    \(resource("bench_v3c", "lua"))
    ```

    # The easel guide
    \(resource("easel_guide", "md"))
    """

    /// One call: the conversation so far (user prompt, maybe a failed plan and its error) to a plan.
    func write(_ messages: [[String: String]]) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "system", "content": Self.systemPrompt]] + messages,
            "max_tokens": 8000,
            "stream": false,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw Failure(message: "DeepSeek HTTP \(status): \(text.prefix(400))")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw Failure(message: "DeepSeek: unexpected response")
        }
        return Self.extractPlan(content)
    }

    /// The Lua inside the reply's code block, with the engine-9 header guaranteed.
    static func extractPlan(_ reply: String) -> String {
        var plan = reply
        if let start = reply.range(of: "```lua") ?? reply.range(of: "```") {
            let rest = reply[start.upperBound...]
            let end = rest.range(of: "```")?.lowerBound ?? rest.endIndex
            plan = String(rest[..<end])
        }
        plan = plan.trimmingCharacters(in: .whitespacesAndNewlines)
        if !plan.hasPrefix("--@ engine") {
            plan = header + "\n" + plan
        }
        return plan + "\n"
    }
}
