import SwiftUI

/// The Dalil D-arrow: straight parallel edges, one slant, one clean curve
/// (from the "شعار دليلك" artboard). Flat, no outline, inside the app.
struct BrandMark: View {
    var size: CGFloat = 28
    var color: Color = AppColors.accent
    var green: Bool = false

    var body: some View {
        DalilLogoShape()
            .fill(green ? AppColors.mint : color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct DalilLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let mark = SVGPathParser.path(
            "M58 36 H106 C148 36 174 66 174 100 C174 134 148 164 106 164 H26 L39 112 H96 V134 L138 100 L96 66 V88 H45 Z"
        )
        // The artboard's 200×200 box; the mark spans x 26…174, y 36…164.
        let box = CGRect(x: 26, y: 36, width: 148, height: 128)
        let scale = min(rect.width / box.width, rect.height / box.height)
        let dx = rect.midX - box.midX * scale
        let dy = rect.midY - box.midY * scale
        return mark.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: dx, ty: dy))
    }
}

struct NazlahWordmark: View {
    @EnvironmentObject private var settings: AppSettings
    var compact: Bool = false
    var subtitle: LocalizedStringKey? = "app.tagline"

    var body: some View {
        HStack(spacing: 8) {
            BrandMark(size: compact ? 32 : 36)
            VStack(alignment: .leading, spacing: 0) {
                Text(DalilCopy.t("brand", settings.language))
                    .font(compact ? AppTypography.extraBold(20) : AppTypography.bold(24))
                    .foregroundStyle(AppColors.primaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.regular(11))
                        .foregroundStyle(AppColors.secondaryText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
