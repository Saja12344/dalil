import SwiftUI

/// Dalil's own duotone icon set, drawn from the "أيقونات دليلك" artboard.
/// Each glyph is ink outline + one category color, on a 120×120 grid.
/// This is the light cut: thinner ink (85%) and a short hard shadow (3.5 instead of 5).
enum DalilGlyph: String, CaseIterable, Identifiable {
    case pin
    case discover
    case map
    case cafe
    case restaurant
    case park
    case events
    case tourism
    case featured
    case saved
    case search
    case route
    case arrived
    case home
    case work
    case add

    var id: String { rawValue }
}

struct DalilIcon: View {
    var glyph: DalilGlyph
    var size: CGFloat = 32
    /// Replaces the glyph's main color (category color). Ink and paper stay fixed.
    var tint: Color? = nil
    var shadow: Bool = true

    var body: some View {
        Canvas { context, canvas in
            let scale = min(canvas.width, canvas.height) / 120
            context.translateBy(
                x: (canvas.width - 120 * scale) / 2,
                y: (canvas.height - 120 * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            DalilIconPainter(context: context, tint: tint, shadow: shadow).draw(glyph)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension PlaceCategory {
    var dalilGlyph: DalilGlyph {
        switch self {
        case .cafe, .cowork: return .cafe
        case .restaurant, .dessert: return .restaurant
        case .park, .viewpoint: return .park
        case .family: return .tourism
        default: return .pin
        }
    }
}

private struct DalilIconPainter {
    let context: GraphicsContext
    let tint: Color?
    let shadow: Bool

    private static let ink = Color(hex: "111111")
    private static let paper = Color.white
    private static let orange = Color(hex: "FF4E00")
    private static let green = Color(hex: "008E51")
    private static let gold = Color(hex: "F2A20C")
    private static let blue = Color(hex: "2E7DF0")
    private static let pink = Color(hex: "E6007E")

    let lightness: CGFloat = 0.85
    let shadowOffset: CGFloat = 3.5

    private var ink: Color { Self.ink }
    private var paper: Color { Self.paper }

    private func w(_ value: CGFloat) -> CGFloat { value * lightness }
    private func p(_ d: String) -> Path { SVGPathParser.path(d) }

    private func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: r, style: .continuous)
    }

    private func dropShadow(_ path: Path, offset: CGFloat? = nil) {
        guard shadow else { return }
        let o = offset ?? shadowOffset
        context.fill(path.offsetBy(dx: o, dy: o), with: .color(ink))
    }

    /// Filled shape with ink outline and the hard offset shadow.
    private func block(_ path: Path, _ fill: Color, line: CGFloat = 4) {
        dropShadow(path)
        shape(path, fill, line: line)
    }

    /// Filled shape with ink outline, no shadow.
    private func shape(_ path: Path, _ fill: Color, line: CGFloat = 4) {
        context.fill(path, with: .color(fill))
        stroke(path, line)
    }

    private func stroke(_ path: Path, _ width: CGFloat, color: Color? = nil, dash: [CGFloat] = []) {
        context.stroke(
            path,
            with: .color(color ?? ink),
            style: StrokeStyle(lineWidth: w(width), lineCap: .round, lineJoin: .round, dash: dash)
        )
    }

    private func fill(_ path: Path, _ color: Color? = nil) {
        context.fill(path, with: .color(color ?? ink))
    }

    func draw(_ glyph: DalilGlyph) {
        switch glyph {
        case .pin: pin()
        case .discover: discover()
        case .map: map()
        case .cafe: cafe()
        case .restaurant: restaurant()
        case .park: park()
        case .events: events()
        case .tourism: tourism()
        case .featured: featured()
        case .saved: saved()
        case .search: search()
        case .route: route()
        case .arrived: arrived()
        case .home: home()
        case .work: work()
        case .add: add()
        }
    }

    // MARK: - From the artboard

    private func pin() {
        let drop = p("M60 14 C40 14 26 29 26 48 C26 74 60 104 60 104 C60 104 94 74 94 48 C94 29 80 14 60 14 Z")
        block(drop, tint ?? Self.orange)
        shape(circle(60, 48, 16), paper)
        fill(circle(65, 48, 7))
    }

    private func discover() {
        let main = tint ?? Self.orange
        shape(rect(24, 22, 28, 40, 9), main)
        shape(rect(68, 22, 28, 40, 9), main)
        fill(rect(50, 38, 20, 16, 4))
        fill(circle(36, 74, 24))
        fill(circle(84, 74, 24))
        fill(ellipse(36, 74, 14, 10), paper)
        fill(ellipse(84, 74, 14, 10), paper)
        fill(circle(41, 74, 6))
        fill(circle(89, 74, 6))
    }

    private func map() {
        dropShadow(p("M16 30 L44 20 L76 30 L104 20 L104 96 L76 106 L44 96 L16 106 Z"))
        shape(p("M16 30 L44 20 L44 96 L16 106 Z"), paper)
        shape(p("M44 20 L76 30 L76 106 L44 96 Z"), tint ?? Self.green)
        shape(p("M76 30 L104 20 L104 96 L76 106 Z"), paper)
        stroke(p("M54 40 L54 92 M66 44 L66 96 M44 52 L76 62 M44 72 L76 82"), 2)
        stroke(p("M24 88 Q36 64 30 50"), 3, dash: [5, 5])
        shape(circle(90, 54, 8), Self.orange, line: 3)
    }

    private func cafe() {
        let cup = p("M24 42 H86 V76 Q86 100 62 100 H48 Q24 100 24 76 Z")
        stroke(p("M44 14 Q38 22 44 30 M58 10 Q52 20 58 30 M72 14 Q66 22 72 30"), 4)
        dropShadow(cup)
        stroke(p("M86 52 Q104 52 104 66 Q104 80 86 80"), 5)
        shape(cup, tint ?? Self.gold)
        stroke(p("M40 64 Q45 58 50 64 M60 64 Q65 58 70 64"), 4)
        shape(p("M44 76 Q55 86 66 76 Z"), ink, line: 3)
    }

    private func park() {
        let main = tint ?? Self.green
        stroke(p("M60 94 L60 60"), 5)
        shape(p("M58 82 Q30 84 22 58 Q48 54 58 80 Z"), main)
        fill(p("M10 108 Q60 66 110 108 Z"))
        shape(circle(60, 40, 26), main)
        stroke(p("M48 38 Q52 32 56 38 M64 38 Q68 32 72 38"), 4)
        stroke(p("M50 48 Q60 56 70 48"), 4)
    }

    private func events() {
        var rotated = context
        rotated.translateBy(x: 60, y: 60)
        rotated.rotate(by: .degrees(-12))
        rotated.translateBy(x: -60, y: -60)
        let painter = DalilIconPainter(context: rotated, tint: tint, shadow: shadow)
        painter.ticket()
    }

    fileprivate func ticket() {
        // The artboard's notches are SVG arcs; written here as two cubic quarter-circles each.
        let body = p(
            "M16 34 H104 V50 C98.477 50 94 54.477 94 60 C94 65.523 98.477 70 104 70 V86 H16 V70 " +
            "C21.523 70 26 65.523 26 60 C26 54.477 21.523 50 16 50 Z"
        )
        block(body, tint ?? Self.gold)
        stroke(p("M80 38 V82"), 3, dash: [5, 5])
        shape(p("M48 44 L53 55 L65 56 L56 64 L59 76 L48 69 L37 76 L40 64 L31 56 L43 55 Z"), paper, line: 3.5)
    }

    private func tourism() {
        fill(rect(40, 24, 32, 18, 5))
        let body = rect(14, 38, 92, 60, 14)
        block(body, tint ?? Self.blue)
        shape(circle(60, 68, 22), paper)
        fill(circle(60, 68, 11))
        fill(circle(56, 64, 3.5), paper)
        shape(rect(88, 46, 10, 7, 2), paper, line: 3)
    }

    private func featured() {
        block(p("M56 12 Q62 50 100 56 Q62 62 56 104 Q50 62 12 56 Q50 50 56 12 Z"), tint ?? Self.pink)
        stroke(p("M94 14 L94 30 M86 22 L102 22"), 4)
        fill(circle(98, 96, 5))
    }

    private func saved() {
        block(p("M30 14 H90 V106 L60 84 L30 106 Z"), tint ?? Self.orange)
        let check = p("M42 48 L55 61 L78 36")
        context.stroke(check, with: .color(paper), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
        stroke(check, 5)
    }

    private func search() {
        context.stroke(p("M76 76 L104 104"), with: .color(ink), style: StrokeStyle(lineWidth: 16, lineCap: .round))
        if shadow { fill(circle(55, 55, 34)) }
        shape(circle(50, 50, 34), paper)
        var lens = context
        lens.clip(to: circle(50, 50, 32))
        lens.stroke(
            p("M18 34 H82 M18 50 H82 M18 66 H82 M34 18 V82 M50 18 V82 M66 18 V82"),
            with: .color(tint ?? Self.green),
            lineWidth: w(3)
        )
        shape(circle(50, 50, 10), Self.orange)
    }

    private func route() {
        stroke(p("M22 98 C22 60 76 84 70 54 C66 36 84 40 88 46"), 5, dash: [2, 10])
        fill(circle(22, 98, 11))
        fill(circle(22, 98, 4), paper)
        let drop = p("M92 12 C80 12 72 21 72 32 C72 48 92 64 92 64 C92 64 112 48 112 32 C112 21 104 12 92 12 Z")
        dropShadow(drop, offset: 3)
        shape(drop, tint ?? Self.orange)
        shape(circle(92, 32, 7), paper, line: 3)
    }

    private func arrived() {
        let check = p("M18 62 L46 90 L102 30")
        let outer: CGFloat = 16 + w(4) * 2
        if shadow {
            context.stroke(
                check.offsetBy(dx: shadowOffset, dy: shadowOffset),
                with: .color(ink),
                style: StrokeStyle(lineWidth: outer, lineCap: .round, lineJoin: .round)
            )
        }
        context.stroke(check, with: .color(ink), style: StrokeStyle(lineWidth: outer, lineCap: .round, lineJoin: .round))
        context.stroke(check, with: .color(tint ?? Self.green), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Same rules, for slots the artboard did not cover

    private func restaurant() {
        let main = tint ?? Self.gold
        stroke(p("M16 16 V34 Q16 44 22 44 Q28 44 28 34 V16 M22 16 V34"), 4)
        stroke(p("M22 44 V104"), 5)
        shape(p("M104 16 Q92 30 96 60 H104 Z"), paper)
        stroke(p("M104 60 V104"), 5)
        block(circle(62, 64, 30), main)
        shape(circle(62, 64, 19), paper)
        stroke(p("M53 61 Q56 56 59 61 M65 61 Q68 56 71 61"), 3.5)
        stroke(p("M55 69 Q62 75 69 69"), 3.5)
    }

    private func home() {
        block(p("M18 58 L60 20 L102 58 V102 H18 Z"), tint ?? Self.orange)
        fill(rect(49, 70, 22, 32, 5))
        shape(rect(76, 64, 14, 12, 3), paper, line: 3)
    }

    private func work() {
        stroke(p("M44 38 V30 Q44 22 52 22 H68 Q76 22 76 30 V38"), 5)
        block(rect(14, 38, 92, 62, 12), tint ?? Self.blue)
        stroke(p("M14 64 H106"), 4)
        shape(rect(52, 56, 16, 16, 4), paper, line: 3.5)
    }

    private func add() {
        block(circle(60, 60, 40), tint ?? paper)
        context.stroke(
            p("M60 40 V80 M40 60 H80"),
            with: .color(ink),
            style: StrokeStyle(lineWidth: 9, lineCap: .round)
        )
    }
}

/// Minimal reader for the absolute SVG path commands the icon artboard uses (M L H V C Q Z).
enum SVGPathParser {
    static func path(_ d: String) -> Path {
        let tokens = tokenize(d)
        var path = Path()
        var index = 0
        var command: Character = "M"
        var current = CGPoint.zero
        var start = CGPoint.zero

        func number() -> CGFloat {
            defer { index += 1 }
            guard index < tokens.count else { return 0 }
            return CGFloat(Double(tokens[index]) ?? 0)
        }

        func point() -> CGPoint {
            let x = number()
            let y = number()
            return CGPoint(x: x, y: y)
        }

        while index < tokens.count {
            if let first = tokens[index].first, first.isLetter {
                command = first
                index += 1
            }
            switch command {
            case "M":
                current = point()
                start = current
                path.move(to: current)
                command = "L"
            case "L":
                current = point()
                path.addLine(to: current)
            case "H":
                current.x = number()
                path.addLine(to: current)
            case "V":
                current.y = number()
                path.addLine(to: current)
            case "C":
                let c1 = point()
                let c2 = point()
                current = point()
                path.addCurve(to: current, control1: c1, control2: c2)
            case "Q":
                let control = point()
                current = point()
                path.addQuadCurve(to: current, control: control)
            case "Z", "z":
                path.closeSubpath()
                current = start
                if index < tokens.count, let next = tokens[index].first, !next.isLetter {
                    index += 1
                }
            default:
                index += 1
            }
        }
        return path
    }

    private static func tokenize(_ d: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        for character in d {
            if character.isLetter {
                flush()
                tokens.append(String(character))
            } else if character == " " || character == "," || character == "\n" {
                flush()
            } else if character == "-" {
                flush()
                current = "-"
            } else {
                current.append(character)
            }
        }
        flush()
        return tokens
    }
}

#if DEBUG
#Preview("Dalil icons") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
        ForEach(DalilGlyph.allCases) { glyph in
            VStack {
                DalilIcon(glyph: glyph, size: 56)
                Text(glyph.rawValue).font(.caption)
            }
        }
    }
    .padding()
    .background(AppColors.warmBackground)
}
#endif
