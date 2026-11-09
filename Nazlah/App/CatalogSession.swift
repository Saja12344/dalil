import Foundation
import SwiftUI

@MainActor
final class CatalogSession: ObservableObject {
    @Published var catalog: MetroCatalog?
    @Published var rankedPlaces: [RankedPlace] = []
    @Published var placesByStation: [String: [RankedPlace]] = [:]
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var anchor = GeoCoordinate(latitude: 24.6965, longitude: 46.6837)
    @Published var usedUserLocation = false
    @Published var visitCoordinate: GeoCoordinate?
    @Published var activeTrip: ActiveTrip?

    private var guidanceTask: Task<Void, Never>?
    private var lastPublishedLocation: GeoCoordinate?

    var tripOriginCoordinate: GeoCoordinate {
        visitCoordinate ?? anchor
    }

    var nearestStation: MetroStation? {
        nearestStation(to: anchor)
    }

    func nearestStation(to coordinate: GeoCoordinate) -> MetroStation? {
        guard let catalog else { return nil }
        return environment.nearestFinder.nearest(to: coordinate, in: catalog)
    }

    func markVisited(_ coordinate: GeoCoordinate) {
        visitCoordinate = coordinate
    }

    func nearestWalkLabel(_ language: AppLanguage) -> String? {
        guard let station = nearestStation else { return nil }
        let meters = Int(anchor.distanceMeters(to: station.coordinate).rounded())
        let walk = max(1, Int((Double(meters) / 80).rounded()))
        return "\(station.localizedName(language: language)) · \(DalilCopy.walkAndDistance(minutes: walk, meters: meters, language))"
    }

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func loadCatalog() async {
        if catalog != nil { return }
        isLoading = true
        errorMessage = nil
        do {
            catalog = try await environment.metro.catalog()
        } catch {
            errorMessage = String(localized: "state.error.message")
        }
    }

    func load() async {
        await loadCatalog()
        do {
            try await refreshPlaces()
        } catch {
            if errorMessage == nil {
                errorMessage = String(localized: "state.error.message")
            }
        }
        isLoading = false
    }

    func useNearMe() async {
        let status = await environment.location.requestWhenInUse()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            errorMessage = String(localized: "location.denied")
            return
        }
        do {
            let coordinate = try await environment.location.currentCoordinate()
            guard Self.isInRiyadh(coordinate) else { return }
            setAnchor(coordinate)
            markVisited(coordinate)
            try await refreshPlaces()
        } catch {
            errorMessage = String(localized: "location.unavailable")
        }
    }

    func setAnchor(_ coordinate: GeoCoordinate) {
        anchor = coordinate
        usedUserLocation = true
        Task { try? await refreshPlaces() }
    }

    func beginGuidance(_ trip: ActiveTrip) async {
        endGuidance()
        activeTrip = trip
        lastPublishedLocation = nil
        let lang = environment.settings.language
        if environment.settings.notificationsEnabled {
            await TripNotifier.requestPermission()
            if let first = trip.waypoints.first {
                TripNotifier.send(title: DalilCopy.t("brand", lang), body: "\(first.action) · \(first.label)")
            }
        }
        _ = await environment.location.requestWhenInUse()
        _ = await environment.location.requestAlways()
        guidanceTask = Task { await trackGuidance() }
    }

    func endGuidance() {
        guidanceTask?.cancel()
        guidanceTask = nil
        environment.location.stopTripUpdates()
        activeTrip = nil
        lastPublishedLocation = nil
    }

    private func trackGuidance() async {
        for await coordinate in environment.location.locationStream() {
            if Task.isCancelled { break }
            updateLiveLocation(coordinate)
            advanceGuidance(at: coordinate)
        }
    }

    private func updateLiveLocation(_ coordinate: GeoCoordinate) {
        let movedFar = lastPublishedLocation.map { coordinate.distanceMeters(to: $0) > 40 } ?? true
        if movedFar {
            lastPublishedLocation = coordinate
            anchor = coordinate
            usedUserLocation = true
        }
    }

    private func advanceGuidance(at coordinate: GeoCoordinate) {
        guard var trip = activeTrip, !trip.isComplete else { return }
        let lang = environment.settings.language
        var changed = false
        while let waypoint = trip.currentWaypoint,
              coordinate.distanceMeters(to: waypoint.coordinate) <= waypoint.radius {
            if environment.settings.notificationsEnabled {
                TripNotifier.send(title: DalilCopy.t("brand", lang), body: waypoint.arrivalPrompt)
            }
            trip.currentIndex += 1
            changed = true
        }
        guard changed else { return }
        activeTrip = trip
        if trip.isComplete {
            environment.location.stopTripUpdates()
        }
    }

    static func isInRiyadh(_ coordinate: GeoCoordinate) -> Bool {
        (24.3...25.15).contains(coordinate.latitude) && (46.3...47.25).contains(coordinate.longitude)
    }

    func refreshPlaces() async throws {
        guard let catalog else { return }
        let collected = try await environment.places.publishedPlaces()
        var ranked: [RankedPlace] = []
        for place in collected {
            guard let host = catalog.station(id: place.stationId) else { continue }
            do {
                let access = try await environment.accessAssembler.summary(
                    place: place,
                    station: host,
                    verifiedExits: catalog.verifiedExits(for: host.id)
                )
                ranked.append(
                    RankedPlace(
                        place: place,
                        access: access,
                        score: environment.ranker.score(place: place, access: access)
                    )
                )
            } catch {
                continue
            }
        }
        let ordered = environment.ranker.rank(ranked)
        var grouped: [String: [RankedPlace]] = [:]
        for item in ordered {
            grouped[item.place.stationId, default: []].append(item)
        }
        placesByStation = grouped
        let nearest = environment.nearestFinder.nearest(to: anchor, in: catalog)
        rankedPlaces = ordered.filter { item in
            if item.place.editorialTags.contains(.worthTheStop) { return true }
            guard let nearest else { return true }
            return item.place.coordinate.distanceMeters(to: nearest.coordinate) <= 1_200
                || item.place.stationId == nearest.id
        }
    }

    func rankedPlaces(for stationId: String) -> [RankedPlace] {
        placesByStation[stationId] ?? []
    }

    func ranked(matching filters: [PlaceFilter]) -> [RankedPlace] {
        rankedPlaces.filter { item in
            filters.allSatisfy { environment.searchIndex.applies($0, to: item) }
        }
    }
}
