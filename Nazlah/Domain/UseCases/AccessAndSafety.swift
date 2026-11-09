import CoreGraphics
import Foundation
import ImageIO

actor WalkingRouteCache {
    private var storage: [String: WalkingRoute] = [:]

    func route(for key: String) -> WalkingRoute? {
        storage[key]
    }

    func store(_ route: WalkingRoute, key: String) {
        storage[key] = route
    }

    func invalidate() {
        storage.removeAll()
    }

    static func key(from: GeoCoordinate, to: GeoCoordinate) -> String {
        "\(from.cacheKey)->\(to.cacheKey)"
    }
}

struct AccessAssembler: Sendable {
    var routing: WalkingRouting
    var exitSelector: VerifiedExitSelector
    var cache: WalkingRouteCache

    func summary(
        place: Place,
        station: MetroStation,
        verifiedExits: [StationExit]
    ) async throws -> AccessSummary {
        let stationRoute = try await cachedRoute(from: station.coordinate, to: place.coordinate)
        var exit: StationExit?
        var exitRoute: WalkingRoute?

        if let preferred = verifiedExits.first(where: { $0.id == place.nearestExitId }) {
            let route = try await cachedRoute(from: preferred.coordinate, to: place.coordinate)
            if route.distanceMeters < 3_500 {
                exit = preferred
                exitRoute = route
            }
        } else if station.hasVerifiedExits, !verifiedExits.isEmpty {
            if let picked = try await exitSelector.bestExit(
                station: station,
                exits: verifiedExits,
                destination: place.coordinate
            ) {
                exit = picked.exit
                exitRoute = picked.route
            }
        }

        return AccessSummary(
            station: station,
            routeFromStation: stationRoute,
            exit: exit,
            routeFromExit: exitRoute,
            stationHasVerifiedExits: station.hasVerifiedExits && !verifiedExits.isEmpty
        )
    }

    private func cachedRoute(from: GeoCoordinate, to: GeoCoordinate) async throws -> WalkingRoute {
        let key = WalkingRouteCache.key(from: from, to: to)
        if let existing = await cache.route(for: key) {
            return existing
        }
        let route = try await routing.walkingRoute(from: from, to: to)
        await cache.store(route, key: key)
        return route
    }
}

actor RateLimiter {
    private struct Stamp {
        var times: [Date]
    }

    private var stamps: [String: Stamp] = [:]

    func allow(key: String, limit: Int, window: TimeInterval, now: Date = .now) -> Bool {
        var stamp = stamps[key] ?? Stamp(times: [])
        stamp.times = stamp.times.filter { now.timeIntervalSince($0) < window }
        guard stamp.times.count < limit else {
            stamps[key] = stamp
            return false
        }
        stamp.times.append(now)
        stamps[key] = stamp
        return true
    }
}

enum ImagePrep {
    static let maxBytes = 1_200_000
    static let allowedTypes: Set<String> = ["public.jpeg", "public.png", "public.heic"]

    static func stripGPSMetadata(from data: Data) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return data
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil) else {
            return data
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        CGImageDestinationFinalize(destination)
        return output as Data
    }
}
