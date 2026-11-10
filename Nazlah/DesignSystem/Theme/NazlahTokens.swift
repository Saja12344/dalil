import SwiftUI
import UIKit

enum LineColor: String, CaseIterable, Identifiable, Sendable {
    case blue, red, orange, yellow, green, purple

    var id: String { rawValue }

    /// Official RCRC polyline hexes from `metro_catalog.json`.
    var hex: String {
        switch self {
        case .blue: return "00ADE5"
        case .red: return "F0493A"
        case .orange: return "F68D39"
        case .yellow: return "FFD105"
        case .green: return "43B649"
        case .purple: return "984C9D"
        }
    }

    var color: Color { Color(hex: hex) }

    /// Darker chip fill so white/ink text meets WCAG AA on the ride stripe.
    var chipHex: String {
        switch self {
        case .blue: return "0B6A94"
        case .red: return "C23028"
        case .orange: return "B85A12"
        case .yellow: return "C49200"
        case .green: return "2A7A32"
        case .purple: return "6E3573"
        }
    }

    var chipColor: Color { Color(hex: chipHex) }
    var onChip: Color { AppColors.onFill(chipHex) }
    var number: String { String(displayOrder) }
    var code: String { "M\(number)" }

    var displayOrder: Int {
        switch self {
        case .blue: return 1
        case .red: return 2
        case .orange: return 3
        case .yellow: return 4
        case .green: return 5
        case .purple: return 6
        }
    }

    var nameAr: String {
        switch self {
        case .blue: return "الأزرق"
        case .red: return "الأحمر"
        case .orange: return "البرتقالي"
        case .yellow: return "الأصفر"
        case .green: return "الأخضر"
        case .purple: return "البنفسجي"
        }
    }

    var nameEn: String {
        switch self {
        case .blue: return "Blue"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .purple: return "Purple"
        }
    }

    func localizedName(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
    }

    static func from(id: String) -> LineColor? {
        LineColor(rawValue: id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    static func from(hex: String) -> LineColor? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        return allCases.first { $0.hex == cleaned }
    }

    static func resolving(id: String? = nil, hex: String) -> LineColor {
        if let id, let line = from(id: id) { return line }
        return from(hex: hex) ?? .blue
    }
}

enum AppColors {
    /// Accent is CTA orange only. Navy is a dark fill for banners, not orange.
    static let navy = Color(hex: "111111")
    static let accent = Color(hex: "FF4E00")
    static let accentInk = Color(light: "B03600", dark: "FF4E00")
    static let warmBackground = Color(light: "ECE6DB", dark: "111111")
    static let cardSurface = Color(light: "FFFFFF", dark: "1A1A1A")
    static let primaryContainer = Color(light: "FFD8C8", dark: "2A2A2A")
    static let softSand = Color(light: "EFEBE4", dark: "1F1F1F")
    static let lime = Color(light: "5C534C", dark: "B8AFA4")
    static let limeDeep = Color(hex: "F2A20C")
    static let electric = Color(hex: "F2A20C")
    static let electricInk = Color(light: "7A4E00", dark: "F2A20C")
    static let mint = Color(hex: "008E51")
    static let mintInk = Color(light: "006237", dark: "5DDBA0")
    static let pink = Color(hex: "E6007E")
    static let pinkInk = Color(light: "B8005F", dark: "FF6FB8")
    static let tourism = Color(hex: "2E7DF0")
    static let tourismInk = Color(light: "0B4FA8", dark: "7EB4FF")
    static let night = Color(hex: "111111")
    static let charcoal = Color(light: "111111", dark: "1A1A1A")
    static let primaryText = Color(light: "111111", dark: "ECE6DB")
    static let secondaryText = Color(light: "5C534C", dark: "B8AFA4", lightContrast: "3D3833", darkContrast: "E4DCD2")
    static let success = Color(hex: "008E51")
    static let lightOrangeTint = Color(hex: "FF4E00").opacity(0.15)
    static let divider = Color(light: "C9C0B6", dark: "2A2A2A")
    static let controlBorder = Color(light: "7A736B", dark: "6A6A6A")
    static let border = Color(light: "C9C0B6", dark: "2A2A2A", lightContrast: "7A736B", darkContrast: "6A6A6A")
    static let onLime = Color.white
    static let outline = Color(light: "5C534C", dark: "B8AFA4")
    static let coral = Color(hex: "FF4E00")
    static let lavender = Color(light: "EFEBE4", dark: "1F1F1F")
    static let brandOrange = accent
    static let cream = Color(hex: "ECE6DB")
    static let brandGreen = Color(hex: "008E51")
    static let onAccent = Color.white
    static let banner = Color(hex: "111111")

    static func metroLine(_ hex: String) -> Color {
        LineColor.from(hex: hex)?.color ?? Color(hex: hex)
    }

    static func metroLine(_ line: LineColor) -> Color {
        line.color
    }

    static func category(_ category: PlaceCategory) -> Color {
        switch category {
        case .cafe, .cowork: return pink
        case .family: return tourism
        case .park, .viewpoint, .pharmacy: return mint
        case .restaurant, .dessert, .gym: return electric
        default: return electric
        }
    }

    static func categoryInk(_ category: PlaceCategory) -> Color {
        switch category {
        case .cafe, .cowork: return pinkInk
        case .family: return tourismInk
        case .park, .viewpoint, .pharmacy: return mintInk
        case .restaurant, .dessert, .gym: return electricInk
        default: return electricInk
        }
    }

    /// 15% tint behind category icons (within the 12–18% range).
    static func categoryTint(_ category: PlaceCategory) -> Color {
        Self.category(category).opacity(0.15)
    }

    static func onFill(_ hex: String) -> Color {
        Color.relativeLuminance(hex) > 0.55 ? Color(hex: "111111") : .white
    }

    static func onFill(_ line: LineColor) -> Color {
        onFill(line.hex)
    }
}

enum AppTextStyle: CaseIterable {
    case largeTitle
    case title
    case headline
    case body
    case subhead
    case caption

    var size: CGFloat {
        switch self {
        case .largeTitle: return 32
        case .title: return 22
        case .headline: return 17
        case .body: return 16
        case .subhead: return 14
        case .caption: return 12
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .largeTitle: return 38
        case .title: return 28
        case .headline: return 22
        case .body: return 22
        case .subhead: return 18
        case .caption: return 16
        }
    }

    var lineSpacing: CGFloat { max(lineHeight - size, 0) }

    var font: Font {
        switch self {
        case .largeTitle: return AppTypography.extraBold(size)
        case .title: return AppTypography.bold(size)
        case .headline: return AppTypography.semibold(size)
        case .body: return AppTypography.regular(size)
        case .subhead: return Font.system(size: size, weight: .semibold)
        case .caption: return Font.system(size: size, weight: .regular)
        }
    }
}

enum AppTypography {
    static func extraBold(_ size: CGFloat) -> Font {
        scaled("Changa", size: size, weight: .heavy)
    }

    static func bold(_ size: CGFloat) -> Font {
        scaled("Changa", size: size, weight: .bold)
    }

    static func semibold(_ size: CGFloat) -> Font {
        size >= 16
            ? scaled("Changa", size: size, weight: .semibold)
            : Font.system(textStyle(for: size)).weight(.semibold)
    }

    static func regular(_ size: CGFloat) -> Font {
        size >= 16
            ? scaled("Changa", size: size, weight: .medium)
            : Font.system(textStyle(for: size))
    }

    static func font(_ style: AppTextStyle) -> Font {
        style.font
    }

    static func scaled(_ name: String, size: CGFloat, weight: Font.Weight) -> Font {
        .custom(name, size: size, relativeTo: textStyle(for: size)).weight(weight)
    }

    static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 34...: return .largeTitle
        case 26...: return .title
        case 22...: return .title2
        case 18...: return .title3
        case 16...: return .body
        case 14...: return .subheadline
        case 13...: return .footnote
        case 12...: return .caption
        default: return .caption2
        }
    }

    static let wordmark = AppTextStyle.headline.font
    static let tagline = AppTextStyle.caption.font
    static let section = AppTextStyle.title.font
    static let placeName = AppTextStyle.headline.font
    static let body = AppTextStyle.body.font
    static let caption = AppTextStyle.caption.font
    static let micro = AppTextStyle.caption.font
}

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let chip: CGFloat = 6
    static let tight: CGFloat = 8
    static let item: CGFloat = 12
    static let screen: CGFloat = 16
    static let section: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum AppSize {
    static let header: CGFloat = 44
    static let touch: CGFloat = 44
    static let chip: CGFloat = 36
    static let categoryChip: CGFloat = 40
    static let search: CGFloat = 52
    static let button: CGFloat = 56
    static let thumb: CGFloat = 56
    static let placeRow: CGFloat = 72
    static let timelineRow: CGFloat = 64
    static let hero: CGFloat = 240
}

enum AppRadius {
    static let card: CGFloat = 16
    static let button: CGFloat = 16
    static let chip: CGFloat = 999
    static let search: CGFloat = 999
}

enum AppShadow {
    static let card = ShadowToken(color: Color(light: "18111111", dark: "66000000"), radius: 18, y: 8)
    static let bar = ShadowToken(color: Color(light: "14111111", dark: "80000000"), radius: 16, y: -6)
}

struct ShadowToken {
    var color: Color
    var radius: CGFloat
    var y: CGFloat
}

/// Light neo-brutalist outline: a thin ink edge plus a small hard (unblurred) offset shadow.
/// Kept deliberately subtle — 1.5pt line, 3pt offset — so the app stays calm.
enum AppOutline {
    static let width: CGFloat = 1.5
    static let offset: CGFloat = 3
    static let smallOffset: CGFloat = 2
    static let ink = Color(light: "111111", dark: "6A6A6A")
    static let shadow = Color(light: "111111", dark: "000000")
}

extension View {
    /// Ink outline + hard offset shadow on any shape. Pass `offset: 0` for outline only.
    func dalilBlock<S: InsettableShape>(
        _ shape: S,
        offset: CGFloat = AppOutline.offset,
        lineWidth: CGFloat = AppOutline.width
    ) -> some View {
        self
            .clipShape(shape)
            .overlay(shape.strokeBorder(AppOutline.ink, lineWidth: lineWidth))
            .background {
                if offset > 0 {
                    shape
                        .fill(AppOutline.shadow)
                        .offset(x: offset, y: offset)
                        .accessibilityHidden(true)
                }
            }
    }

    func dalilCard(offset: CGFloat = AppOutline.offset) -> some View {
        dalilBlock(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous), offset: offset)
    }
}

extension View {
    func appCardShadow() -> some View {
        shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: 0, y: AppShadow.card.y)
    }

    func appBarShadow() -> some View {
        shadow(color: AppShadow.bar.color, radius: AppShadow.bar.radius, x: 0, y: AppShadow.bar.y)
    }
}

enum NazlahPalette {
    static let riyadhNight = AppColors.night
    static let metroSand = AppColors.softSand
    static let sunsetOrange = AppColors.accent
    static let palmGreen = AppColors.mint
    static let electricBlue = AppColors.tourism
    static let offWhite = AppColors.warmBackground
    static let canvas = AppColors.warmBackground
    static let canvasElevated = AppColors.cardSurface
    static let ink = AppColors.primaryText
    static let inkMuted = AppColors.secondaryText
    static let hairline = AppColors.border

    static func metroLine(_ hex: String) -> Color {
        AppColors.metroLine(hex)
    }
}

enum NazlahSpacing {
    static let xxs: CGFloat = AppSpacing.xxs
    static let xs: CGFloat = AppSpacing.tight
    static let sm: CGFloat = AppSpacing.item
    static let md: CGFloat = AppSpacing.screen
    static let lg: CGFloat = AppSpacing.section
    static let xl: CGFloat = AppSpacing.xl
    static let xxl: CGFloat = AppSpacing.xxl
}

enum NazlahRadius {
    static let chip: CGFloat = AppRadius.chip
    static let card: CGFloat = AppRadius.card
    static let sheet: CGFloat = 28
    static let station: CGFloat = 22
}

enum NazlahMotion {
    static let quick: Animation = .easeOut(duration: 0.22)
    static let settle: Animation = .spring(response: 0.46, dampingFraction: 0.82)
    static let splash: Animation = .spring(response: 0.7, dampingFraction: 0.86)
}

enum NazlahTypography {
    static func display(_ size: CGFloat = AppTextStyle.largeTitle.size) -> Font { AppTextStyle.largeTitle.font }
    static func title(_ size: CGFloat = AppTextStyle.title.size) -> Font { AppTextStyle.title.font }
    static func body(_ size: CGFloat = AppTextStyle.body.size) -> Font { AppTextStyle.body.font }
    static func caption(_ size: CGFloat = AppTextStyle.caption.size) -> Font { AppTextStyle.caption.font }
    static func mono(_ size: CGFloat = AppTextStyle.subhead.size) -> Font { AppTextStyle.subhead.font }
}

extension View {
    func appText(_ style: AppTextStyle) -> some View {
        font(style.font)
            .lineSpacing(style.lineSpacing)
    }

    func appLiveNumber(_ style: AppTextStyle) -> some View {
        appText(style).monospacedDigit()
    }

    func appScreenPadding() -> some View {
        padding(.horizontal, AppSpacing.screen)
    }

    /// Extra space so the last card sits above the native tab bar.
    func appTabBarClearance() -> some View {
        padding(.bottom, AppSpacing.screen)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 8 {
            let a = Double((value & 0xFF000000) >> 24) / 255
            r = Double((value & 0x00FF0000) >> 16) / 255
            g = Double((value & 0x0000FF00) >> 8) / 255
            b = Double(value & 0x000000FF) / 255
            self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
            return
        }
        if cleaned.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }

    init(light: String, dark: String, lightContrast: String? = nil, darkContrast: String? = nil) {
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let highContrast = traits.accessibilityContrast == .high
            let hex: String
            switch (isDark, highContrast) {
            case (true, true): hex = darkContrast ?? dark
            case (false, true): hex = lightContrast ?? light
            case (true, false): hex = dark
            case (false, false): hex = light
            }
            return UIColor(Color(hex: hex))
        })
    }

    static func relativeLuminance(_ hex: String) -> Double {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        func linear(_ channel: Double) -> Double {
            let value = channel / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let r = linear(Double((value & 0xFF0000) >> 16))
        let g = linear(Double((value & 0x00FF00) >> 8))
        let b = linear(Double(value & 0x0000FF))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}
