import SwiftUI

enum AppChipStyle {
    case orangeTint
    case sand
    case navy
    case success
    case outline
}

struct AppChip: View {
    var title: LocalizedStringKey
    var systemImage: String? = nil
    var style: AppChipStyle = .sand
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
            }
            Text(title)
                .font(compact ? AppTypography.micro : AppTypography.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 7)
        .foregroundStyle(foreground)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous))
    }

    private var background: Color {
        switch style {
        case .orangeTint: return AppColors.lightOrangeTint
        case .sand: return AppColors.softSand
        case .navy: return AppColors.navy.opacity(0.88)
        case .success: return AppColors.success
        case .outline: return Color.clear
        }
    }

    private var foreground: Color {
        switch style {
        case .orangeTint: return AppColors.brandOrange
        case .sand: return AppColors.primaryText
        case .navy, .success: return .white
        case .outline: return AppColors.secondaryText
        }
    }
}

struct NearMeChip: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            AppChip(title: "home.nearMe", systemImage: "location.fill", style: .orangeTint)
        }
        .buttonStyle(.plain)
        .accessibilityHint("location.reason")
    }
}
