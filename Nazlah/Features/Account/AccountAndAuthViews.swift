import AuthenticationServices
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var session: CatalogSession
    @State private var signOutFailed = false

    private var lang: AppLanguage { settings.language }
    private func t(_ key: String) -> String { DalilCopy.t(key, lang) }

    var body: some View {
        Form {
            Section {
                header
            }

            Section {
                savedSlotRow(kind: .home, location: settings.homeLocation)
                savedSlotRow(kind: .work, location: settings.workLocation)
                ForEach(settings.customLocations) { location in
                    savedRow(location)
                }
                Button { router.presentMapPicker(.add) } label: {
                    rowLabel("plus", t("home.quick.add"))
                }
            } header: {
                Text(t("account.myPlaces"))
            }

            Section {
                languageRow
                VStack(alignment: .leading, spacing: AppSpacing.tight) {
                    Text(t("account.appearance"))
                        .appText(.body)
                        .foregroundStyle(AppColors.primaryText)
                    Picker(t("account.appearance"), selection: appearanceBinding) {
                        Text(t("appearance.light")).tag(AppearancePreference.light)
                        Text(t("appearance.dark")).tag(AppearancePreference.dark)
                        Text(t("appearance.system")).tag(AppearancePreference.system)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(.vertical, AppSpacing.xxs)
                Toggle(isOn: $settings.notificationsEnabled) {
                    Text(t("account.notifications"))
                        .appText(.body)
                        .foregroundStyle(AppColors.primaryText)
                }
                .tint(AppColors.mint)
            } header: {
                Text(t("account.preferences"))
            }

            Section {
                formLink("plus.square", t("account.submissions"), .submissions)
                formLink("flag", t("account.reports"), .reports)
                if environment.auth.currentUser?.role == .moderator || environment.auth.currentUser?.role == .admin {
                    formLink("tray", t("moderator.title"), .moderator)
                }
            } header: {
                Text(t("account.contributions"))
            }

            Section {
                formLink("lock", t("account.privacy"), .privacy)
                formLink("info.circle", t("account.sources"), .sources)
                formLink("questionmark.circle", t("account.support"), .support)
                HStack {
                    rowLabel("number", t("account.version"))
                    Spacer()
                    Text(appVersion)
                        .appText(.subhead)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.secondaryText)
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text(t("account.aboutSection"))
            }

            if environment.auth.currentUser != nil {
                Section {
                    Button(t("account.signOut")) {
                        Task {
                            do { try await environment.auth.signOut() } catch { signOutFailed = true }
                        }
                    }
                    .appText(.body)
                    .foregroundStyle(AppColors.primaryText)
                }
                Section {
                    NavigationLink(value: AppRoute.deleteAccount) {
                        Text(t("account.delete"))
                            .appText(.body)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text(t("account.made"))
                        .appText(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.section)
                }
            } else {
                Section {
                } footer: {
                    Text(t("account.made"))
                        .appText(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.warmBackground.ignoresSafeArea())
        .navigationTitle(t("account.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(t("account.signOut.failed"), isPresented: $signOutFailed) {
            Button(t("common.ok"), role: .cancel) {}
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: AppSpacing.item) {
            avatar
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if let user = environment.auth.currentUser {
                    Text(user.displayName)
                        .appText(.title)
                        .foregroundStyle(AppColors.primaryText)
                        .lineLimit(1)
                    Text(t("role.\(user.role.rawValue)"))
                        .appText(.subhead)
                        .foregroundStyle(AppColors.secondaryText)
                } else {
                    Text(t("account.signInPrompt"))
                        .appText(.headline)
                        .foregroundStyle(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { router.isShowingAuth = true } label: {
                        Text(t("auth.signIn"))
                            .appText(.subhead)
                            .foregroundStyle(AppColors.warmBackground)
                            .padding(.horizontal, AppSpacing.item)
                            .frame(height: AppSize.chip)
                            .background(AppColors.primaryText)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, AppSpacing.xxs)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.tight)
        .listRowBackground(AppColors.cardSurface)
    }

    private var avatar: some View {
        Group {
            if let initials = initials {
                Text(initials)
                    .appText(.title)
                    .foregroundStyle(AppColors.primaryText)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: AppTextStyle.title.size, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .frame(width: AppSize.thumb, height: AppSize.thumb)
        .background(AppColors.softSand)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: String? {
        guard let name = environment.auth.currentUser?.displayName else { return nil }
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? nil : letters.joined()
    }

    // MARK: Saved places

    private func savedSlotRow(kind: SavedLocation.Kind, location: SavedLocation?) -> some View {
        Group {
            if let location {
                savedRow(location)
            } else {
                Button { router.presentMapPicker(kind == .home ? .home : .work) } label: {
                    rowLabel(kind.emptySystemImage, t(kind == .home ? "home.quick.addHome" : "home.quick.addWork"))
                }
            }
        }
    }

    private func savedRow(_ location: SavedLocation) -> some View {
        Button { router.presentMapPicker(.relocate(location.id)) } label: {
            HStack(spacing: AppSpacing.item) {
                Image(systemName: location.kind.systemImage)
                    .font(.system(size: AppTextStyle.body.size, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(width: AppSpacing.section)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(location.title(lang))
                        .appText(.body)
                        .foregroundStyle(AppColors.primaryText)
                    if let station = session.nearestStation(to: location.coordinate) {
                        Text("\(t("account.nearestStation")) · \(station.localizedName(language: lang))")
                            .appText(.subhead)
                            .foregroundStyle(AppColors.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.system(size: AppTextStyle.caption.size, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                settings.removeSavedLocation(id: location.id)
            } label: {
                Label(t("saved.delete"), systemImage: "trash")
            }
        }
    }

    // MARK: Rows

    private func rowLabel(_ icon: String, _ title: String) -> some View {
        Label {
            Text(title)
                .appText(.body)
                .foregroundStyle(AppColors.primaryText)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(AppColors.secondaryText)
        }
    }

    private var languageRow: some View {
        HStack {
            Text(t("account.language"))
                .appText(.body)
                .foregroundStyle(AppColors.primaryText)
            Spacer()
            Menu {
                Button(t("lang.ar")) { settings.language = .arabic }
                Button(t("lang.en")) { settings.language = .english }
            } label: {
                HStack(spacing: AppSpacing.xxs) {
                    Text(t(lang == .arabic ? "lang.ar" : "lang.en"))
                        .appText(.subhead)
                        .foregroundStyle(AppColors.secondaryText)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: AppTextStyle.caption.size, weight: .semibold))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .accessibilityLabel(t("account.language"))
        }
    }

    private var appearanceBinding: Binding<AppearancePreference> {
        Binding(
            get: { settings.appearance },
            set: { settings.appearance = $0 }
        )
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    private func formLink(_ icon: String, _ title: String, _ route: AppRoute) -> some View {
        NavigationLink(value: route) {
            rowLabel(icon, title)
        }
    }
}


struct AuthSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.section) {
                Text("auth.title")
                    .appText(.largeTitle)
                    .foregroundStyle(AppColors.primaryText)
                Text("auth.body")
                    .appText(.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    Task { await handle(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: AppSize.search)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                #if DEBUG
                Button("auth.devUser") {
                    environment.auth.signInMockUser()
                    finish()
                }
                .appText(.caption)
                Button("auth.devModerator") {
                    environment.auth.signInMockModerator()
                    finish()
                }
                .appText(.caption)
                #endif
                Spacer()
            }
            .padding(AppSpacing.section)
            .background(AppColors.warmBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("auth.close") { dismiss() }
                }
            }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) async {
        if case .success(let auth) = result,
           let credential = auth.credential as? ASAuthorizationAppleIDCredential,
           let token = credential.identityToken,
           let code = credential.authorizationCode {
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            _ = try? await environment.auth.signInWithApple(identityToken: token, authorizationCode: code, fullName: name)
            finish()
        }
    }

    private func finish() {
        router.isShowingAuth = false
        dismiss()
    }
}

struct SearchResultsView: View {
    var initialQuery: String
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var session: CatalogSession
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var savedRecords: [FavoriteRecord] = []

    private func t(_ key: String) -> String { DalilCopy.t(key, settings.language) }
    private var typedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isIdle: Bool { typedQuery.isEmpty }

    var body: some View {
        VStack(spacing: AppSpacing.item) {
            searchChrome
            if isIdle {
                idleList
            } else if filteredStations.isEmpty && filteredPlaces.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .padding(.top, AppSpacing.item)
        .background(AppColors.warmBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .environment(\.locale, settings.locale)
        .environment(\.layoutDirection, settings.layoutDirection)
        .onChange(of: initialQuery) { _, newValue in
            if !newValue.isEmpty { query = newValue }
        }
        .onChange(of: router.pendingSearchQuery) { _, newValue in
            guard !newValue.isEmpty else { return }
            query = newValue
            router.pendingSearchQuery = ""
        }
        .task {
            if !initialQuery.isEmpty { query = initialQuery }
            if !router.pendingSearchQuery.isEmpty {
                query = router.pendingSearchQuery
                router.pendingSearchQuery = ""
            }
            if session.catalog == nil { await session.load() }
            await loadSaved()
        }
    }

    private var searchChrome: some View {
        HStack(spacing: AppSpacing.tight) {
            SearchField(
                placeholder: t("home.search"),
                text: $query,
                trailingSystemImage: nil,
                trailingAction: nil,
                onSubmit: { settings.rememberSearch(typedQuery) },
                autoFocus: true
            )
            Button(t("search.cancel")) { close() }
                .appText(.headline)
                .foregroundStyle(AppColors.primaryText)
                .padding(.trailing, AppSpacing.screen)
        }
        .padding(.leading, AppSpacing.xxs)
    }

    private var idleList: some View {
        List {
            if !settings.recentSearches.isEmpty {
                Section {
                    ForEach(settings.recentSearches, id: \.self) { item in
                        Button {
                            query = item
                        } label: {
                            recentRow(item)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                settings.removeSearch(item)
                            } label: {
                                Label(t("search.clear"), systemImage: "trash")
                            }
                        }
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionTitle(t("search.recent"))
                }
            }

            if !savedPlaces.isEmpty {
                Section {
                    ForEach(savedPlaces) { item in
                        Button { reveal(.place(item.place.id), remember: item.place.localizedName(language: settings.language)) } label: {
                            PlaceRow(ranked: item, language: settings.language)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionTitle(t("favorites.saved"))
                }
            }

            if !nearbyStations.isEmpty {
                Section {
                    ForEach(nearbyStations) { station in
                        stationButton(station)
                    }
                } header: {
                    sectionTitle(t("search.nearbyStations"))
                }
            }

            Section {
                browseChips
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } header: {
                sectionTitle(t("search.browse"))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var resultsList: some View {
        List {
            if !filteredStations.isEmpty {
                Section {
                    ForEach(filteredStations) { station in
                        stationButton(station)
                    }
                } header: {
                    sectionTitle(t("search.stations"))
                }
            }
            if !filteredPlaces.isEmpty {
                Section {
                    ForEach(filteredPlaces) { item in
                        Button { reveal(.place(item.place.id), remember: typedQuery) } label: {
                            PlaceRow(ranked: item, language: settings.language)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionTitle(t("search.places"))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            Text(t("search.empty.suggest"))
                .appText(.body)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.item)
                .background(AppColors.cardSurface)
                .dalilCard()
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screen)
    }

    private var browseChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.tight) {
                ForEach(BrowseCategory.allCases) { browse in
                    Button {
                        query = t(browse.copyKey)
                    } label: {
                        CategoryChip(browse: browse, language: settings.language, isSelected: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func recentRow(_ item: String) -> some View {
        HStack(spacing: AppSpacing.item) {
            Image(systemName: "clock")
                .font(.system(size: AppTextStyle.body.size, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)
                .frame(width: AppSize.touch, height: AppSize.touch)
                .background(AppColors.softSand)
                .clipShape(Circle())
            Text(item)
                .appText(.headline)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private func stationButton(_ station: MetroStation) -> some View {
        Button { reveal(.station(station.id), remember: station.localizedName(language: settings.language)) } label: {
            HStack(spacing: AppSpacing.item) {
                Image(systemName: "tram.fill")
                    .font(.system(size: AppTextStyle.body.size, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(width: AppSize.touch, height: AppSize.touch)
                    .background(AppColors.softSand)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                Text(station.localizedName(language: settings.language))
                    .appText(.headline)
                    .foregroundStyle(AppColors.primaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: AppSpacing.tight)
                HStack(spacing: AppSpacing.xxs) {
                    ForEach(session.catalog?.lines(for: station) ?? []) { line in
                        LineBadge(line: line.lineColor, style: .number, language: settings.language)
                    }
                }
            }
            .padding(.vertical, AppSpacing.xxs)
        }
        .buttonStyle(.plain)
        .listRowInsets(rowInsets)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .appText(.title)
            .foregroundStyle(AppColors.primaryText)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppSpacing.xxs)
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: AppSpacing.xxs, leading: AppSpacing.screen, bottom: AppSpacing.xxs, trailing: AppSpacing.screen)
    }

    private var allPlaces: [RankedPlace] {
        session.placesByStation.values.flatMap { $0 }
    }

    private var savedPlaces: [RankedPlace] {
        let ids = Set(savedRecords.filter { $0.targetKind == .place }.map(\.targetId))
        return Array(allPlaces.filter { ids.contains($0.place.id) }.prefix(4))
    }

    private var nearbyStations: [MetroStation] {
        guard let catalog = session.catalog else { return [] }
        return Array(
            catalog.stations
                .sorted { $0.coordinate.distanceMeters(to: session.anchor) < $1.coordinate.distanceMeters(to: session.anchor) }
                .prefix(2)
        )
    }

    private var filteredStations: [MetroStation] {
        guard !typedQuery.isEmpty else { return [] }
        return (session.catalog?.stations ?? []).filter {
            $0.localizedName(language: settings.language).localizedCaseInsensitiveContains(typedQuery)
                || $0.nameAr.localizedCaseInsensitiveContains(typedQuery)
                || $0.nameEn.localizedCaseInsensitiveContains(typedQuery)
        }
    }

    private var filteredPlaces: [RankedPlace] {
        let q = typedQuery
        guard !q.isEmpty else { return [] }
        if let browse = BrowseCategory.allCases.first(where: { t($0.copyKey).caseInsensitiveCompare(q) == .orderedSame }) {
            return allPlaces.filter { $0.place.category == browse.placeCategory }
        }
        let index = PlaceSearchIndex()
        return allPlaces.filter { item in
            index.matches(item.place, station: item.access.station, query: q, language: settings.language)
        }
    }

    private func reveal(_ route: AppRoute, remember raw: String) {
        settings.rememberSearch(raw)
        close()
        router.open(route)
    }

    private func close() {
        if router.isShowingSearch {
            router.dismissSearch()
        } else {
            dismiss()
        }
    }

    private func loadSaved() async {
        guard let user = environment.auth.currentUser else {
            savedRecords = []
            return
        }
        savedRecords = (try? await environment.favorites.favorites(for: user.id)) ?? []
    }
}

struct HomeBrowseView: View {
    var kind: HomeBrowse
    @EnvironmentObject private var session: CatalogSession
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @State private var sort: BrowseSort = .walk
    @State private var walkLimit: Int? = nil
    @State private var nearMyStation = false

    private var lang: AppLanguage { settings.language }
    private func t(_ key: String) -> String { DalilCopy.t(key, lang) }

    var body: some View {
        Group {
            if kind == .stations {
                stationsList
            } else {
                placesList
            }
        }
        .background(AppColors.warmBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if session.catalog == nil { await session.load() }
        }
    }

    private var title: String {
        switch kind {
        case .stations: t("home.cat.stations")
        case .tourism: t("home.cat.tourism")
        case .parks: t("home.cat.parks")
        case .clubs: t("home.cat.clubs")
        case .restaurant: t("cat.restaurant")
        case .cafe: t("cat.cafe")
        case .pharmacy: t("cat.pharmacy")
        }
    }

    private var stationsList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.tight) {
                ForEach(session.catalog?.stations ?? []) { station in
                    Button { router.open(.station(station.id)) } label: {
                        HStack(spacing: AppSpacing.item) {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(station.localizedName(language: lang))
                                    .appText(.headline)
                                    .foregroundStyle(AppColors.primaryText)
                                Text(t("home.cat.stations.sub"))
                                    .appText(.subhead)
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.system(size: AppTextStyle.caption.size, weight: .semibold))
                                .foregroundStyle(AppColors.secondaryText)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, AppSpacing.screen)
                        .frame(minHeight: AppSize.placeRow)
                        .background(AppColors.cardSurface)
                        .dalilCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.screen)
            .padding(.bottom, AppSpacing.section)
        }
    }

    private var placesList: some View {
        let items = filteredPlaces
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.tight, pinnedViews: [.sectionHeaders]) {
                Section {
                    Text(DalilCopy.results(items.count, lang))
                        .appText(.subhead)
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.top, AppSpacing.xxs)
                    if items.isEmpty {
                        Text(t(matchingPlaces.isEmpty ? "browse.empty" : "browse.filtered.empty"))
                            .appText(.body)
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.screen)
                            .background(AppColors.cardSurface)
                            .dalilCard()
                    }
                    ForEach(items) { item in
                        Button { router.open(.place(item.place.id)) } label: {
                            PlaceRow(ranked: item, language: lang)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    filterBar
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.section)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.tight) {
                Menu {
                    Picker(t("browse.sort"), selection: $sort) {
                        Text(t("browse.sort.walk")).tag(BrowseSort.walk)
                        Text(t("browse.sort.me")).tag(BrowseSort.nearMe)
                    }
                } label: {
                    FilterChipLabel(
                        title: t(sort == .walk ? "browse.sort.walk" : "browse.sort.me"),
                        systemImage: "arrow.up.arrow.down",
                        isSelected: false,
                        showsChevron: true
                    )
                }
                .accessibilityLabel(t("browse.sort"))

                ForEach([5, 10, 15], id: \.self) { limit in
                    Button {
                        walkLimit = walkLimit == limit ? nil : limit
                    } label: {
                        FilterChipLabel(
                            title: DalilCopy.walkUpTo(limit, lang),
                            systemImage: "figure.walk",
                            isSelected: walkLimit == limit
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let station = myStation {
                    Button { nearMyStation.toggle() } label: {
                        FilterChipLabel(
                            title: station.localizedName(language: lang),
                            systemImage: "tram.fill",
                            isSelected: nearMyStation
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(t("browse.nearStation"))
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.vertical, AppSpacing.tight)
        }
        .padding(.horizontal, -AppSpacing.screen)
        .background(AppColors.warmBackground)
    }

    private var myStation: MetroStation? {
        session.nearestStation(to: session.anchor)
    }

    private var filteredPlaces: [RankedPlace] {
        var items = matchingPlaces
        if let walkLimit {
            items = items.filter { $0.access.displayedMinutes <= walkLimit }
        }
        if nearMyStation, let station = myStation {
            items = items.filter { $0.access.station.id == station.id }
        }
        switch sort {
        case .walk:
            return items.sorted { $0.access.displayedMinutes < $1.access.displayedMinutes }
        case .nearMe:
            let anchor = session.anchor
            return items.sorted {
                $0.place.coordinate.distanceMeters(to: anchor) < $1.place.coordinate.distanceMeters(to: anchor)
            }
        }
    }

    private var matchingPlaces: [RankedPlace] {
        let all = session.placesByStation.values.flatMap { $0 }
        switch kind {
        case .stations:
            return []
        case .parks:
            return all.filter { $0.place.category == .park || $0.place.category == .viewpoint }
        case .clubs:
            return all.filter { $0.place.category == .gym }
        case .tourism:
            return all.filter { isTourism($0.place) }
        case .restaurant:
            return all.filter { $0.place.category == .restaurant || $0.place.category == .dessert }
        case .cafe:
            return all.filter { $0.place.category == .cafe || $0.place.category == .cowork }
        case .pharmacy:
            return all.filter { $0.place.category == .pharmacy }
        }
    }

    private func isTourism(_ place: Place) -> Bool {
        if place.category == .viewpoint { return true }
        let blob = (place.nameAr + " " + place.nameEn + " " + place.shortDescriptionAr).lowercased()
        let keys = ["متحف", "museum", "قصر", "palace", "برج", "tower", "سياح", "attraction", "heritage", "تراث"]
        return keys.contains { blob.contains($0) }
    }
}

private enum BrowseSort: Hashable {
    case walk
    case nearMe
}

private struct FilterChipLabel: View {
    var title: String
    var systemImage: String
    var isSelected: Bool
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: AppSpacing.chip) {
            Image(systemName: systemImage)
                .font(.system(size: AppTextStyle.subhead.size, weight: .semibold))
            Text(title)
                .appText(.subhead)
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: AppTextStyle.caption.size, weight: .semibold))
            }
        }
        .foregroundStyle(isSelected ? AppColors.warmBackground : AppColors.primaryText)
        .padding(.horizontal, AppSpacing.item)
        .frame(height: AppSize.chip)
        .background(isSelected ? AppColors.primaryText : AppColors.cardSurface)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

enum LegalPageKind {
    case privacy, sources, support
}

struct LegalPageView: View {
    var kind: LegalPageKind
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ScrollView {
            Text(DalilCopy.t(copyKey, settings.language))
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .padding(AppSpacing.screen)
        }
        .background(AppColors.warmBackground.ignoresSafeArea())
        .navigationTitle(DalilCopy.t(copyKey, settings.language))
    }

    private var copyKey: String {
        switch kind {
        case .privacy: "account.privacy"
        case .sources: "account.sources"
        case .support: "account.support"
        }
    }
}

struct DeleteAccountView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    @State private var failed = false

    private func t(_ key: String) -> String { DalilCopy.t(key, settings.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.screen) {
            Text(t("account.delete"))
                .appText(.title)
                .foregroundStyle(AppColors.primaryText)
            Text(t("account.delete.body"))
                .appText(.body)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(role: .destructive) {
                Task { await delete() }
            } label: {
                Group {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Text(t("account.delete")).appText(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.button)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDeleting)
        }
        .padding(AppSpacing.screen)
        .background(AppColors.warmBackground.ignoresSafeArea())
        .navigationTitle(t("account.delete"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(t("account.delete.failed"), isPresented: $failed) {
            Button(t("common.ok"), role: .cancel) {}
        }
    }

    private func delete() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await environment.auth.deleteAccount()
            dismiss()
        } catch {
            failed = true
        }
    }
}

struct MySubmissionsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var items: [PlaceSubmission] = []

    var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.nameAr).font(AppTypography.semibold(16))
                Text(item.status.rawValue).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
        }
        .navigationTitle("account.submissions")
        .task {
            guard let user = await environment.auth.currentUser else { return }
            items = (try? await environment.submissions.submissions(for: user.id)) ?? []
        }
    }
}

struct MyReportsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var items: [PlaceReport] = []

    var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.reason.rawValue).font(AppTypography.semibold(16))
                Text(item.status.rawValue).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
        }
        .navigationTitle("account.reports")
        .task {
            guard let user = await environment.auth.currentUser else { return }
            items = (try? await environment.reports.reports(for: user.id)) ?? []
        }
    }
}

struct ReportSheet: View {
    var place: Place
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason = ReportReason.allCases.first ?? .closed
    @State private var details = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("place.report", selection: $reason) {
                    ForEach(ReportReason.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                TextField("place.report", text: $details, axis: .vertical)
            }
            .navigationTitle("place.report")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("place.report") {
                        Task {
                            guard let user = await environment.auth.currentUser else { return }
                            try? await environment.reports.submit(
                                PlaceReport(
                                    id: UUID().uuidString,
                                    userId: user.id,
                                    placeId: place.id,
                                    reason: reason,
                                    details: details,
                                    status: .open,
                                    createdAt: Date()
                                )
                            )
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

