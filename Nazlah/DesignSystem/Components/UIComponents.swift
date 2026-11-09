import SwiftUI

struct NazlahButton: View {
    enum Kind { case primary, secondary, ghost }

    var title: LocalizedStringKey
    var kind: Kind = .primary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.semibold(16))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .background(background)
        .foregroundStyle(foreground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
    }

    private var background: Color {
        switch kind {
        case .primary: return AppColors.accent
        case .secondary: return AppColors.charcoal
        case .ghost: return Color.clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return AppColors.onLime
        case .secondary: return .white
        case .ghost: return AppColors.primaryText
        }
    }
}

struct NazlahSearchField: View {
    @Binding var text: String
    var placeholder: LocalizedStringKey
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.navy)
            TextField(placeholder, text: $text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.primaryText)
                .multilineTextAlignment(.leading)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.search, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.search, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

struct SearchLaunchButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.navy)
                Text("home.search.placeholder")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
                Spacer()
                Text("home.search.action")
                    .font(AppTypography.semibold(12))
                    .foregroundStyle(AppColors.brandOrange)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.search, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.search, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeader: View {
    var title: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = "home.seeAll"
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .appText(.title)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(2)
            Spacer()
            if let action {
                Button(action: action) {
                    Text(actionTitle ?? "home.seeAll")
                        .appText(.subhead)
                        .foregroundStyle(AppColors.primaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SkeletonBlock: View {
    var height: CGFloat = 16
    var width: CGFloat? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(AppColors.softSand)
            .frame(width: width, height: height)
    }
}

struct PlaceCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonBlock(height: 140)
            SkeletonBlock(height: 16, width: 180)
            SkeletonBlock(height: 12, width: 120)
        }
        .padding(12)
        .background(AppColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

struct EmptyStateView: View {
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tram")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppColors.brandOrange)
            Text(title)
                .font(AppTypography.section)
                .foregroundStyle(AppColors.primaryText)
            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                NazlahButton(title: actionTitle, kind: .secondary, action: action)
                    .frame(maxWidth: 220)
            }
        }
        .padding(AppSpacing.section)
    }
}

struct ErrorStateView: View {
    var retry: () -> Void

    var body: some View {
        EmptyStateView(
            title: "state.error.title",
            message: "state.error.message",
            actionTitle: "state.retry",
            action: retry
        )
    }
}

struct OfflineBanner: View {
    var body: some View {
        Text("state.offline")
            .font(AppTypography.caption)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(AppColors.navy)
            .foregroundStyle(.white)
    }
}
