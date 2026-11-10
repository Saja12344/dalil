import SwiftUI
import UIKit

struct BottomNavigation: View {
    @Binding var selection: AppTab
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var router: AppRouter

    private let items: [(AppTab, String, String)] = [
        (.home, "house", "tab.home"),
        (.map, "map", "tab.map"),
        (.favorites, "bookmark", "tab.favorites"),
        (.account, "line.3.horizontal", "tab.account")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { item in
                tabButton(item.0, icon: item.1, title: DalilCopy.t(item.2, settings.language))
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .frame(minHeight: 62)
        .background(AppColors.cardSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppOutline.ink)
                .frame(height: AppOutline.width)
        }
    }

    private func tabButton(_ tab: AppTab, icon: String, title: String) -> some View {
        let active = selection == tab
        return Button {
            if tab == .home {
                router.resetToHome()
            } else {
                selection = tab
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: active ? .semibold : .regular))
                    .symbolVariant(active ? .fill : .none)
                Text(title)
                    .font(AppTypography.semibold(11))
                    .lineLimit(1)
            }
            .foregroundStyle(active ? AppColors.accentInk : AppColors.secondaryText)
            .padding(.horizontal, AppSpacing.item)
            .padding(.vertical, AppSpacing.xxs)
            .background {
                if active {
                    Capsule()
                        .fill(AppColors.primaryContainer)
                        .overlay(Capsule().strokeBorder(AppOutline.ink, lineWidth: AppOutline.width))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
