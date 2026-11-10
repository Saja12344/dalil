import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var session: CatalogSession
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @State private var records: [FavoriteRecord] = []
    @State private var sort: PlaceSortMode = .walkingThenQuality
    @State private var renamingLocation: SavedLocation?

    private func t(_ key: String) -> String { DalilCopy.t(key, settings.language) }
    private var hasRecents: Bool { !settings.recentSearches.isEmpty }
    private var hasSaved: Bool { !records.isEmpty }
    private var hasPinned: Bool { !settings.savedLocations.isEmpty }

    var body: some View {
        tripsList
        .background(AppColors.warmBackground.ignoresSafeArea())
        .navigationTitle(t("favorites.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $renamingLocation) { item in
            SaveLocationSheet(mode: .rename(item), nearestSummary: nil)
        }
        .task { await load() }
    }

    private var tripsList: some View {
        List {
            if hasPinned {
                Section {
                    ForEach(settings.savedLocations) { location in
                        Button {
                            router.open(.savedTrip(location.id))
                        } label: {
                            HStack(spacing: AppSpacing.item) {
                                DalilIcon(glyph: location.kind.glyph, size: 30)
                                    .frame(width: AppSize.touch, height: AppSize.touch)
                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text(location.title(settings.language))
                                        .appText(.headline)
                                        .foregroundStyle(AppColors.primaryText)
                                        .lineLimit(1)
                                    Text(t("saved.useHint"))
                                        .appText(.subhead)
                                        .foregroundStyle(AppColors.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .themedRow()
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if location.kind == .custom {
                                Button {
                                    renamingLocation = location
                                } label: {
                                    Label(t("saved.rename"), systemImage: "pencil")
                                }
                            }
                            Button {
                                router.presentMapPicker(.relocate(location.id))
                            } label: {
                                Label(t("saved.move"), systemImage: "map")
                            }
                            Button(role: .destructive) {
                                settings.removeSavedLocation(id: location.id)
                            } label: {
                                Label(t("saved.delete"), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                settings.removeSavedLocation(id: location.id)
                            } label: {
                                Label(t("saved.delete"), systemImage: "trash")
                            }
                        }
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionTitle(t("saved.title"))
                }
            }

            if hasRecents {
                Section {
                    ForEach(settings.recentSearches, id: \.self) { item in
                        Button {
                            router.presentSearch(query: item)
                        } label: {
                            HStack(spacing: AppSpacing.item) {
                                DalilIcon(glyph: .search, size: 26, shadow: false)
                                    .frame(width: AppSize.touch, height: AppSize.touch)
                                Text(item)
                                    .appText(.headline)
                                    .foregroundStyle(AppColors.primaryText)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .themedRow()
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

            Section {
                if environment.auth.currentUser == nil {
                    savedEmpty(signedOut: true)
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else if !hasSaved {
                    savedEmpty(signedOut: false)
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(placeItems) { item in
                        Button { router.open(.place(item.place.id)) } label: {
                            PlaceRow(ranked: item, language: settings.language)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    ForEach(stationItems) { station in
                        Button { router.open(.station(station.id)) } label: {
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
                }
            } header: {
                sectionTitle(t("favorites.saved"))
            }

            if !hasSaved, !suggestions.isEmpty {
                Section {
                    ForEach(suggestions) { item in
                        HStack(spacing: AppSpacing.tight) {
                            Button { router.open(.place(item.place.id)) } label: {
                                PlaceRow(ranked: item, language: settings.language)
                            }
                            .buttonStyle(.plain)
                            Button { save(item.place.id) } label: {
                                DalilIcon(glyph: .saved, size: 28, shadow: false)
                                    .frame(width: AppSize.touch, height: AppSize.touch)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(t("place.save"))
                        }
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionTitle(t("favorites.suggest"))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .appTabBarClearance()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .appText(.title)
            .foregroundStyle(AppColors.primaryText)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: AppSpacing.xxs, leading: AppSpacing.screen, bottom: AppSpacing.xxs, trailing: AppSpacing.screen)
    }

    /// Theme card: the same black sign as home, with the saved icon and one action.
    private func savedEmpty(signedOut: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.item) {
            VStack(alignment: .leading, spacing: AppSpacing.tight) {
                Text(t(signedOut ? "favorites.signedOut.title" : "favorites.empty.title"))
                    .font(AppTypography.extraBold(24))
                    .foregroundStyle(AppColors.cream)
                Text(t(signedOut ? "favorites.signedOut.short" : "favorites.empty.body"))
                    .appText(.subhead)
                    .foregroundStyle(AppColors.cream.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                if signedOut {
                    Button { router.isShowingAuth = true } label: {
                        Text(t("auth.signIn"))
                            .appText(.headline)
                            .foregroundStyle(AppColors.onAccent)
                            .padding(.horizontal, AppSpacing.screen)
                            .frame(height: AppSize.chip + AppSpacing.xxs)
                            .background(AppColors.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, AppSpacing.xxs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DalilIcon(glyph: .saved, size: 56, shadow: false)
                .environment(\.colorScheme, .dark)
        }
        .padding(AppSpacing.screen)
        .background(AppColors.night)
        .overlay(alignment: .bottom) {
            AppColors.accent.frame(height: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var suggestions: [RankedPlace] {
        Array(session.rankedPlaces.prefix(4))
    }

    private func save(_ placeId: String) {
        Task {
            guard let user = await environment.auth.currentUser else {
                router.isShowingAuth = true
                return
            }
            _ = try? await environment.favorites.toggle(userId: user.id, targetId: placeId, kind: .place)
            await load()
        }
    }

    private var placeItems: [RankedPlace] {
        let ids = Set(records.filter { $0.targetKind == .place }.map(\.targetId))
        var items = session.rankedPlaces.filter { ids.contains($0.place.id) }
        switch sort {
        case .walkingThenQuality, .nearest:
            items.sort { $0.access.displayedMinutes < $1.access.displayedMinutes }
        case .byLine:
            items.sort { $0.access.station.lineIds.first ?? "" < $1.access.station.lineIds.first ?? "" }
        }
        return items
    }

    private var stationItems: [MetroStation] {
        let ids = Set(records.filter { $0.targetKind == .station }.map(\.targetId))
        return (session.catalog?.stations ?? []).filter { ids.contains($0.id) }
    }

    private func load() async {
        if session.catalog == nil { await session.load() }
        guard let user = await environment.auth.currentUser else {
            records = []
            return
        }
        records = (try? await environment.favorites.favorites(for: user.id)) ?? []
    }
}

private extension View {
    /// Card row used across the trips page: surface, hairline, 16 radius.
    func themedRow() -> some View {
        padding(.horizontal, AppSpacing.item)
            .padding(.vertical, AppSpacing.tight)
            .background(AppColors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}
