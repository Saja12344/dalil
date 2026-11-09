import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var page = 0

    private var lang: AppLanguage { settings.language }
    private func t(_ key: String) -> String { DalilCopy.t(key, lang) }

    private var pages: [(String, String, String)] {
        [
            ("onboarding.1.title", "onboarding.1.body", "magnifyingglass"),
            ("onboarding.2.title", "onboarding.2.body", "figure.walk"),
            ("onboarding.3.title", "onboarding.3.body", "plus")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            NazlahWordmark()
                .padding(.top, 24)
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 20) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                .fill(AppColors.softSand)
                                .frame(height: 180)
                            Image(systemName: item.2)
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(AppColors.brandOrange)
                        }
                        .padding(.horizontal, AppSpacing.screen)
                        Text(t(item.0))
                            .font(AppTypography.extraBold(28))
                            .foregroundStyle(AppColors.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.screen)
                        Text(t(item.1))
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                        Spacer()
                    }
                    .tag(index)
                    .padding(.top, 28)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            NazlahButton(title: LocalizedStringKey(stringLiteral: page == 2 ? t("onboarding.start") : t("onboarding.next"))) {
                if page == 2 {
                    settings.hasCompletedOnboarding = true
                } else {
                    withAnimation { page += 1 }
                }
            }
            .padding(AppSpacing.screen)
        }
        .background(AppColors.warmBackground.ignoresSafeArea())
    }
}
