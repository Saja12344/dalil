import Foundation
import CoreLocation

struct GeoCoordinate: Hashable, Codable, Sendable {
    var latitude: Double
    var longitude: Double

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distanceMeters(to other: GeoCoordinate) -> Double {
        clLocation.distance(from: other.clLocation)
    }

    /// Rounded cache key. Not used to choose exits.
    var cacheKey: String {
        String(format: "%.5f,%.5f", latitude, longitude)
    }
}

struct MetroLine: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var nameAr: String
    var nameEn: String
    var colorHex: String
    var stationIds: [String]
    var displayOrder: Int
    var shortCode: String
    var path: [GeoCoordinate] = []

    func localizedName(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
    }

    var lineColor: LineColor {
        LineColor.resolving(id: id, hex: colorHex)
    }

    func mapCoordinates(in catalog: MetroCatalog) -> [CLLocationCoordinate2D] {
        if path.count >= 2 {
            return path.map(\.clCoordinate)
        }
        return stationIds.compactMap { catalog.station(id: $0)?.coordinate.clCoordinate }
    }
}

struct MetroStation: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var nameAr: String
    var nameEn: String
    var lineIds: [String]
    var latitude: Double
    var longitude: Double
    var stationType: StationType
    var facilities: [StationFacility]
    var hasVerifiedExits: Bool
    var hasVerifiedIndoorPlaces: Bool
    var heroImageURL: String?
    var coordinateSource: CoordinateSource
    var updatedAt: Date

    var coordinate: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    var isInterchange: Bool { lineIds.count > 1 }

    func localizedName(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
    }
}

struct StationExit: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var stationId: String
    var exitNumber: String
    var nameAr: String
    var nameEn: String
    var latitude: Double
    var longitude: Double
    var directionAr: String
    var directionEn: String
    var nearbyLandmarkAr: String
    var nearbyLandmarkEn: String
    var accessibilityType: AccessibilityKind
    var verificationStatus: ExitVerificationStatus
    var verifiedAt: Date?
    var verifiedBy: String?

    var coordinate: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    var isVerified: Bool { verificationStatus == .verified }

    func localizedName(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
    }
}

struct MetroCatalog: Sendable {
    var lines: [MetroLine]
    var stations: [MetroStation]
    var exits: [StationExit]
    var attribution: DataAttribution

    func station(id: String) -> MetroStation? {
        stations.first { $0.id == id }
    }

    func line(id: String) -> MetroLine? {
        lines.first { $0.id == id }
    }

    func lines(for station: MetroStation) -> [MetroLine] {
        station.lineIds.compactMap(line(id:))
    }

    func verifiedExits(for stationId: String) -> [StationExit] {
        exits.filter { $0.stationId == stationId && $0.isVerified }
    }

    func exits(for stationId: String) -> [StationExit] {
        exits
            .filter { $0.stationId == stationId }
            .sorted { $0.exitNumber.localizedStandardCompare($1.exitNumber) == .orderedAscending }
    }

    func stations(on lineId: String) -> [MetroStation] {
        guard let line = line(id: lineId) else { return [] }
        return line.stationIds.compactMap(station(id:))
    }
}

struct DataAttribution: Codable, Sendable {
    var stationNames: String
    var coordinates: String
    var schematic: String
    var exits: String
}
