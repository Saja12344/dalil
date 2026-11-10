import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var showSplash = true

    var body: some View {
        ZStack {
            AppColors.warmBackground.ignoresSafeArea()
            if showSplash {
                SplashView {
                    withAnimation(NazlahMotion.settle) {
                        showSplash = false
                    }
                }
            } else if !settings.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .background(AppColors.warmBackground)
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-uitesting") {
                settings.hasCompletedOnboarding = true
                showSplash = false
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var session: CatalogSession

    var body: some View {
        TabView(selection: tabSelection) {
            tabStack($router.homePath, .home, "tab.home", "house") {
                AroundYouView()
            }
            tabStack($router.mapPath, .map, "tab.map", "map") {
                MetroMapView()
            }
            tabStack($router.favoritesPath, .favorites, "tab.favorites", "bookmark") {
                FavoritesView()
            }
            tabStack($router.accountPath, .account, "tab.account", "person") {
                AccountView()
            }
        }
        .tint(AppColors.accent)
        .sheet(isPresented: $router.isShowingAuth) {
            AuthSheet()
        }
        .fullScreenCover(isPresented: $router.isShowingSearch) {
            SearchResultsView(initialQuery: router.pendingSearchQuery)
                .environmentObject(environment)
                .environmentObject(settings)
                .environmentObject(router)
                .environmentObject(session)
                .environment(\.locale, settings.locale)
                .environment(\.layoutDirection, settings.layoutDirection)
                .preferredColorScheme(settings.colorScheme)
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { router.tab },
            set: { router.select($0) }
        )
    }

    @ViewBuilder
    private func tabStack<Content: View>(
        _ path: Binding<NavigationPath>,
        _ tab: AppTab,
        _ title: String,
        _ icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack(path: path) {
            content()
                .navigationDestination(for: AppRoute.self, destination: routeView)
        }
        .tabItem {
            Label(DalilCopy.t(title, settings.language), systemImage: icon)
        }
        .tag(tab)
    }

    @ViewBuilder
    private func routeView(_ route: AppRoute) -> some View {
        Group {
            switch route {
            case .station(let id):
                StationDetailView(stationId: id)
            case .place(let id):
                PlaceDetailView(placeId: id)
            case .addPlace:
                AddPlaceFlowView()
            case .searchResults(let query):
                SearchResultsView(initialQuery: query)
            case .browse(let browse):
                HomeBrowseView(kind: browse)
            case .submissions:
                MySubmissionsView()
            case .reports:
                MyReportsView()
            case .privacy:
                LegalPageView(kind: .privacy)
            case .sources:
                LegalPageView(kind: .sources)
            case .support:
                LegalPageView(kind: .support)
            case .deleteAccount:
                DeleteAccountView()
            case .moderator:
                ModeratorInboxView()
            case .submissionDetail(let id):
                ModeratorSubmissionView(submissionId: id)
            case .auth:
                AuthSheet()
            case .metroMap:
                MetroMapView()
            case .tripPlan(let id):
                TripPlanView(destination: .place(id))
            case .savedTrip(let id):
                TripPlanView(destination: .saved(id))
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(AppColors.warmBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
