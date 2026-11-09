import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

@main
struct NazlahApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var environment: AppEnvironment
    @StateObject private var session: CatalogSession

    init() {
        let environment = AppEnvironment.live()
        _environment = StateObject(wrappedValue: environment)
        _session = StateObject(wrappedValue: CatalogSession(environment: environment))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .environmentObject(environment.settings)
                .environmentObject(environment.router)
                .environmentObject(session)
                .environment(\.locale, environment.settings.locale)
                .environment(\.layoutDirection, environment.settings.layoutDirection)
                .preferredColorScheme(environment.settings.colorScheme)
                .id(environment.settings.languageRaw)
                .onAppear { applySemantics(environment.settings.language) }
                .onChange(of: environment.settings.languageRaw) { _, _ in
                    applySemantics(environment.settings.language)
                }
        }
    }

    private func applySemantics(_ language: AppLanguage) {
        UIView.appearance().semanticContentAttribute = language == .arabic ? .forceRightToLeft : .forceLeftToRight
    }
}
