import SwiftUI

struct BrandMark: View {
    var size: CGFloat = 28
    var color: Color = .white
    var green: Bool = false

    var body: some View {
        Image(green ? "DalilMarkGreen" : "DalilMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
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
