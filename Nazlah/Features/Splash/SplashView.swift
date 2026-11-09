import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void
    @EnvironmentObject private var settings: AppSettings
    @State private var progress: CGFloat = 0.08

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                BrandMark(size: 96)
                    .scaleEffect(progress > 0.4 ? 1 : 0.86)
                    .opacity(Double(progress))
                VStack(spacing: 4) {
                    Text(DalilCopy.t("brand", settings.language))
                        .font(AppTypography.extraBold(44))
                        .foregroundStyle(AppColors.cream)
                        .multilineTextAlignment(.center)
                    Text(DalilCopy.t("splash.tagline", settings.language))
                        .font(AppTypography.regular(14))
                        .foregroundStyle(AppColors.outline)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            withAnimation(NazlahMotion.splash) { progress = 1 }
            Task {
                try? await Task.sleep(for: .milliseconds(1100))
                onFinished()
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}
