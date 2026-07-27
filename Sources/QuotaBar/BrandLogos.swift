import SwiftUI

/// Vector brand marks for every provider.
///
/// The marks are drawn from normalised geometry instead of bitmap assets so the
/// panel stays a single self-contained binary and every mark renders crisply at
/// 12pt in the one-line bar and at 23pt on a card.
struct BrandMark: Shape {
    let provider: ProviderID

    func path(in rect: CGRect) -> Path {
        let box = Self.squared(rect)
        return switch provider {
        case .codex: Self.openAI(in: box)
        case .claude: Self.claude(in: box)
        case .kimi: Self.kimi(in: box)
        case .deepseek: Self.deepSeek(in: box)
        case .grok: Self.grok(in: box)
        case .gemini: Self.gemini(in: box)
        }
    }

    private static func squared(_ rect: CGRect) -> CGRect {
        let side = min(rect.width, rect.height)
        return CGRect(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2,
            width: side,
            height: side
        )
    }

    // MARK: - Marks

    /// OpenAI's blossom: three capsule-shaped rings rotated by 60°, which
    /// reproduces the six-fold knot with an open centre.
    private static func openAI(in box: CGRect) -> Path {
        let ring = Path(
            roundedRect: CGRect(x: 0.325, y: 0.075, width: 0.35, height: 0.85),
            cornerRadius: 0.175
        )
        .strokedPath(StrokeStyle(lineWidth: 0.10, lineJoin: .round))

        var combined = Path()
        for step in 0..<3 {
            let rotation = CGAffineTransform(translationX: 0.5, y: 0.5)
                .rotated(by: .pi / 3 * Double(step))
                .translatedBy(x: -0.5, y: -0.5)
            combined.addPath(ring, transform: rotation)
        }
        return scaled(combined, into: box)
    }

    /// Anthropic's starburst: tapered rays radiating from a shared centre.
    private static func claude(in box: CGRect) -> Path {
        let center = CGPoint(x: 0.5, y: 0.5)
        let rayCount = 12
        var path = Path()
        for index in 0..<rayCount {
            let angle = (Double(index) / Double(rayCount)) * 2 * .pi - .pi / 2
            // Alternating reach keeps the mark from reading as a plain asterisk.
            let reach = index.isMultiple(of: 2) ? 0.49 : 0.415
            let tipHalfWidth = index.isMultiple(of: 2) ? 0.046 : 0.040
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let normal = CGPoint(x: -direction.y, y: direction.x)
            let tip = CGPoint(
                x: center.x + direction.x * (reach - tipHalfWidth),
                y: center.y + direction.y * (reach - tipHalfWidth)
            )
            let root = CGPoint(
                x: center.x + direction.x * 0.02,
                y: center.y + direction.y * 0.02
            )
            let rootHalfWidth = 0.017

            path.move(to: CGPoint(
                x: root.x + normal.x * rootHalfWidth,
                y: root.y + normal.y * rootHalfWidth
            ))
            path.addLine(to: CGPoint(
                x: tip.x + normal.x * tipHalfWidth,
                y: tip.y + normal.y * tipHalfWidth
            ))
            path.addArc(
                center: tip,
                radius: tipHalfWidth,
                startAngle: .radians(angle + .pi / 2),
                endAngle: .radians(angle - .pi / 2),
                clockwise: true
            )
            path.addLine(to: CGPoint(
                x: root.x - normal.x * rootHalfWidth,
                y: root.y - normal.y * rootHalfWidth
            ))
            path.closeSubpath()
        }
        return scaled(path, into: box)
    }

    /// Moonshot's crescent with an accompanying spark. Drawn as one closed
    /// outline — a circular outer edge plus a curved inner edge — so a plain
    /// non-zero fill produces the crescent without any boolean subtraction.
    private static func kimi(in box: CGRect) -> Path {
        let disc = CGPoint(x: 0.46, y: 0.5)
        let radius = 0.455
        let hornAngle = Angle.degrees(60)
        let horn = { (sign: Double) in
            CGPoint(
                x: disc.x + radius * cos(hornAngle.radians) * 1,
                y: disc.y + radius * sin(hornAngle.radians) * sign
            )
        }
        var path = Path()
        path.move(to: horn(-1))
        path.addArc(
            center: disc,
            radius: radius,
            startAngle: -hornAngle,
            endAngle: hornAngle,
            clockwise: true
        )
        path.addCurve(
            to: horn(-1),
            control1: CGPoint(x: 0.205, y: 0.88),
            control2: CGPoint(x: 0.205, y: 0.12)
        )
        path.closeSubpath()
        path.addPath(star(center: CGPoint(x: 0.875, y: 0.155), radius: 0.125, waist: 0.22))
        return scaled(path, into: box)
    }

    /// DeepSeek's whale, reduced to a single silhouette.
    private static func deepSeek(in box: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0.045, y: 0.545))
        path.addCurve(
            to: CGPoint(x: 0.50, y: 0.285),
            control1: CGPoint(x: 0.12, y: 0.36),
            control2: CGPoint(x: 0.31, y: 0.275)
        )
        path.addCurve(
            to: CGPoint(x: 0.715, y: 0.395),
            control1: CGPoint(x: 0.60, y: 0.295),
            control2: CGPoint(x: 0.665, y: 0.335)
        )
        path.addLine(to: CGPoint(x: 0.955, y: 0.175))
        path.addCurve(
            to: CGPoint(x: 0.865, y: 0.505),
            control1: CGPoint(x: 0.945, y: 0.335),
            control2: CGPoint(x: 0.895, y: 0.435)
        )
        path.addCurve(
            to: CGPoint(x: 0.955, y: 0.845),
            control1: CGPoint(x: 0.905, y: 0.605),
            control2: CGPoint(x: 0.945, y: 0.715)
        )
        path.addLine(to: CGPoint(x: 0.695, y: 0.615))
        path.addCurve(
            to: CGPoint(x: 0.045, y: 0.545),
            control1: CGPoint(x: 0.50, y: 0.775),
            control2: CGPoint(x: 0.20, y: 0.735)
        )
        path.closeSubpath()

        // Blowhole spout, drawn as a slim teardrop above the back.
        path.move(to: CGPoint(x: 0.305, y: 0.205))
        path.addCurve(
            to: CGPoint(x: 0.395, y: 0.045),
            control1: CGPoint(x: 0.305, y: 0.135),
            control2: CGPoint(x: 0.345, y: 0.08)
        )
        path.addCurve(
            to: CGPoint(x: 0.355, y: 0.195),
            control1: CGPoint(x: 0.4, y: 0.105),
            control2: CGPoint(x: 0.375, y: 0.155)
        )
        path.closeSubpath()
        return scaled(path, into: box)
    }

    /// xAI's blade-like X: one unbroken diagonal crossed by a split one.
    private static func grok(in box: CGRect) -> Path {
        var path = Path()
        path.addPath(quad(
            CGPoint(x: 0.735, y: 0.045),
            CGPoint(x: 0.985, y: 0.045),
            CGPoint(x: 0.265, y: 0.955),
            CGPoint(x: 0.015, y: 0.955)
        ))
        path.addPath(quad(
            CGPoint(x: 0.015, y: 0.045),
            CGPoint(x: 0.265, y: 0.045),
            CGPoint(x: 0.505, y: 0.345),
            CGPoint(x: 0.255, y: 0.345)
        ))
        path.addPath(quad(
            CGPoint(x: 0.495, y: 0.655),
            CGPoint(x: 0.745, y: 0.655),
            CGPoint(x: 0.985, y: 0.955),
            CGPoint(x: 0.735, y: 0.955)
        ))
        return scaled(path, into: box)
    }

    /// Gemini's four-pointed spark.
    private static func gemini(in box: CGRect) -> Path {
        scaled(
            star(center: CGPoint(x: 0.5, y: 0.5), radius: 0.5, waist: 0.19),
            into: box
        )
    }

    // MARK: - Primitives

    /// Four-pointed star with concave sides. `waist` is the distance from the
    /// centre where the curve controls sit; smaller means sharper points.
    private static func star(center: CGPoint, radius: Double, waist: Double) -> Path {
        let tip = radius
        let control = radius * waist
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - tip))
        path.addQuadCurve(
            to: CGPoint(x: center.x + tip, y: center.y),
            control: CGPoint(x: center.x + control, y: center.y - control)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y + tip),
            control: CGPoint(x: center.x + control, y: center.y + control)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x - tip, y: center.y),
            control: CGPoint(x: center.x - control, y: center.y + control)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y - tip),
            control: CGPoint(x: center.x - control, y: center.y - control)
        )
        path.closeSubpath()
        return path
    }

    private static func quad(
        _ a: CGPoint,
        _ b: CGPoint,
        _ c: CGPoint,
        _ d: CGPoint
    ) -> Path {
        Path { path in
            path.move(to: a)
            path.addLine(to: b)
            path.addLine(to: c)
            path.addLine(to: d)
            path.closeSubpath()
        }
    }

    private static func scaled(_ path: Path, into box: CGRect) -> Path {
        path.applying(
            CGAffineTransform(translationX: box.minX, y: box.minY)
                .scaledBy(x: box.width, y: box.height)
        )
    }
}

/// A provider's mark tinted with its accent colour, optionally on a soft chip.
struct BrandLogoView: View {
    let provider: ProviderID
    var size: Double = 14
    var dimmed: Bool = false

    var body: some View {
        BrandMark(provider: provider)
            .fill(
                LinearGradient(
                    colors: provider.logoGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .opacity(dimmed ? 0.4 : 1)
            .accessibilityLabel(provider.title)
    }
}

extension ProviderID {
    var accent: Color {
        Color(hex: accentHex) ?? .white
    }

    /// Gemini's mark is a two-tone spark; everything else keeps a single tint
    /// with a light sheen so the marks look like one family.
    var logoGradient: [Color] {
        switch self {
        case .gemini:
            [Color(hex: "#7FA8FF") ?? accent, Color(hex: "#B98BE0") ?? accent]
        default:
            [accent.opacity(0.84), accent]
        }
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
