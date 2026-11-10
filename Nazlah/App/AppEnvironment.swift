import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @Published var languageRaw: String = AppLanguage.arabic.rawValue {
        didSet { persist() }
    }
    @Published var appearanceRaw: String = AppearancePreference.system.rawValue {
        didSet { persist() }
    }
    @Published var hasCompletedOnboarding = false {
        didSet { persist() }
    }
    @Published var notificationsEnabled = true {
        didSet { persist() }
    }
    @Published var placeFiltersRaw = "" {
        didSet { persist() }
    }
    @Published var recentSearchesRaw = "" {
        didSet { persist() }
    }
    @Published var savedLocationsRaw = "" {
        didSet { persist() }
    }

    private var canPersist = false

    init() {
        let defaults = UserDefaults.standard
        if let language = defaults.string(forKey: "nazlah.language") {
            languageRaw = language
        }
        if let appearance = defaults.string(forKey: "nazlah.appearance") {
            appearanceRaw = appearance
        }
        if defaults.object(forKey: "nazlah.onboarded") != nil {
            hasCompletedOnboarding = defaults.bool(forKey: "nazlah.onboarded")
        }
        if let notifications = defaults.object(forKey: "nazlah.notifications") as? Bool {
            notificationsEnabled = notifications
        }
        if let filters = defaults.string(forKey: "nazlah.placeFilters") {
            placeFiltersRaw = filters
        }
        if let recents = defaults.string(forKey: "nazlah.recentSearches") {
            recentSearchesRaw = recents
        }
        if let saved = defaults.string(forKey: "nazlah.savedLocations") {
            savedLocationsRaw = saved
        }
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-dalil-lang"), args.indices.contains(idx + 1) {
            languageRaw = args[idx + 1]
        }
        if let idx = args.firstIndex(of: "-dalil-appearance"), args.indices.contains(idx + 1) {
            appearanceRaw = args[idx + 1]
        }
        canPersist = true
    }

    private func persist() {
        guard canPersist else { return }
        let defaults = UserDefaults.standard
        defaults.set(languageRaw, forKey: "nazlah.language")
        defaults.set(appearanceRaw, forKey: "nazlah.appearance")
        defaults.set(hasCompletedOnboarding, forKey: "nazlah.onboarded")
        defaults.set(notificationsEnabled, forKey: "nazlah.notifications")
        defaults.set(placeFiltersRaw, forKey: "nazlah.placeFilters")
        defaults.set(recentSearchesRaw, forKey: "nazlah.recentSearches")
        defaults.set(savedLocationsRaw, forKey: "nazlah.savedLocations")
    }

    var savedLocations: [SavedLocation] {
        get {
            guard let data = savedLocationsRaw.data(using: .utf8),
                  let items = try? JSONDecoder().decode([SavedLocation].self, from: data) else { return [] }
            return items.sorted { lhs, rhs in
                if lhs.kind.sortRank != rhs.kind.sortRank { return lhs.kind.sortRank < rhs.kind.sortRank }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
        set {
            let encoded = (try? JSONEncoder().encode(Array(newValue.prefix(12)))) ?? Data()
            savedLocationsRaw = String(data: encoded, encoding: .utf8) ?? ""
        }
    }

    var homeLocation: SavedLocation? { savedLocations.first { $0.kind == .home } }
    var workLocation: SavedLocation? { savedLocations.first { $0.kind == .work } }
    var customLocations: [SavedLocation] { savedLocations.filter { $0.kind == .custom } }

    func upsertSavedLocation(_ location: SavedLocation) {
        var items = savedLocations
        if location.kind != .custom {
            items.removeAll { $0.kind == location.kind && $0.id != location.id }
        }
        if let index = items.firstIndex(where: { $0.id == location.id }) {
            items[index] = location
        } else {
            items.append(location)
        }
        savedLocations = items
    }

    func saveSlot(_ kind: SavedLocation.Kind, at coordinate: GeoCoordinate, name: String? = nil) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let existing = savedLocations.first(where: { $0.kind == kind && kind != .custom }) {
            var updated = existing
            updated.latitude = coordinate.latitude
            updated.longitude = coordinate.longitude
            if !trimmed.isEmpty { updated.name = trimmed }
            upsertSavedLocation(updated)
            return
        }
        upsertSavedLocation(
            SavedLocation(
                id: UUID().uuidString,
                name: trimmed.isEmpty ? kind.rawValue : trimmed,
                kind: kind,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        )
    }

    func relocateSavedLocation(id: String, to coordinate: GeoCoordinate) {
        guard var item = savedLocations.first(where: { $0.id == id }) else { return }
        item.latitude = coordinate.latitude
        item.longitude = coordinate.longitude
        upsertSavedLocation(item)
    }

    func renameSavedLocation(id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var item = savedLocations.first(where: { $0.id == id }) else { return }
        item.name = trimmed
        upsertSavedLocation(item)
    }

    func removeSavedLocation(id: String) {
        savedLocations = savedLocations.filter { $0.id != id }
    }

    var recentSearches: [String] {
        get {
            recentSearchesRaw
                .split(separator: "\u{1e}", omittingEmptySubsequences: true)
                .map(String.init)
        }
        set {
            recentSearchesRaw = Array(newValue.prefix(8)).joined(separator: "\u{1e}")
        }
    }

    func rememberSearch(_ raw: String) {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        var items = recentSearches.filter { $0.caseInsensitiveCompare(query) != .orderedSame }
        items.insert(query, at: 0)
        recentSearches = Array(items.prefix(8))
    }

    func removeSearch(_ query: String) {
        recentSearches = recentSearches.filter { $0 != query }
    }

    var persistedPlaceFilters: Set<PlaceFilter> {
        get {
            Set(placeFiltersRaw.split(separator: ",").compactMap { PlaceFilter(rawValue: String($0)) })
        }
        set {
            placeFiltersRaw = newValue.map(\.rawValue).sorted().joined(separator: ",")
        }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .arabic }
        set {
            languageRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    var appearance: AppearancePreference {
        get { AppearancePreference(rawValue: appearanceRaw) ?? .system }
        set {
            appearanceRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    var locale: Locale { language.locale }

    var layoutDirection: LayoutDirection {
        language == .arabic ? .rightToLeft : .leftToRight
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum HomeBrowse: String, Hashable {
    case stations
    case tourism
    case parks
    case clubs
    case restaurant
    case cafe
    case pharmacy
}

enum AppRoute: Hashable {
    case station(String)
    case place(String)
    case addPlace
    case searchResults(String)
    case browse(HomeBrowse)
    case submissions
    case reports
    case privacy
    case sources
    case support
    case deleteAccount
    case moderator
    case submissionDetail(String)
    case auth
    case metroMap
    case tripPlan(String)
    case savedTrip(String)
}

enum AppTab: Hashable {
    case home
    case map
    case favorites
    case account
}

enum MapPickIntent: Equatable {
    case add
    case home
    case work
    case relocate(String)
}

struct SavedLocation: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var kind: Kind
    var latitude: Double
    var longitude: Double

    enum Kind: String, Codable, Hashable {
        case home
        case work
        case custom

        var sortRank: Int {
            switch self {
            case .home: return 0
            case .work: return 1
            case .custom: return 2
            }
        }

        var systemImage: String {
            switch self {
            case .home: return "house.fill"
            case .work: return "briefcase.fill"
            case .custom: return "mappin.and.ellipse"
            }
        }

        var glyph: DalilGlyph {
            switch self {
            case .home: return .home
            case .work: return .work
            case .custom: return .pin
            }
        }

        var emptySystemImage: String {
            switch self {
            case .home: return "house"
            case .work: return "briefcase"
            case .custom: return "plus"
            }
        }
    }

    var coordinate: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    func title(_ language: AppLanguage) -> String {
        switch kind {
        case .home: return DalilCopy.t("home.quick.home", language)
        case .work: return DalilCopy.t("home.quick.work", language)
        case .custom:
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? DalilCopy.t("saved.unnamed", language) : trimmed
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var tab: AppTab = .home
    @Published var homePath = NavigationPath()
    @Published var mapPath = NavigationPath()
    @Published var favoritesPath = NavigationPath()
    @Published var accountPath = NavigationPath()
    @Published var pendingSearchQuery = ""
    @Published var pendingAuthRoute: AppRoute?
    @Published var isShowingAuth = false
    @Published var isShowingSearch = false
    @Published var isPickingMapLocation = false
    @Published var mapPickIntent: MapPickIntent = .add
    @Published var pendingSaveCoordinate: GeoCoordinate?
    @Published var shouldFocusAnchor = false

    init() {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-dalil-open-tab"), args.indices.contains(idx + 1) else { return }
        switch args[idx + 1] {
        case "map": tab = .map
        case "favorites": tab = .favorites
        case "account": tab = .account
        case "search":
            tab = .home
            isShowingSearch = true
        default: tab = .home
        }
    }

    func presentSearch(query: String = "") {
        pendingSearchQuery = query
        isShowingSearch = true
    }

    func presentMapPicker(_ intent: MapPickIntent = .add) {
        mapPickIntent = intent
        pendingSaveCoordinate = nil
        mapPath = NavigationPath()
        isPickingMapLocation = true
        tab = .map
    }

    func focusAnchorOnMap() {
        isPickingMapLocation = false
        pendingSaveCoordinate = nil
        shouldFocusAnchor = true
        mapPath = NavigationPath()
        tab = .map
    }

    func openGuidanceMap() {
        isPickingMapLocation = false
        pendingSaveCoordinate = nil
        shouldFocusAnchor = true
        homePath = NavigationPath()
        mapPath = NavigationPath()
        favoritesPath = NavigationPath()
        tab = .map
    }

    func dismissSearch() {
        isShowingSearch = false
        pendingSearchQuery = ""
    }

    func open(_ route: AppRoute) {
        if case .searchResults(let query) = route {
            presentSearch(query: query)
            return
        }
        if isShowingSearch {
            isShowingSearch = false
        }
        switch tab {
        case .home: homePath.append(route)
        case .map: mapPath.append(route)
        case .favorites: favoritesPath.append(route)
        case .account: accountPath.append(route)
        }
    }

    func select(_ tab: AppTab) {
        if tab == self.tab {
            popToRoot(tab)
        } else {
            self.tab = tab
        }
    }

    func resetToHome() {
        tab = .home
        homePath = NavigationPath()
    }

    private func popToRoot(_ tab: AppTab) {
        switch tab {
        case .home: homePath = NavigationPath()
        case .map: mapPath = NavigationPath()
        case .favorites: favoritesPath = NavigationPath()
        case .account: accountPath = NavigationPath()
        }
    }
}

@MainActor
final class AppEnvironment: ObservableObject {
    let settings: AppSettings
    let router: AppRouter
    let metro: MetroCatalogServing
    let places: PlaceDiscovering
    let routes: WalkingRouting
    let auth: InMemoryAuthService
    let favorites: FavoritesServing
    let submissions: InMemorySubmissionService
    let reports: ReportServing
    let location: LocationServing
    let images: ImageUploading
    let moderator: ModeratorServing
    let ranker = PlaceRanker()
    let nearestFinder = NearestStationFinder()
    let searchIndex = PlaceSearchIndex()
    let routeCache = WalkingRouteCache()

    var accessAssembler: AccessAssembler {
        AccessAssembler(
            routing: routes,
            exitSelector: VerifiedExitSelector(routing: routes),
            cache: routeCache
        )
    }

    init(
        settings: AppSettings,
        router: AppRouter,
        metro: MetroCatalogServing,
        places: PlaceDiscovering,
        routes: WalkingRouting,
        auth: InMemoryAuthService,
        favorites: FavoritesServing,
        submissions: InMemorySubmissionService,
        reports: ReportServing,
        location: LocationServing,
        images: ImageUploading,
        moderator: ModeratorServing
    ) {
        self.settings = settings
        self.router = router
        self.metro = metro
        self.places = places
        self.routes = routes
        self.auth = auth
        self.favorites = favorites
        self.submissions = submissions
        self.reports = reports
        self.location = location
        self.images = images
        self.moderator = moderator
    }

    static func live() -> AppEnvironment {
        let submissions = InMemorySubmissionService()
        return AppEnvironment(
            settings: AppSettings(),
            router: AppRouter(),
            metro: JSONMetroCatalogService(),
            places: MockPlaceDiscoveryService(),
            routes: StreetWalkingRouter(fallback: MockWalkingRouteService()),
            auth: InMemoryAuthService(),
            favorites: InMemoryFavoritesService(),
            submissions: submissions,
            reports: InMemoryReportService(),
            location: SystemLocationService(),
            images: InMemoryImageUploader(),
            moderator: InMemoryModeratorService(submissions: submissions)
        )
    }
}
