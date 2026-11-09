import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var session: CatalogSession
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @State private var savedPlaceIDs: Set<String> = []

    private let cardHeight: CGFloat = 296

    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width - AppSpacing.screen - 18
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    header
                        .padding(.horizontal, AppSpacing.screen)
                    VStack(alignment: .leading, spacing: AppSpacing.item) {
                        SearchLaunchButton {
                            router.open(.searchResults(""))
                        }
                        NearMeChip {
                            Task { await session.useNearMe() }
                        }
                        if session.usedUserLocation {
                            Text("home.usingLocation")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screen)
                    if let catalog = session.catalog {
                        MetroPreviewCard(catalog: catalog) { station in
                            router.open(.station(station.id))
                        } onOpenFullMap: {
                            router.open(.metroMap)
                        }
                        .padding(.horizontal, AppSpacing.screen)
                    }
                    if session.isLoading {
                        PlaceCardSkeleton()
                            .padding(.horizontal, AppSpacing.screen)
                    } else if session.errorMessage != nil {
                        ErrorStateView { Task { await session.load() } }
                            .padding(.horizontal, AppSpacing.screen)
                    } else {
                        sections(cardWidth: cardWidth)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollClipDisabled()
        }
        .background(AppColors.warmBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if session.catalog == nil {
                await session.load()
            }
            await refreshSaved()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                NazlahWordmark(subtitle: "explore.englishName")
                Spacer()
                Button {
                    requireAuthThen { router.open(.addPlace) }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(AppColors.navy)
                        .clipShape(Circle())
                }
                .accessibilityLabel("add.title")
            }
            HStack {
                Text("explore.live")
                    .font(AppTypography.regular(11))
                    .foregroundStyle(AppColors.onLime)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.lime)
                    .clipShape(Capsule())
                Spacer()
                if let station = session.nearestStation {
                    Text(station.localizedName(language: settings.language))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(1)
                }
            }
            Text("explore.title")
                .font(AppTypography.extraBold(28))
                .foregroundStyle(AppColors.navy)
            Text("explore.subtitle")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
        }
    }

    @ViewBuilder
    private func sections(cardWidth: CGFloat) -> some View {
        placeRail(title: "home.worth", items: session.ranked(matching: [.worthTheStop]), cardWidth: cardWidth)
        placeRail(title: "home.inside", items: session.ranked(matching: [.insideStation]), cardWidth: cardWidth)
        placeRail(title: "home.five", items: session.ranked(matching: [.underFiveMinutes]), cardWidth: cardWidth)
        placeRail(title: "home.work", items: session.ranked(matching: [.workFriendly]), cardWidth: cardWidth)
        placeRail(title: "home.sitting", items: session.ranked(matching: [.sitting]), cardWidth: cardWidth)
        placeRail(title: "home.food", items: session.ranked(matching: [.restaurant]), cardWidth: cardWidth)
        placeRail(title: "home.open", items: session.ranked(matching: [.openNow]), cardWidth: cardWidth)
        lineExplorer
        suggestedStations
    }

    private func placeRail(title: LocalizedStringKey, items: [RankedPlace], cardWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            SectionHeader(title: title) {
                router.open(.searchResults(""))
            }
            .padding(.horizontal, AppSpacing.screen)
            if items.isEmpty {
                Text("state.empty.section")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .padding(.horizontal, AppSpacing.screen)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.item) {
                        ForEach(items.prefix(8)) { item in
                            Button {
                                router.open(.place(item.place.id))
                            } label: {
                                PlaceCard(
                                    ranked: item,
                                    language: settings.language,
                                    lines: session.catalog?.lines(for: item.access.station) ?? [],
                                    isSaved: savedPlaceIDs.contains(item.place.id),
                                    onSave: { toggleSave(item.place.id) }
                                )
                                .frame(width: cardWidth, height: cardHeight, alignment: .top)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, AppSpacing.screen)
                    .padding(.trailing, 18)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var lineExplorer: some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            SectionHeader(title: "home.byLine") {
                router.tab = .map
            }
            .padding(.horizontal, AppSpacing.screen)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(session.catalog?.lines.sorted(by: { $0.displayOrder < $1.displayOrder }) ?? []) { line in
                        Button {
                            router.tab = .map
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Circle()
                                    .fill(Color(hex: line.colorHex))
                                    .frame(width: 10, height: 10)
                                Text(line.localizedName(language: settings.language))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.primaryText)
                                    .lineLimit(1)
                            }
                            .padding(14)
                            .frame(minWidth: 108, alignment: .leading)
                            .background(AppColors.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
            }
            .scrollClipDisabled()
        }
    }

    private var suggestedStations: some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            SectionHeader(title: "home.stations") {
                router.tab = .map
            }
            let suggested = (session.catalog?.stations ?? []).filter {
                ["kafd", "stc", "bank_albilad", "national_museum", "qasr_al_hokm"].contains($0.id)
            }
            ForEach(suggested) { station in
                Button {
                    router.open(.station(station.id))
                } label: {
                    StationCard(
                        station: station,
                        lines: session.catalog?.lines(for: station) ?? [],
                        placeCount: session.rankedPlaces.filter { $0.place.stationId == station.id }.count,
                        language: settings.language
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.screen)
    }

    private func toggleSave(_ placeId: String) {
        requireAuthThen {
            Task {
                guard let user = await environment.auth.currentUser else { return }
                if let saved = try? await environment.favorites.toggle(userId: user.id, targetId: placeId, kind: .place) {
                    if saved {
                        savedPlaceIDs.insert(placeId)
                    } else {
                        savedPlaceIDs.remove(placeId)
                    }
                }
            }
        }
    }

    private func refreshSaved() async {
        guard let user = await environment.auth.currentUser else { return }
        let records = (try? await environment.favorites.favorites(for: user.id)) ?? []
        savedPlaceIDs = Set(records.filter { $0.targetKind == .place }.map(\.targetId))
    }

    private func requireAuthThen(_ action: @escaping () -> Void) {
        Task {
            do {
                _ = try await environment.auth.requireSignedInUser()
                action()
            } catch {
                router.pendingAuthRoute = .addPlace
                router.isShowingAuth = true
            }
        }
    }
}
