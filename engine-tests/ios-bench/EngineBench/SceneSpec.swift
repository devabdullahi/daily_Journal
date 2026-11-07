import Foundation
import FoundationModels

// The scene a language model composes from a journal entry: the place and
// everything in it are its own words; the structure (shapes, positions, sizes,
// paint colours) is what our scene compiler (Plans/scene_compiler.lua) paints.
// Shared by the app and the Mac test tool.

@Generable enum PaintColor: String {
    case white, cream, yellow, gold, orange, red, darkRed, pink, purple
    case blue, skyBlue, navy, green, darkGreen, brown, tan, grey, darkGrey, black
}

/// What kind of thing an element is: the scene compiler builds and places each kind its own way.
@Generable enum Kind: String {
    case person, animal, tree, plant, building, vehicle, furniture, food, drink, object, screen, lamp, window, mountain, sun, moon
}
@Generable enum Role: String {
    /// main: the subject, large and near. beside: next to the main subject. behind: in the distance or on the back wall.
    case main, beside, behind
}
@Generable enum Size: String { case small, medium, large }
@Generable enum LightFrom: String { case left, right, above, front }
@Generable enum DayTime: String { case dawn, morning, midday, afternoon, sunset, dusk, night }
@Generable enum Sky: String { case clear, cloudy, rain, fog, snow }
@Generable enum Feeling: String { case joyful, hopeful, calm, tense, tired, melancholy }
@Generable enum Surface: String {
    /// what the ground or floor is
    case grass, water, sand, road, snow, wood, tiles, carpet, stone
}

@Generable(description: "One visible thing in the picture (not weather, not light, not a feeling)")
struct Element {
    @Guide(description: "What it is, in the entry's own words, 1-4 words.")
    var name: String
    @Guide(description: "What kind of thing it is.")
    var kind: Kind
    @Guide(description: "Exactly one element is main: the thing the entry is about.")
    var role: Role
    var size: Size
    @Guide(description: "Its main colour.")
    var color: PaintColor
    @Guide(description: "A second colour: trousers, a cup's contents, a cone's scoop, a screen's glow, a roof, a mountain's snow.")
    var second: PaintColor
    @Guide(description: "How many of it, 1 to 3 (e.g. 'with friends' = 3 people).", .range(1...3))
    var count: Int
}

@Generable(description: "A small oil painting of a journal entry")
struct SceneSpec {
    @Guide(description: "A title, 2-5 words.")
    var title: String
    @Guide(description: "Where this entry happens, in its own words, up to 8 words. Read it from this entry only.")
    var place: String
    @Guide(description: "True if the scene is inside a room or building.")
    var indoor: Bool
    @Guide(description: "Colour of the sky (outdoors) or the back wall (indoors).")
    var upper: PaintColor
    @Guide(description: "Colour of the ground (outdoors) or the floor (indoors).")
    var lower: PaintColor
    @Guide(description: "What the ground or floor is.")
    var surface: Surface
    var time: DayTime
    var weather: Sky
    var feeling: Feeling
    @Guide(description: "Where the main light comes from.")
    var light: LightFrom
    @Guide(description: "1 to 5 visible things from the entry: the main one first, then what is beside it, then what is behind.", .count(1...5))
    var elements: [Element]
}

enum SceneLua {
    /// A Lua string literal (quotes, backslashes and line breaks escaped).
    static func str(_ s: String) -> String {
        var out = "\""
        for c in s.unicodeScalars {
            switch c {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n", "\r": out += " "
            default: out.unicodeScalars.append(c)
            }
        }
        return out + "\""
    }

    /// The scene as a Lua table `SCENE = {...}` for the compiler.
    static func table(_ s: SceneSpec, seed: Int) -> String {
        var t = "SCENE = {title=\(str(s.title)), place=\(str(s.place)), indoor=\(s.indoor), "
        t += "upper=\"\(s.upper.rawValue)\", lower=\"\(s.lower.rawValue)\", surface=\"\(s.surface.rawValue)\", "
        t += "time=\"\(s.time.rawValue)\", weather=\"\(s.weather.rawValue)\", feeling=\"\(s.feeling.rawValue)\", "
        t += "light=\"\(s.light.rawValue)\", seed=\(seed), elements={\n"
        for e in s.elements.prefix(5) {
            t += "  {name=\(str(e.name)), kind=\"\(e.kind.rawValue)\", role=\"\(e.role.rawValue)\", size=\"\(e.size.rawValue)\", "
            t += "color=\"\(e.color.rawValue)\", second=\"\(e.second.rawValue)\", count=\(max(1, min(3, e.count)))},\n"
        }
        return t + "}}"
    }

    static let instructions = """
    You read a journal entry and say what a painting of it should show: the place, and the visible things \
    in it, in the entry's own words. Use the entry's own place and things; never swap them for something \
    generic. If it gives no place, choose one that carries its feeling. List only things you could see \
    (people, animals, objects, buildings), not weather, light, sounds or feelings. The main element is \
    what the entry is most about.
    """
}
// Stage 2 (agreed with Codex, 2026-11-01): the model draws one thing as simple flat
// shapes inside its own box; the compiler places the box and paints the parts.

@Generable enum PartShape: String {
    /// circle: round things (heads, wheels, balls). oval: stretched round things (bodies, leaves).
    /// box: rectangles (bodies, doors, screens, legs). triangle: pointed things (roofs, noses, ears, cones), point up.
    /// line: thin things (arms, poles, handles, tails, branches).
    case circle, oval, box, triangle, line
}

@Generable(description: "One flat shape of the drawing")
struct Part {
    @Guide(description: "Which part it is, 1-3 words.")
    var name: String
    var shape: PartShape
    @Guide(description: "Centre across the box: 0 = left, 100 = right.", .range(0...100))
    var x: Int
    @Guide(description: "Centre down the box: 0 = top, 100 = bottom (where it stands).", .range(0...100))
    var y: Int
    @Guide(description: "Width as a percent of the box width.", .range(2...100))
    var width: Int
    @Guide(description: "Height as a percent of the box height.", .range(2...100))
    var height: Int
    @Guide(description: "Tilt in degrees, 0 = upright.", .range(-90...90))
    var tilt: Int
    var color: PaintColor
}

@Generable(description: "A simple picture of one thing, made of flat shapes like cut paper")
struct Drawing {
    @Guide(description: "The thing's width as a percent of its height (a person ~40, a car ~220, a mug ~90).", .range(15...400))
    var widthPercent: Int
    @Guide(description: "6 to 12 shapes, back to front; together they fill the box from top (0) to bottom (100).", .count(6...12))
    var parts: [Part]
}

enum DrawingCheck {
    /// Diagnostics on a 50x50 raster of the box: coverage (0-1), touches the ground (bottom 10%),
    /// separate pieces, parts larger than 4% of the box.
    struct Report { var coverage: Double; var grounded: Bool; var pieces: Int; var bigParts: Int
        /// agreed rejection: clearly unusable only
        var usable: Bool { coverage >= 0.05 && coverage <= 0.98 && bigParts >= 2 }
    }

    static func check(_ d: Drawing) -> Report {
        let n = 50
        var grid = [Bool](repeating: false, count: n * n)
        var big = 0
        for p in d.parts {
            if Double(p.width * p.height) / 10000 > 0.04 { big += 1 }
            let cx = Double(p.x), cy = Double(p.y), w = Double(p.width), h = Double(p.height)
            let t = Double(p.tilt) * .pi / 180
            for gy in 0..<n { for gx in 0..<n {
                // the cell centre in box percent, rotated into the part's frame
                let px = (Double(gx) + 0.5) * 100 / Double(n) - cx, py = (Double(gy) + 0.5) * 100 / Double(n) - cy
                let u = px * cos(t) + py * sin(t), v = -px * sin(t) + py * cos(t)
                var inside = false
                switch p.shape {
                case .circle: let r = min(w, h) / 2; inside = u * u + v * v <= r * r
                case .oval: inside = (u * u) / max(1, w * w / 4) + (v * v) / max(1, h * h / 4) <= 1
                case .box, .line: inside = abs(u) <= w / 2 && abs(v) <= max(h, 2) / 2
                case .triangle: inside = v <= h / 2 && v >= -h / 2 && abs(u) <= (v + h / 2) / h * w / 2
                }
                if inside { grid[gy * n + gx] = true }
            } }
        }
        let filled = grid.filter { $0 }.count
        let grounded = (Int(Double(n) * 0.9)..<n).contains { gy in (0..<n).contains { grid[gy * n + $0] } }
        // connected pieces (4-neighbour)
        var seen = [Bool](repeating: false, count: n * n), pieces = 0
        for start in 0..<(n * n) where grid[start] && !seen[start] {
            pieces += 1
            var stack = [start]; seen[start] = true
            while let c = stack.popLast() {
                let x = c % n, y = c / n
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = x + dx, ny = y + dy
                    if nx >= 0, ny >= 0, nx < n, ny < n, grid[ny * n + nx], !seen[ny * n + nx] { seen[ny * n + nx] = true; stack.append(ny * n + nx) }
                }
            }
        }
        return Report(coverage: Double(filled) / Double(n * n), grounded: grounded, pieces: pieces, bigParts: big)
    }
}

enum DrawingLua {
    static let instructions = """
    You draw one thing as a few simple flat shapes, like a child's cut-paper picture, inside a box: \
    x from 0 (left) to 100 (right), y from 0 (top) to 100 (bottom, where it stands). \
    Big shapes first, details last. Shapes touch or overlap so the thing reads as one piece. \
    Use the colours a real one has.
    """

    static func prompt(name: String, kind: String, color: String, second: String) -> String {
        "Draw: \(name) (a \(kind)). Its main colour is \(color), its second colour \(second)."
    }

    /// The drawing as a Lua table for the compiler: {wp=..., parts={{shape, x, y, w, h, tilt, color}, ...}}
    static func table(_ d: Drawing) -> String {
        var t = "{wp=\(d.widthPercent), parts={"
        for p in d.parts.prefix(12) {
            t += "{\"\(p.shape.rawValue)\", \(p.x), \(p.y), \(p.width), \(p.height), \(p.tilt), \"\(p.color.rawValue)\"}, "
        }
        return t + "}}"
    }
}
