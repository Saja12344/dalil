import Foundation

struct NearestStationFinder: Sendable {
    func nearest(to coordinate: GeoCoordinate, in catalog: MetroCatalog) -> MetroStation? {
        catalog.stations.min { lhs, rhs in
            lhs.coordinate.distanceMeters(to: coordinate) < rhs.coordinate.distanceMeters(to: coordinate)
        }
    }

    func ranked(to coordinate: GeoCoordinate, in catalog: MetroCatalog, limit: Int = 6) -> [MetroStation] {
        Array(
            catalog.stations
                .sorted { $0.coordinate.distanceMeters(to: coordinate) < $1.coordinate.distanceMeters(to: coordinate) }
                .prefix(limit)
        )
    }
}

/// Chooses a verified exit using walking routes only. Never uses straight-line distance.
struct VerifiedExitSelector: Sendable {
    var routing: WalkingRouting

    func bestExit(
        station: MetroStation,
        exits: [StationExit],
        destination: GeoCoordinate
    ) async throws -> (exit: StationExit, route: WalkingRoute)? {
        let verified = exits.filter { $0.stationId == station.id && $0.isVerified }
        guard station.hasVerifiedExits, !verified.isEmpty else { return nil }

        var best: (StationExit, WalkingRoute)?
        for exit in verified {
            let route = try await routing.walkingRoute(from: exit.coordinate, to: destination)
            guard route.isReasonableWalk else { continue }
            if let current = best {
                if route.durationSeconds < current.1.durationSeconds {
                    best = (exit, route)
                }
            } else {
                best = (exit, route)
            }
        }
        return best
    }
}

struct PlaceRanker: Sendable {
    func score(place: Place, access: AccessSummary) -> Double {
        let minutes = Double(access.displayedMinutes)
        let walking = max(0, 1 - (minutes / 18.0)) * 0.38
        let rating = ((place.rating ?? 0) / 5.0) * 0.16
        let reviews = min(log(Double((place.reviewCount ?? 0) + 1)) / log(2000), 1) * 0.10
        let open = (place.isOpenNow == true ? 0.12 : 0)
        let completeness = place.completenessScore * 0.08
        let editorial = editorialBoost(place)
        let relation = relationBoost(place.stationRelation)
        return walking + rating + reviews + open + completeness + editorial + relation
    }

    func rank(_ items: [RankedPlace]) -> [RankedPlace] {
        items
            .filter { $0.access.routeFromStation.isReasonableWalk || $0.place.stationRelation == .insideStation }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.access.displayedMinutes < rhs.access.displayedMinutes
                }
                return lhs.score > rhs.score
            }
    }

    private func editorialBoost(_ place: Place) -> Double {
        var value = 0.0
        if place.editorialTags.contains(.worthTheStop) { value += 0.12 }
        if place.source == .editorial { value += 0.04 }
        return value
    }

    private func relationBoost(_ relation: StationRelation) -> Double {
        switch relation {
        case .insideStation: return 0.10
        case .directlyConnected: return 0.06
        case .nearby: return 0.02
        case .unverified: return -0.20
        }
    }
}

struct PlaceSearchIndex: Sendable {
    func matches(_ place: Place, station: MetroStation?, query: String, language: AppLanguage) -> Bool {
        let needle = normalized(query)
        guard !needle.isEmpty else { return true }
        if needle.contains("نادي") || needle == "gym" || needle.contains("fitness") {
            if place.category == .gym { return true }
        }
        if needle.contains("صيدل") || needle == "pharmacy" {
            if place.category == .pharmacy { return true }
        }
        let fields = [
            place.nameAr, place.nameEn,
            place.shortDescriptionAr, place.shortDescriptionEn,
            place.neighborhoodAr, place.neighborhoodEn,
            place.category.rawValue,
            station?.nameAr, station?.nameEn
        ]
        .compactMap { $0 }
        .map(normalized)

        let hay = fields.joined(separator: " ")
        if hay.contains(needle) { return true }

        let synonyms: [String: [String]] = [
            "قهوة": ["cafe", "coffee", "قهوه"],
            "فطور": ["breakfast", "فطور"],
            "جلسات": ["sitting", "park", "viewpoint", "جلسة"],
            "هادئ": ["quiet", "هادئ"],
            "للعمل": ["work", "cowork", "عمل"],
            "عائلات": ["family", "عائل"],
            "حلا": ["dessert", "حلو", "حلى"],
            "مفتوح": ["open"],
            "نادي": ["gym", "fitness", "club", "نادي"],
            "صيدليه": ["pharmacy", "صيدليه", "صيدلية"]
        ]

        for token in needle.split(separator: " ").map(String.init) {
            if hay.contains(token) { return true }
            for (key, values) in synonyms {
                let hit = normalized(key).contains(token) || values.contains(where: { normalized($0).contains(token) })
                if hit && (place.editorialTags.contains(where: { tagMatches($0, token: token) }) || hay.contains(token) || fields.contains(where: { $0.contains(token) })) {
                    return true
                }
            }
        }
        return false
    }

    func applies(_ filter: PlaceFilter, to ranked: RankedPlace) -> Bool {
        let place = ranked.place
        switch filter {
        case .insideStation: return place.stationRelation == .insideStation
        case .underFiveMinutes: return ranked.access.displayedMinutes <= 5
        case .underTenMinutes: return ranked.access.displayedMinutes <= 10
        case .openNow: return place.isOpenNow == true
        case .topRated: return (place.rating ?? 0) >= 4.5
        case .cheapest: return (place.priceLevel ?? 3) <= 1
        case .workFriendly: return place.editorialTags.contains(.workFriendly) || place.category == .cowork
        case .familyFriendly: return place.editorialTags.contains(.familyFriendly)
        case .wheelchairAccessible: return place.editorialTags.contains(.wheelchairAccessible)
        case .cafe: return place.category == .cafe
        case .restaurant: return place.category == .restaurant
        case .sitting: return place.category == .park || place.category == .viewpoint || place.editorialTags.contains(.outdoorSeating)
        case .worthTheStop: return place.editorialTags.contains(.worthTheStop)
        }
    }

    private func tagMatches(_ tag: EditorialTag, token: String) -> Bool {
        normalized(tag.rawValue).contains(token)
            || (token.contains("عمل") && tag == .workFriendly)
            || (token.contains("عائل") && tag == .familyFriendly)
            || (token.contains("هادئ") && tag == .quiet)
            || (token.contains("حلا") && tag == .dessert)
            || (token.contains("فطور") && tag == .breakfast)
    }

    private func normalized(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ة", with: "ه")
            .replacingOccurrences(of: "ى", with: "ي")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MetroServiceClock {
    static func isRunning(at date: Date = .now) -> Bool {
        (6..<24).contains(Calendar.current.component(.hour, from: date))
    }

    static func untilLabel(language: AppLanguage, at date: Date = .now) -> String {
        isRunning(at: date)
            ? DalilCopy.t("status.untilMidnight", language)
            : DalilCopy.t("status.opensMorning", language)
    }
}

struct MetroDepartureClock {
    static func rows(
        station: MetroStation,
        catalog: MetroCatalog,
        language: AppLanguage,
        now: Date = .now
    ) -> [(direction: String, minutes: [Int])] {
        guard let line = catalog.lines(for: station).first else { return [] }
        let stops = catalog.stations(on: line.id)
        guard let first = stops.first, let last = stops.last else { return [] }
        let seed = abs(station.id.hashValue) &+ Int(now.timeIntervalSince1970 / 60)
        func pair(_ offset: Int) -> [Int] {
            let firstWait = 2 + ((seed &+ offset) % 6)
            return [firstWait, firstWait + 7, firstWait + 14]
        }
        var rows: [(String, [Int])] = []
        if station.id != last.id {
            rows.append((last.localizedName(language: language), pair(0)))
        }
        if station.id != first.id {
            rows.append((first.localizedName(language: language), pair(3)))
        }
        if rows.isEmpty {
            rows.append((last.localizedName(language: language), pair(0)))
        }
        return Array(rows.prefix(2))
    }
}

struct MetroRide: Equatable {
    var line: MetroLine
    var from: MetroStation
    var to: MetroStation
}

struct MetroTripPlanner {
    static func sharedLine(from origin: MetroStation, to dest: MetroStation, catalog: MetroCatalog) -> MetroLine? {
        for lineId in origin.lineIds where dest.lineIds.contains(lineId) {
            if let line = catalog.line(id: lineId) { return line }
        }
        return nil
    }

    static func rides(from origin: MetroStation, to dest: MetroStation, catalog: MetroCatalog) -> [MetroRide] {
        if origin.id == dest.id { return [] }
        if let line = sharedLine(from: origin, to: dest, catalog: catalog) {
            return [MetroRide(line: line, from: origin, to: dest)]
        }
        var best: [MetroRide] = []
        var bestStops = Int.max
        for hub in catalog.stations where hub.isInterchange && hub.id != origin.id && hub.id != dest.id {
            guard let first = sharedLine(from: origin, to: hub, catalog: catalog),
                  let second = sharedLine(from: hub, to: dest, catalog: catalog) else { continue }
            let stops = stopCount(from: origin, to: hub, catalog: catalog) + stopCount(from: hub, to: dest, catalog: catalog)
            if stops < bestStops {
                bestStops = stops
                best = [
                    MetroRide(line: first, from: origin, to: hub),
                    MetroRide(line: second, from: hub, to: dest)
                ]
            }
        }
        return best
    }

    static func stopCount(from origin: MetroStation, to dest: MetroStation, catalog: MetroCatalog) -> Int {
        guard let line = sharedLine(from: origin, to: dest, catalog: catalog),
              let i = line.stationIds.firstIndex(of: origin.id),
              let j = line.stationIds.firstIndex(of: dest.id) else { return 1 }
        return max(1, abs(j - i))
    }

    static func towardName(from origin: MetroStation, to dest: MetroStation, catalog: MetroCatalog, language: AppLanguage) -> String {
        guard let line = sharedLine(from: origin, to: dest, catalog: catalog),
              let i = line.stationIds.firstIndex(of: origin.id),
              let j = line.stationIds.firstIndex(of: dest.id) else {
            return dest.localizedName(language: language)
        }
        let endId = j >= i ? line.stationIds.last : line.stationIds.first
        return endId.flatMap(catalog.station)?.localizedName(language: language) ?? dest.localizedName(language: language)
    }
}

struct TripWaypoint: Identifiable, Equatable {
    var id: String
    var label: String
    var action: String
    var arrivalPrompt: String
    var coordinate: GeoCoordinate
    var radius: Double
}

struct ActiveTrip: Equatable {
    var title: String
    var destCoordinate: GeoCoordinate
    var waypoints: [TripWaypoint]
    var currentIndex: Int

    var isComplete: Bool { currentIndex >= waypoints.count }

    var currentWaypoint: TripWaypoint? {
        guard currentIndex < waypoints.count else { return nil }
        return waypoints[currentIndex]
    }
}

enum TripGuidanceBuilder {
    static func build(
        title: String,
        originStation: MetroStation,
        destStation: MetroStation,
        dest: GeoCoordinate,
        destName: String,
        catalog: MetroCatalog,
        language: AppLanguage
    ) -> ActiveTrip {
        func t(_ key: String) -> String { DalilCopy.t(key, language) }
        var waypoints: [TripWaypoint] = []
        let rides = MetroTripPlanner.rides(from: originStation, to: destStation, catalog: catalog)

        let boardPrompt: String
        if let first = rides.first {
            boardPrompt = DalilCopy.tripNowRide(
                line: first.line.localizedName(language: language),
                toward: MetroTripPlanner.towardName(from: first.from, to: first.to, catalog: catalog, language: language),
                language
            )
        } else if originStation.id == destStation.id {
            boardPrompt = DalilCopy.tripNowWalk(destName, language)
        } else {
            boardPrompt = t("trip.nowAlight")
        }

        waypoints.append(
            TripWaypoint(
                id: "board-\(originStation.id)",
                label: originStation.localizedName(language: language),
                action: t("trip.walkStation"),
                arrivalPrompt: boardPrompt,
                coordinate: originStation.coordinate,
                radius: 120
            )
        )

        if originStation.id != destStation.id {
            if rides.isEmpty {
                waypoints.append(
                    TripWaypoint(
                        id: "head-\(destStation.id)",
                        label: destStation.localizedName(language: language),
                        action: t("trip.headTo"),
                        arrivalPrompt: DalilCopy.tripNowAlightWalk(destName, language),
                        coordinate: destStation.coordinate,
                        radius: 120
                    )
                )
            } else {
                for (index, ride) in rides.enumerated() {
                    let toward = MetroTripPlanner.towardName(from: ride.from, to: ride.to, catalog: catalog, language: language)
                    let compact = DalilCopy.tripRideCompact(
                        line: ride.line.localizedName(language: language),
                        toward: toward,
                        stops: MetroTripPlanner.stopCount(from: ride.from, to: ride.to, catalog: catalog),
                        language
                    )
                    let isLast = index == rides.count - 1
                    let arrival: String
                    if isLast {
                        arrival = DalilCopy.tripNowAlightWalk(destName, language)
                    } else {
                        let next = rides[index + 1]
                        arrival = DalilCopy.tripNowTransfer(
                            line: next.line.localizedName(language: language),
                            toward: MetroTripPlanner.towardName(from: next.from, to: next.to, catalog: catalog, language: language),
                            language
                        )
                    }
                    waypoints.append(
                        TripWaypoint(
                            id: "stop-\(ride.to.id)-\(index)",
                            label: ride.to.localizedName(language: language),
                            action: compact,
                            arrivalPrompt: arrival,
                            coordinate: ride.to.coordinate,
                            radius: 120
                        )
                    )
                }
            }
        }

        waypoints.append(
            TripWaypoint(
                id: "arrive",
                label: destName,
                action: DalilCopy.tripNowWalk(destName, language),
                arrivalPrompt: DalilCopy.t("trip.arrived", language),
                coordinate: dest,
                radius: 55
            )
        )

        return ActiveTrip(title: title, destCoordinate: dest, waypoints: waypoints, currentIndex: 0)
    }
}
