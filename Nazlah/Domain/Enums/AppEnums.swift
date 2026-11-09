import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case arabic = "ar"
    case english = "en"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

enum StationType: String, Codable, CaseIterable, Identifiable {
    case underground
    case elevated
    case atGrade
    case interchangeHub

    var id: String { rawValue }
}

enum StationFacility: String, Codable, CaseIterable, Identifiable {
    case parking
    case prayerRoom
    case retail
    case customerService
    case restroom

    var id: String { rawValue }
}

enum CoordinateSource: String, Codable {
    case openStreetMap
    case approximatePublic
    case official
    case user
}

enum StationRelation: String, Codable, CaseIterable, Identifiable {
    case insideStation
    case directlyConnected
    case nearby
    case unverified

    var id: String { rawValue }
}

enum PlaceCategory: String, Codable, CaseIterable, Identifiable {
    case cafe
    case restaurant
    case dessert
    case park
    case viewpoint
    case cowork
    case family
    case gym
    case pharmacy
    case other

    var id: String { rawValue }
}

enum VerificationStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case pendingReview
    case needsInfo
    case verified
    case rejected
    case unpublished

    var id: String { rawValue }
}

enum SubmissionStatus: String, Codable, CaseIterable, Identifiable {
    case pendingReview
    case needsInfo
    case approved
    case rejected

    var id: String { rawValue }
}

enum TicketGatePosition: String, Codable, CaseIterable, Identifiable {
    case beforeGates
    case afterGates
    case unknown

    var id: String { rawValue }
}

enum AccessibilityKind: String, Codable, CaseIterable, Identifiable {
    case stepFree
    case stairsOnly
    case mixed
    case unknown

    var id: String { rawValue }
}

enum ExitVerificationStatus: String, Codable, CaseIterable, Identifiable {
    case unverified
    case pending
    case verified
    case rejected

    var id: String { rawValue }
}

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case guest
    case user
    case moderator
    case admin

    var id: String { rawValue }
}

enum ReportReason: String, Codable, CaseIterable, Identifiable {
    case wrongLocation
    case wrongStation
    case closed
    case duplicate
    case inappropriate
    case other

    var id: String { rawValue }
}

enum ReportStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case reviewing
    case resolved
    case dismissed

    var id: String { rawValue }
}

enum PlaceSource: String, Codable {
    case googlePlaces
    case editorial
    case userSubmission
    case sample
    case openStreetMap
}

enum EditorialTag: String, Codable, CaseIterable, Identifiable {
    case worthTheStop
    case workFriendly
    case familyFriendly
    case quiet
    case outdoorSeating
    case breakfast
    case dessert
    case sunsetView
    case wheelchairAccessible

    var id: String { rawValue }
}

enum RouteSource: String, Codable {
    case googleRoutes
    case mockGrid
    case cached
    case osrm
}

enum PlaceSortMode: String, CaseIterable, Identifiable {
    case walkingThenQuality
    case nearest
    case byLine

    var id: String { rawValue }
}

enum MapDisplayMode: String, CaseIterable, Identifiable {
    case map
    case list

    var id: String { rawValue }
}

enum PlaceFilter: String, CaseIterable, Identifiable, Hashable {
    case insideStation
    case underFiveMinutes
    case underTenMinutes
    case openNow
    case topRated
    case cheapest
    case workFriendly
    case familyFriendly
    case wheelchairAccessible
    case cafe
    case restaurant
    case sitting
    case worthTheStop

    var id: String { rawValue }
}
