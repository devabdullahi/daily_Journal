import Foundation
import FoundationModels

// What the on-device Apple model reads from an entry: only choices the
// landscape template knows how to paint (guided generation guarantees it).

@Generable enum Setting: String, CaseIterable { case meadow, hills, sea, city }
@Generable enum TimeOfDay { case dawn, morning, midday, afternoon, sunset, dusk, night }
@Generable enum Weather { case clear, cloudy, rain, fog, snow }
@Generable enum Subject { case none, tree, house, figure, boat, flowers }
@Generable enum Side { case left, center, right }
@Generable enum Mood { case joyful, hopeful, calm, tense, tired, melancholy }
@Generable enum Season { case spring, summer, autumn, winter }
@Generable enum Accent { case none, red, orange, yellow, green, blue, purple, pink, white, brown }

@Generable(description: "How a journal entry should be painted as one small landscape in oil")
struct Reading {
    @Guide(description: "The entry's main feeling.")
    var mood: Mood
    @Guide(description: "Where to set the scene. city: downtown, streets, shops, offices, school, campus, commuting, buses, anywhere in a town. meadow: parks, gardens, fields, open green places. hills: walks, countryside, mountains, travel. sea: beach, lake, river, water, boats.")
    var setting: Setting
    @Guide(description: "Time of day the entry mentions; if none, the one that best carries the mood (joy: morning or afternoon, calm: afternoon or sunset, sadness or tiredness: dusk or night, hope: dawn).")
    var time: TimeOfDay
    @Guide(description: "Weather the entry mentions; if none, the one that best carries the mood (sad or tired: rain or fog, joyful: clear).")
    var weather: Weather
    @Guide(description: "One thing in the scene that stands for the entry. figure: the writer or another person. house: home, family, rest. tree: growth, steadiness, nature. flowers: joy, love, a small good thing. boat: travel, leaving, freedom (only by the sea). none: an empty, open landscape.")
    var subject: Subject
    @Guide(description: "Where the subject stands in the picture.")
    var side: Side
    @Guide(description: "Season the entry mentions or suggests (cold, falling leaves, blossom, heat); if none, the one that best carries the mood.")
    var season: Season
    @Guide(description: "A colour the entry names for something in it (a red coat, an orange sky, yellow flowers); none if it names no colour.")
    var accent: Accent
    @Guide(description: "How many people to paint when the subject is figure: the writer alone 1, with a friend 2, a group 3.", .range(1...3))
    var people: Int
    @Guide(description: "True if the entry involves walking, a journey, a road or going somewhere.")
    var path: Bool
    @Guide(description: "True if the entry mentions birds, freedom, lightness or flying.")
    var birds: Bool
    @Guide(description: "A title for the painting, 2 to 5 words, no quotes.")
    var title: String
}

enum ReadingError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        switch self { case .unavailable(let why): "Apple Intelligence isn't available: \(why)" }
    }
}

enum Reader {
    static let instructions = """
    You read a short journal entry and choose how to paint it as a small oil landscape. \
    Pick what fits the entry's feelings and anything it says about time, weather or place. \
    Never invent sad details for a happy entry or happy ones for a sad entry.
    """

    static func read(_ entry: String) async throws -> Reading {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw ReadingError.unavailable(String(describing: model.availability))
        }
        let session = LanguageModelSession(model: model, instructions: instructions)
        return try await session.respond(to: entry, generating: Reading.self).content
    }
}

enum Composer {
    private static func resource(_ name: String) -> String {
        guard let path = Bundle.main.path(forResource: name, ofType: "lua", inDirectory: "Plans"),
              let text = try? String(contentsOfFile: path, encoding: .utf8) else { return "" }
        return text
    }

    /// A stable seed from the entry's text (FNV-1a), so the same entry paints the same way.
    static func seed(_ text: String) -> Int {
        var h: UInt32 = 2166136261
        for b in text.utf8 { h = (h ^ UInt32(b)) &* 16777619 }
        return Int(h % 997) + 1
    }

    /// Header + parameters + the tested template. The entry goes in a comment only, on one line.
    static func plan(for r: Reading, entry: String) -> String {
        let oneLine = entry.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        let people = max(1, min(3, r.people))
        let params = "P = {setting=\"\(r.setting)\", time=\"\(r.time)\", weather=\"\(r.weather)\", season=\"\(r.season)\", "
            + "subject=\"\(r.subject)\", side=\"\(r.side)\", people=\(people), accent=\"\(r.accent)\", "
            + "path=\(r.path), birds=\(r.birds), mood=\"\(r.mood)\", seed=\(seed(entry))}"
        let title = r.title.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        return PlanWriter.header + "\n--@ chunk\n-- Entry: \(oneLine)\n-- Title: \(title)\n"
            + PainterStyle.lua + "\n" + params + "\n" + resource("template_landscape")
    }

    static func summary(_ r: Reading) -> String {
        var parts = ["\(r.mood)", "\(r.season) \(r.time)", "\(r.weather)", "\(r.setting)"]
        switch r.subject {
        case .none: parts.append("open landscape")
        case .figure where r.people > 1: parts.append("\(r.people) people, \(r.side)")
        default: parts.append("\(r.subject), \(r.side)")
        }
        if r.accent != .none { parts.append("\(r.accent)") }
        if r.path { parts.append("path") }
        if r.birds { parts.append("birds") }
        return parts.joined(separator: " · ")
    }
}

/// The user's own painter: picked at random on first launch (each install paints differently),
/// changeable in Settings. The same for every painting, so a user's paintings read as one body of work.
enum PainterStyle {
    static let brushes = ["smooth", "lively", "bold"]
    static let tempers = ["warm", "neutral", "cool"]
    static let lights = ["high", "natural", "low"]
    static let grounds = ["white", "ochre", "red"]

    /// Creates the random painter the first time; the keys are the Settings pickers' @AppStorage keys.
    static func ensure() {
        let d = UserDefaults.standard
        guard d.string(forKey: "style-brush") == nil else { return }
        d.set(brushes.randomElement()!, forKey: "style-brush")
        d.set(tempers.randomElement()!, forKey: "style-temper")
        d.set(lights.randomElement()!, forKey: "style-light")
        d.set(grounds.randomElement()!, forKey: "style-ground")
    }

    static var lua: String {
        ensure()
        let d = UserDefaults.standard
        let v = { (k: String) in d.string(forKey: "style-\(k)") ?? "" }
        return "STYLE = {brush=\"\(v("brush"))\", temper=\"\(v("temper"))\", light=\"\(v("light"))\", ground=\"\(v("ground"))\"}"
    }
}
