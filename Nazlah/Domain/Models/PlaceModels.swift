import Foundation

struct Place: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var googlePlaceId: String?
    var nameAr: String
    var nameEn: String
    var latitude: Double
    var longitude: Double
    var category: PlaceCategory
    var stationId: String
    var stationRelation: StationRelation
    var floor: String?
    var ticketGatePosition: TicketGatePosition?
    var nearestExitId: String?
    var editorialTags: [EditorialTag]
    var verificationStatus: VerificationStatus
    var source: PlaceSource
    var priceLevel: Int?
    var rating: Double?
    var reviewCount: Int?
    var isOpenNow: Bool?
    var shortDescriptionAr: String
    var shortDescriptionEn: String
    var indoorLocationNoteAr: String?
    var indoorLocationNoteEn: String?
    var lastVerifiedAt: Date?
    var verificationSource: String?
    var neighborhoodAr: String
    var neighborhoodEn: String
    var imageURLs: [String]
    var sourceURL: String? = nil
    var mapsURL: String? = nil
    var updatedAt: Date

    var coordinate: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    var isPublished: Bool {
        verificationStatus == .verified && stationRelation != .unverified
    }

    func localizedName(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
    }

    func localizedDescription(language: AppLanguage) -> String {
        language == .arabic ? shortDescriptionAr : shortDescriptionEn
    }

    func localizedNeighborhood(language: AppLanguage) -> String {
        language == .arabic ? neighborhoodAr : neighborhoodEn
    }

    var completenessScore: Double {
        var score = 0.4
        if rating != nil { score += 0.15 }
        if (reviewCount ?? 0) > 0 { score += 0.1 }
        if isOpenNow != nil { score += 0.1 }
        if !shortDescriptionAr.isEmpty { score += 0.1 }
        if !imageURLs.isEmpty { score += 0.15 }
        return min(score, 1)
    }
}

struct WalkingRoute: Hashable, Codable, Sendable {
    var from: GeoCoordinate
    var to: GeoCoordinate
    var distanceMeters: Double
    var durationSeconds: Double
    var isEstimated: Bool
    var source: RouteSource
    var calculatedAt: Date
    var path: [GeoCoordinate] = []

    var durationMinutes: Int {
        let fromDistance = distanceMeters / 80
        let fromTime = durationSeconds / 60
        let metersPerMinute = distanceMeters / max(durationSeconds / 60, 0.01)
        if (50...110).contains(metersPerMinute) {
            return max(1, Int(fromTime.rounded()))
        }
        return max(1, Int(fromDistance.rounded()))
    }

    var isReasonableWalk: Bool {
        distanceMeters > 8 && distanceMeters < 3_500 && durationSeconds < 45 * 60
    }
}

struct AccessSummary: Hashable, Sendable {
    var station: MetroStation
    var routeFromStation: WalkingRoute
    var exit: StationExit?
    var routeFromExit: WalkingRoute?
    var stationHasVerifiedExits: Bool

    var displayedMinutes: Int {
        (routeFromExit ?? routeFromStation).durationMinutes
    }

    var displayedMeters: Double {
        (routeFromExit ?? routeFromStation).distanceMeters
    }

    var usesEstimatedStationWalk: Bool {
        exit == nil
    }

    var displayedPath: [GeoCoordinate] {
        let route = routeFromExit ?? routeFromStation
        if route.path.count >= 2 { return route.path }
        return [route.from, route.to]
    }
}

struct RankedPlace: Identifiable, Hashable, Sendable {
    var place: Place
    var access: AccessSummary
    var score: Double

    var id: String { place.id }
}

struct PlaceSubmission: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var submittedBy: String
    var nameAr: String
    var nameEn: String
    var category: PlaceCategory
    var descriptionAr: String
    var descriptionEn: String
    var latitude: Double
    var longitude: Double
    var selectedStationId: String
    var stationRelationClaim: StationRelation
    var imageURLs: [String]
    var googleMapsURL: String?
    var status: SubmissionStatus
    var moderatorNotes: String
    var createdAt: Date
    var reviewedAt: Date?
    var reviewedBy: String?
}

struct FavoriteRecord: Identifiable, Hashable, Codable, Sendable {
    var id: String { "\(userId)|\(targetKind.rawValue)|\(targetId)" }
    var userId: String
    var targetId: String
    var targetKind: Kind
    var createdAt: Date

    enum Kind: String, Codable {
        case place
        case station
    }
}

struct PlaceReport: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var userId: String
    var placeId: String
    var reason: ReportReason
    var details: String
    var status: ReportStatus
    var createdAt: Date
}

struct UserProfile: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var displayName: String
    var role: UserRole
    var appleUserID: String?
}

struct DuplicateCandidate: Hashable, Sendable {
    var placeId: String
    var name: String
    var meters: Double
    var googlePlaceIdMatch: Bool
}
