import SwiftUI

struct StationDetailView: View {
    var stationId: String
    @EnvironmentObject private var session: CatalogSession
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @State private var segment = 0
    @State private var category: PlaceCategory?
    @State private var isFavorite = false

    private var lang: AppLanguage { settings.language }
    private func t(_ key: String) -> String { DalilCopy.t(key, lang) }

    var body: some View {
        Group {
            if let catalog = session.catalog, let station = catalog.station(id: stationId) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.section) {
                        HStack(spacing: AppSpacing.chip) {
                            ForEach(catalog.lines(for: station)) { line in
                                LineBadge(line: line.lineColor, style: .pill, language: lang)
                            }
                        }
                        Picker("", selection: $segment) {
                            Text(t("station.seg.departures")).tag(0)
                            Text(t("station.seg.exits")).tag(1)
                            Text(t("station.seg.nearby")).tag(2)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel(t("station.seg.departures"))
                        content(station, catalog: catalog)
                    }
                    .padding(AppSpacing.screen)
                    .appTabBarClearance()
                }
                .background(AppColors.warmBackground.ignoresSafeArea())
                .navigationTitle(station.localizedName(language: lang))
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { toggleFavorite(station) } label: {
                            Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(isFavorite ? AppColors.mint : AppColors.primaryText)
                        }
                        .accessibilityLabel(t("place.save"))
                    }
                }
                .task {
                    session.markVisited(station.coordinate)
                    await refreshFavorite(station)
                }
            } else {
                ProgressView().task {
                    await session.loadCatalog()
                    if session.rankedPlaces.isEmpty { await session.load() }
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ station: MetroStation, catalog: MetroCatalog) -> some View {
        switch segment {
        case 1:
            exitsList(station, catalog: catalog)
        case 2:
            nearbyBlock(station)
        default:
            departuresList(station, catalog: catalog)
        }
    }

    private func departuresList(_ station: MetroStation, catalog: MetroCatalog) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            ForEach(catalog.lines(for: station)) { line in
                VStack(alignment: .leading, spacing: AppSpacing.item) {
                    LineBadge(line: line.lineColor, style: .pill, language: lang)
                    ForEach(MetroDepartureClock.rows(station: station, catalog: catalog, language: lang), id: \.direction) { row in
                        DepartureRow(direction: row.direction, minutes: row.minutes, language: lang)
                    }
                }
                .padding(AppSpacing.item)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            }
        }
    }

    private func exitsList(_ station: MetroStation, catalog: MetroCatalog) -> some View {
        let exits = catalog.exits(for: station.id)
        return VStack(alignment: .leading, spacing: AppSpacing.item) {
            if exits.isEmpty {
                Text(t("station.exits.empty"))
                    .appText(.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .padding(AppSpacing.item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            } else {
                ForEach(exits) { exit in
                    HStack(alignment: .top, spacing: AppSpacing.item) {
                        Text(exit.exitNumber)
                            .appLiveNumber(.headline)
                            .foregroundStyle(AppColors.cream)
                            .frame(width: AppSpacing.xl, height: AppSpacing.xl)
                            .background(AppColors.navy)
                            .clipShape(Circle())
                            .accessibilityLabel(DalilCopy.exitLabel(exit.exitNumber, lang))
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(exit.localizedName(language: lang))
                                .appText(.headline)
                                .foregroundStyle(AppColors.primaryText)
                                .lineLimit(2)
                            Text(exitNote(exit))
                                .appText(.subhead)
                                .foregroundStyle(AppColors.secondaryText)
                                .lineLimit(3)
                        }
                    }
                    .padding(AppSpacing.item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                }
            }
        }
    }

    private func nearbyBlock(_ station: MetroStation) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.tight) {
                    ForEach(BrowseCategory.allCases) { browse in
                        Button {
                            category = category == browse.placeCategory ? nil : browse.placeCategory
                        } label: {
                            CategoryChip(
                                browse: browse,
                                language: lang,
                                isSelected: category == browse.placeCategory
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            let items = uniquePlaces(stationPlaces(station).filter(matchesCategory))
            if items.isEmpty {
                Text(t("home.nearbyEmpty"))
                    .appText(.body)
                    .foregroundStyle(AppColors.secondaryText)
            } else {
                ForEach(items) { item in
                    Button { router.open(.place(item.place.id)) } label: {
                        PlaceRow(ranked: item, showsStation: false, language: lang)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func stationPlaces(_ station: MetroStation) -> [RankedPlace] {
        session.rankedPlaces(for: station.id)
    }

    private func uniquePlaces(_ items: [RankedPlace]) -> [RankedPlace] {
        var seen = Set<String>()
        return items.filter { item in
            let lat = (item.place.latitude * 10_000).rounded()
            let lon = (item.place.longitude * 10_000).rounded()
            let key = "\(item.place.nameEn.lowercased())|\(lat)|\(lon)"
            return seen.insert(key).inserted
        }
    }

    private func matchesCategory(_ item: RankedPlace) -> Bool {
        guard let category else { return true }
        if category == .park { return item.place.category == .park || item.place.category == .viewpoint }
        return item.place.category == category
    }

    private func exitNote(_ exit: StationExit) -> String {
        let landmark = lang == .arabic ? exit.nearbyLandmarkAr : exit.nearbyLandmarkEn
        let street = lang == .arabic ? exit.directionAr : exit.directionEn
        if !landmark.isEmpty { return landmark }
        if !street.isEmpty { return street }
        return t("walk.exit.followSign")
    }

    private func toggleFavorite(_ station: MetroStation) {
        Task {
            do {
                let user = try await environment.auth.requireSignedInUser()
                isFavorite = try await environment.favorites.toggle(userId: user.id, targetId: station.id, kind: .station)
            } catch {
                router.isShowingAuth = true
            }
        }
    }

    private func refreshFavorite(_ station: MetroStation) async {
        guard let user = environment.auth.currentUser else { return }
        isFavorite = (try? await environment.favorites.isFavorite(userId: user.id, targetId: station.id, kind: .station)) ?? false
    }
}
