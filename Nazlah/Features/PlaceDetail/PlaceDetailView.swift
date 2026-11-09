import SwiftUI
import UIKit

struct PlaceDetailView: View {
    var placeId: String
    @EnvironmentObject private var session: CatalogSession
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @State private var ranked: RankedPlace?
    @State private var isFavorite = false
    @State private var showReport = false
    @State private var showNavTitle = false

    private var lang: AppLanguage { settings.language }
    private func t(_ key: String) -> String { DalilCopy.t(key, lang) }

    var body: some View {
        Group {
            if let ranked {
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            hero(ranked)
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(
                                            key: PlaceHeroOffsetKey.self,
                                            value: proxy.frame(in: .named("placeScroll")).minY
                                        )
                                    }
                                )
                            VStack(alignment: .leading, spacing: AppSpacing.section) {
                                identity(ranked)
                                summaryStrip(ranked)
                                routeTimeline(ranked)
                                Button(t("place.report")) {
                                    Task {
                                        do {
                                            _ = try await environment.auth.requireSignedInUser()
                                            showReport = true
                                        } catch {
                                            router.isShowingAuth = true
                                        }
                                    }
                                }
                                .appText(.caption)
                                .foregroundStyle(AppColors.secondaryText)
                            }
                            .padding(AppSpacing.screen)
                            .padding(.bottom, AppSpacing.item)
                        }
                    }
                    .coordinateSpace(name: "placeScroll")
                    .onPreferenceChange(PlaceHeroOffsetKey.self) { value in
                        showNavTitle = value < -120
                    }
                    dock(ranked)
                }
                .background(AppColors.warmBackground.ignoresSafeArea())
                .navigationTitle(showNavTitle ? ranked.place.localizedName(language: lang) : "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { toggleFavorite(ranked.place) } label: {
                            Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(isFavorite ? AppColors.mint : AppColors.primaryText)
                        }
                        .accessibilityLabel(t("place.save"))
                        ShareLink(item: shareText(ranked)) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(AppColors.primaryText)
                        }
                        .accessibilityLabel(t("place.share"))
                    }
                }
            } else {
                ProgressView().task { await load() }
            }
        }
        .sheet(isPresented: $showReport) {
            if let ranked { ReportSheet(place: ranked.place) }
        }
    }

    @ViewBuilder
    private func hero(_ ranked: RankedPlace) -> some View {
        if PlaceCover.url(for: ranked.place) != nil {
            PlacePhotoView(place: ranked.place, glyph: ranked.place.category.symbolName)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.hero)
                .clipped()
        } else if let catalog = session.catalog {
            GeographicMetroMap(
                catalog: catalog,
                selectedLineId: ranked.access.station.lineIds.first,
                selectedStationId: ranked.access.station.id,
                language: lang,
                interactive: false,
                showsAllStations: false,
                places: [
                    GoogleMapPlacePin(
                        id: ranked.place.id,
                        name: ranked.place.localizedName(language: lang),
                        latitude: ranked.place.latitude,
                        longitude: ranked.place.longitude,
                        color: PlaceCategory.pinHex(ranked.place.category)
                    )
                ],
                walk: ranked.access.displayedPath,
                onSelect: { _ in },
                camera: .constant(.automatic)
            )
            .frame(height: AppSize.hero)
            .accessibilityLabel(t("place.walk.metroMap"))
        } else {
            PlacePhotoView(place: ranked.place, glyph: ranked.place.category.symbolName)
                .frame(height: AppSize.hero)
        }
    }

    private func identity(_ ranked: RankedPlace) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            HStack(spacing: AppSpacing.tight) {
                Text(DalilCopy.t(ranked.place.category.copyKey, lang))
                    .appText(.subhead)
                    .foregroundStyle(AppColors.categoryInk(ranked.place.category))
                    .padding(.horizontal, AppSpacing.item)
                    .frame(height: AppSize.chip)
                    .background(AppColors.categoryTint(ranked.place.category))
                    .clipShape(Capsule())
                ForEach(session.catalog?.lines(for: ranked.access.station) ?? []) { line in
                    LineBadge(line: line.lineColor, style: .number, language: lang)
                }
            }
            Text(ranked.place.localizedName(language: lang))
                .appText(.largeTitle)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if let copy = publicDescription(ranked.place) {
                Text(copy)
                    .appText(.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(3)
            }
        }
    }

    private func summaryStrip(_ ranked: RankedPlace) -> some View {
        HStack(spacing: 0) {
            summaryCell("tram.fill", t("place.nearestStation"), ranked.access.station.localizedName(language: lang))
            Divider().frame(height: 36)
            summaryCell("figure.walk", t("place.walk.short"), DalilCopy.shortMinutes(ranked.access.displayedMinutes, lang))
            Divider().frame(height: 36)
            summaryCell("arrow.left.and.right", t("place.distance"), DalilCopy.compactDistance(Int(ranked.access.displayedMeters.rounded()), lang))
        }
        .padding(.vertical, AppSpacing.item)
        .padding(.horizontal, AppSpacing.tight)
        .background(AppColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func summaryCell(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: AppTextStyle.caption.size, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)
            Text(label)
                .appText(.caption)
                .foregroundStyle(AppColors.secondaryText)
            Text(value)
                .appLiveNumber(.headline)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func routeTimeline(_ ranked: RankedPlace) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            Text(t("place.walk.title"))
                .appText(.title)
                .foregroundStyle(AppColors.primaryText)
            VStack(alignment: .leading, spacing: 0) {
                TimelineStep(
                    index: 1,
                    title: stepOneTitle(ranked),
                    subtitle: stepOneDetail(ranked),
                    isFirst: true,
                    isLast: false
                )
                TimelineStep(
                    index: 2,
                    title: t("walk.step2"),
                    subtitle: DalilCopy.walkAndDistance(
                        minutes: ranked.access.displayedMinutes,
                        meters: Int(ranked.access.displayedMeters.rounded()),
                        lang
                    ),
                    isFirst: false,
                    isLast: false
                )
                TimelineStep(
                    index: 3,
                    title: t("walk.arrive"),
                    subtitle: ranked.place.localizedName(language: lang),
                    isFirst: false,
                    isLast: true
                )
            }
            .padding(AppSpacing.item)
            .background(AppColors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        }
    }

    private func dock(_ ranked: RankedPlace) -> some View {
        PrimaryButton(title: t("place.plan")) {
            router.open(.tripPlan(ranked.place.id))
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.vertical, AppSpacing.item)
        .background(.ultraThinMaterial)
        .accessibilityHint(t("trip.title"))
    }

    private func stepOneTitle(_ ranked: RankedPlace) -> String {
        if let exit = ranked.access.exit {
            return DalilCopy.leaveExit(exit.exitNumber, lang)
        }
        return t("walk.step1.station")
    }

    private func stepOneDetail(_ ranked: RankedPlace) -> String {
        if let exit = ranked.access.exit { return officialExitNote(exit) }
        return ranked.access.station.localizedName(language: lang)
    }

    private func officialExitNote(_ exit: StationExit) -> String {
        let direction = lang == .arabic ? exit.directionAr : exit.directionEn
        let landmark = lang == .arabic ? exit.nearbyLandmarkAr : exit.nearbyLandmarkEn
        let lowered = direction.lowercased()
        let isDestinationNote = direction.contains("للوجهة")
            || lowered.contains("destination")
            || lowered.contains("walk to the")
        if !isDestinationNote && !direction.isEmpty { return direction }
        if !landmark.isEmpty { return landmark }
        return t("walk.step1.station")
    }

    private func publicDescription(_ place: Place) -> String? {
        let copy = place.localizedDescription(language: lang)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copy.isEmpty, !isGeneratedWalkCopy(copy) else { return nil }
        let indoor = (lang == .arabic ? place.indoorLocationNoteAr : place.indoorLocationNoteEn)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let indoor, !indoor.isEmpty, copy == indoor { return nil }
        return copy
    }

    private func isGeneratedWalkCopy(_ copy: String) -> Bool {
        copy.contains("دقائق مشي") || copy.lowercased().contains("min walk")
    }

    private func load() async {
        await session.loadCatalog()
        ranked = session.rankedPlaces.first { $0.place.id == placeId }
        if ranked == nil, let place = try? await environment.places.place(id: placeId),
           let catalog = session.catalog,
           let station = catalog.station(id: place.stationId),
           let access = try? await environment.accessAssembler.summary(
            place: place,
            station: station,
            verifiedExits: catalog.verifiedExits(for: station.id)
           ) {
            ranked = RankedPlace(place: place, access: access, score: environment.ranker.score(place: place, access: access))
        }
        if let place = ranked?.place {
            session.markVisited(place.coordinate)
            if let user = environment.auth.currentUser {
                isFavorite = (try? await environment.favorites.isFavorite(userId: user.id, targetId: place.id, kind: .place)) ?? false
            }
        }
    }

    private func toggleFavorite(_ place: Place) {
        Task {
            do {
                let user = try await environment.auth.requireSignedInUser()
                isFavorite = try await environment.favorites.toggle(userId: user.id, targetId: place.id, kind: .place)
            } catch {
                router.isShowingAuth = true
            }
        }
    }

    private func shareText(_ ranked: RankedPlace) -> String {
        "\(ranked.place.localizedName(language: lang)) — \(ranked.access.station.localizedName(language: lang))"
    }
}

private struct PlaceHeroOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TripPlanView: View {
    enum Destination {
        case place(String)
        case saved(String)
    }

    var destination: Destination
    @EnvironmentObject private var session: CatalogSession
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @State private var plan: PreparedTrip?

    private var lang: AppLanguage { settings.language }
    private func t(_ key: String) -> String { DalilCopy.t(key, lang) }

    var body: some View {
        Group {
            if let plan, let catalog = session.catalog {
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        tripBoard(plan, catalog: catalog)
                            .padding(AppSpacing.screen)
                    }
                    PrimaryButton(title: t("trip.start")) {
                        Task { await start(plan) }
                    }
                    .padding(AppSpacing.screen)
                    .background(.ultraThinMaterial)
                }
                .background(AppColors.warmBackground.ignoresSafeArea())
                .navigationTitle(plan.title)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ProgressView().task { await load() }
            }
        }
    }

    private func tripBoard(_ plan: PreparedTrip, catalog: MetroCatalog) -> some View {
        let originCoord = originCoordinate(for: plan)
        let originStation = session.nearestStation(to: originCoord) ?? plan.destStation
        let destStation = plan.destStation
        let originMeters = Int(originCoord.distanceMeters(to: originStation.coordinate).rounded())
        let originWalk = max(1, Int((Double(originMeters) / 80).rounded()))
        let rides = originStation.id == destStation.id
            ? []
            : MetroTripPlanner.rides(from: originStation, to: destStation, catalog: catalog)
        let firstLine = rides.first?.line.lineColor ?? catalog.lines(for: originStation).first?.lineColor
        let firstRail: TripRail = rides.first.map { .ride($0.line.lineColor) } ?? .none

        return VStack(spacing: 0) {
            TripNodeRow(marker: .origin, above: .none, below: .walk, title: t("trip.you"), subtitle: nil)
            TripSegmentRow(rail: .walk) {
                TripWalkLabel(minutes: originWalk, meters: originMeters, language: lang)
            }
            TripNodeRow(
                marker: .station(firstLine ?? .blue),
                above: .walk,
                below: rides.isEmpty ? .walk : firstRail,
                title: originStation.localizedName(language: lang),
                subtitle: rides.isEmpty ? nil : t("trip.ride")
            )
            ForEach(Array(rides.enumerated()), id: \.offset) { index, ride in
                let isLast = index == rides.count - 1
                let next: TripRail = isLast ? .walk : .ride(rides[index + 1].line.lineColor)
                TripSegmentRow(rail: .ride(ride.line.lineColor)) {
                    TripRideLabel(ride: ride, catalog: catalog, language: lang)
                }
                TripNodeRow(
                    marker: isLast ? .station(ride.line.lineColor) : .transfer,
                    above: .ride(ride.line.lineColor),
                    below: next,
                    title: ride.to.localizedName(language: lang),
                    subtitle: t(isLast ? "trip.alight" : "trip.transfer")
                )
            }
            TripSegmentRow(rail: .walk) {
                TripWalkLabel(minutes: plan.walkMinutes, meters: plan.walkMeters, language: lang)
            }
            TripNodeRow(marker: .destination, above: .walk, below: .none, title: plan.title, subtitle: nil)
        }
        .padding(AppSpacing.screen)
        .background(AppColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func originCoordinate(for plan: PreparedTrip) -> GeoCoordinate {
        switch plan.kind {
        case .place:
            return session.anchor
        case .saved:
            return session.tripOriginCoordinate
        }
    }

    private func load() async {
        await session.loadCatalog()
        guard let catalog = session.catalog else { return }
        switch destination {
        case .place(let id):
            if let ranked = await loadPlace(id, catalog: catalog) {
                plan = PreparedTrip(
                    kind: .place,
                    title: ranked.place.localizedName(language: lang),
                    destStation: ranked.access.station,
                    destCoordinate: ranked.place.coordinate,
                    walkMinutes: ranked.access.displayedMinutes,
                    walkMeters: Int(ranked.access.displayedMeters.rounded()),
                    exit: ranked.access.exit
                )
            }
        case .saved(let id):
            guard let location = settings.savedLocations.first(where: { $0.id == id }),
                  let destStation = session.nearestStation(to: location.coordinate) else { return }
            let meters = Int(location.coordinate.distanceMeters(to: destStation.coordinate).rounded())
            plan = PreparedTrip(
                kind: .saved,
                title: location.title(lang),
                destStation: destStation,
                destCoordinate: location.coordinate,
                walkMinutes: max(1, Int((Double(meters) / 80).rounded())),
                walkMeters: meters,
                exit: nil
            )
        }
    }

    private func loadPlace(_ id: String, catalog: MetroCatalog) async -> RankedPlace? {
        if let ranked = session.rankedPlaces.first(where: { $0.place.id == id }) { return ranked }
        guard let place = try? await environment.places.place(id: id),
              let station = catalog.station(id: place.stationId),
              let access = try? await environment.accessAssembler.summary(
                place: place,
                station: station,
                verifiedExits: catalog.verifiedExits(for: station.id)
              ) else { return nil }
        return RankedPlace(place: place, access: access, score: environment.ranker.score(place: place, access: access))
    }

    private func start(_ plan: PreparedTrip) async {
        guard let catalog = session.catalog else { return }
        let originCoord = originCoordinate(for: plan)
        guard let originStation = session.nearestStation(to: originCoord) else { return }
        let trip = TripGuidanceBuilder.build(
            title: plan.title,
            originStation: originStation,
            destStation: plan.destStation,
            dest: plan.destCoordinate,
            destName: plan.title,
            catalog: catalog,
            language: lang
        )
        await session.beginGuidance(trip)
        router.openGuidanceMap()
    }
}

private struct PreparedTrip {
    enum Kind {
        case place
        case saved
    }

    var kind: Kind
    var title: String
    var destStation: MetroStation
    var destCoordinate: GeoCoordinate
    var walkMinutes: Int
    var walkMeters: Int
    var exit: StationExit?
}

private enum TripRail {
    case none
    case walk
    case ride(LineColor)
}

private enum TripMarker {
    case origin
    case station(LineColor)
    case transfer
    case destination
}

private enum TripRailMetrics {
    static let rideWidth: CGFloat = AppSpacing.tight
    static let walkWidth: CGFloat = 3
    static let walkDash: [CGFloat] = [1, 7]
    static let markerStroke: CGFloat = 2
    static let stationSize: CGFloat = AppSpacing.screen
    static let transferSize: CGFloat = AppSpacing.screen + AppSpacing.tight
}

private struct TripRailSegment: View {
    var rail: TripRail

    var body: some View {
        switch rail {
        case .none:
            Color.clear.frame(width: TripRailMetrics.rideWidth)
        case .walk:
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                }
                .stroke(
                    AppColors.controlBorder,
                    style: StrokeStyle(lineWidth: TripRailMetrics.walkWidth, lineCap: .round, dash: TripRailMetrics.walkDash)
                )
            }
            .frame(width: TripRailMetrics.rideWidth)
        case .ride(let line):
            ZStack {
                if Color.relativeLuminance(line.hex) > 0.55 {
                    Rectangle()
                        .fill(AppColors.primaryText.opacity(0.28))
                        .frame(width: TripRailMetrics.rideWidth + 2)
                }
                Rectangle()
                    .fill(line.color)
                    .frame(width: TripRailMetrics.rideWidth)
            }
        }
    }
}

private struct TripMarkerView: View {
    var marker: TripMarker

    var body: some View {
        switch marker {
        case .origin:
            Circle()
                .fill(AppColors.primaryText)
                .overlay(Circle().stroke(AppColors.cardSurface, lineWidth: TripRailMetrics.markerStroke))
                .frame(width: AppSpacing.item + AppSpacing.xxs, height: AppSpacing.item + AppSpacing.xxs)
        case .station(let line):
            Circle()
                .fill(line.color)
                .overlay(Circle().stroke(AppColors.primaryText, lineWidth: TripRailMetrics.markerStroke))
                .frame(width: TripRailMetrics.stationSize, height: TripRailMetrics.stationSize)
        case .transfer:
            Circle()
                .fill(AppColors.cardSurface)
                .overlay(Circle().strokeBorder(AppColors.primaryText, lineWidth: TripRailMetrics.markerStroke + 1))
                .frame(width: TripRailMetrics.transferSize, height: TripRailMetrics.transferSize)
        case .destination:
            Image(systemName: "mappin")
                .font(.system(size: AppTextStyle.caption.size, weight: .bold))
                .foregroundStyle(AppColors.cardSurface)
                .frame(width: TripRailMetrics.transferSize, height: TripRailMetrics.transferSize)
                .background(AppColors.primaryText)
                .clipShape(Circle())
        }
    }
}

private struct TripNodeRow: View {
    var marker: TripMarker
    var above: TripRail
    var below: TripRail
    var title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.item) {
            ZStack {
                VStack(spacing: 0) {
                    TripRailSegment(rail: above)
                    TripRailSegment(rail: below)
                }
                TripMarkerView(marker: marker)
            }
            .frame(width: AppSpacing.xl)
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .appText(.title)
                    .foregroundStyle(AppColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .appText(.body)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .padding(.vertical, AppSpacing.xxs)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

private struct TripSegmentRow<Content: View>: View {
    var rail: TripRail
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: AppSpacing.item) {
            TripRailSegment(rail: rail)
                .frame(width: AppSpacing.xl)
                .frame(maxHeight: .infinity)
            content
                .padding(.vertical, AppSpacing.xxs)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

private struct TripWalkLabel: View {
    var minutes: Int
    var meters: Int
    var language: AppLanguage

    var body: some View {
        HStack(spacing: AppSpacing.tight) {
            Image(systemName: "figure.walk")
                .font(.system(size: AppTextStyle.body.size, weight: .semibold))
            Text(DalilCopy.walkAndDistance(minutes: minutes, meters: meters, language))
                .appText(.body)
        }
        .foregroundStyle(AppColors.secondaryText)
    }
}

private struct TripRideLabel: View {
    var ride: MetroRide
    var catalog: MetroCatalog
    var language: AppLanguage

    var body: some View {
        let line = ride.line.lineColor
        let toward = MetroTripPlanner.towardName(from: ride.from, to: ride.to, catalog: catalog, language: language)
        let stops = MetroTripPlanner.stopCount(from: ride.from, to: ride.to, catalog: catalog)
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(spacing: AppSpacing.tight) {
                LineBadge(line: line, style: .number, language: language)
                Text(line.localizedName(language: language))
                    .appText(.headline)
                    .foregroundStyle(AppColors.primaryText)
            }
            Text(towardLine(toward: toward, stops: stops))
                .appText(.body)
                .foregroundStyle(AppColors.secondaryText)
        }
    }

    private func towardLine(toward: String, stops: Int) -> String {
        let count = DalilCopy.stops(stops, language)
        return language == .arabic ? "باتجاه \(toward) · \(count)" : "Toward \(toward) · \(count)"
    }
}
