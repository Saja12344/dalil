import Foundation

/// Real Google Routes calls must go through a backend proxy so the secret key never ships in the app.
struct GoogleRoutesClient: WalkingRouting {
    var proxyURL: URL?
    var fallback: WalkingRouting

    func walkingRoute(from: GeoCoordinate, to: GeoCoordinate) async throws -> WalkingRoute {
        guard let proxyURL else {
            return try await fallback.walkingRoute(from: from, to: to)
        }
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = [
            "origin": ["lat": from.latitude, "lng": from.longitude],
            "destination": ["lat": to.latitude, "lng": to.longitude],
            "travelMode": "WALK"
        ] as [String: Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return try await fallback.walkingRoute(from: from, to: to)
        }
        let decoded = try JSONDecoder().decode(ProxyRoute.self, from: data)
        return WalkingRoute(
            from: from,
            to: to,
            distanceMeters: decoded.distanceMeters,
            durationSeconds: decoded.durationSeconds,
            isEstimated: false,
            source: .googleRoutes,
            calculatedAt: .now
        )
    }

    private struct ProxyRoute: Decodable {
        var distanceMeters: Double
        var durationSeconds: Double
    }
}

/// Foot geometry from OpenStreetMap via OSRM so the walk follows streets.
struct StreetWalkingRouter: WalkingRouting {
    var fallback: WalkingRouting

    func walkingRoute(from: GeoCoordinate, to: GeoCoordinate) async throws -> WalkingRoute {
        let urlString = "https://router.project-osrm.org/route/v1/foot/\(from.longitude),\(from.latitude);\(to.longitude),\(to.latitude)?overview=full&geometries=geojson"
        guard let url = URL(string: urlString) else {
            return try await fallback.walkingRoute(from: from, to: to)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 7
        request.setValue("Dalil/1.0 (riyadh metro walking)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return try await fallback.walkingRoute(from: from, to: to)
            }
            let decoded = try JSONDecoder().decode(OSRMResponse.self, from: data)
            guard let route = decoded.routes.first,
                  let coords = route.geometry?.coordinates,
                  coords.count >= 2 else {
                return try await fallback.walkingRoute(from: from, to: to)
            }
            let path = coords.compactMap { pair -> GeoCoordinate? in
                guard pair.count >= 2 else { return nil }
                return GeoCoordinate(latitude: pair[1], longitude: pair[0])
            }
            guard path.count >= 2, route.distance <= 3_800 else {
                return try await fallback.walkingRoute(from: from, to: to)
            }
            return WalkingRoute(
                from: from,
                to: to,
                distanceMeters: route.distance,
                durationSeconds: route.duration,
                isEstimated: false,
                source: .osrm,
                calculatedAt: .now,
                path: path
            )
        } catch {
            return try await fallback.walkingRoute(from: from, to: to)
        }
    }

    private struct OSRMResponse: Decodable {
        var routes: [OSRMRoute]
    }

    private struct OSRMRoute: Decodable {
        var distance: Double
        var duration: Double
        var geometry: OSRMGeometry?
    }

    private struct OSRMGeometry: Decodable {
        var coordinates: [[Double]]
    }
}

enum APIKeyStore {
    static var googleMapsKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String ?? ""
    }

    static var routesProxy: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_ROUTES_PROXY_URL") as? String,
              let url = URL(string: raw), !raw.isEmpty else { return nil }
        return url
    }
}
