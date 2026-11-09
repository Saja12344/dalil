import Foundation
import CoreLocation

protocol MetroCatalogServing: Sendable {
    func catalog() async throws -> MetroCatalog
}

protocol PlaceDiscovering: Sendable {
    func places(near station: MetroStation, radiusMeters: Double) async throws -> [Place]
    func place(id: String) async throws -> Place?
    func search(query: String, catalog: MetroCatalog) async throws -> [Place]
    func editorialWorthTheStop() async throws -> [Place]
    func publishedPlaces() async throws -> [Place]
}

protocol WalkingRouting: Sendable {
    func walkingRoute(from: GeoCoordinate, to: GeoCoordinate) async throws -> WalkingRoute
}

protocol AuthServing: Sendable {
    var currentUser: UserProfile? { get async }
    func signInWithApple(identityToken: Data, authorizationCode: Data, fullName: String?) async throws -> UserProfile
    func signOut() async throws
    func deleteAccount() async throws
    func requireSignedInUser() async throws -> UserProfile
}

protocol FavoritesServing: Sendable {
    func favorites(for userId: String) async throws -> [FavoriteRecord]
    func isFavorite(userId: String, targetId: String, kind: FavoriteRecord.Kind) async throws -> Bool
    func toggle(userId: String, targetId: String, kind: FavoriteRecord.Kind) async throws -> Bool
}

protocol SubmissionServing: Sendable {
    func submit(_ draft: PlaceSubmission) async throws -> PlaceSubmission
    func submissions(for userId: String) async throws -> [PlaceSubmission]
    func submission(id: String) async throws -> PlaceSubmission?
}

protocol ReportServing: Sendable {
    func submit(_ report: PlaceReport) async throws
    func reports(for userId: String) async throws -> [PlaceReport]
}

protocol LocationServing: Sendable {
    var authorization: CLAuthorizationStatus { get async }
    func requestWhenInUse() async -> CLAuthorizationStatus
    func requestAlways() async -> CLAuthorizationStatus
    func currentCoordinate() async throws -> GeoCoordinate
    func locationStream() -> AsyncStream<GeoCoordinate>
    func stopTripUpdates()
}

protocol ImageUploading: Sendable {
    func uploadPlaceImages(_ images: [Data], submissionId: String) async throws -> [String]
}

protocol ModeratorServing: Sendable {
    func pendingSubmissions() async throws -> [PlaceSubmission]
    func approve(submissionId: String, reviewerId: String, edits: PlaceSubmission?) async throws
    func requestInfo(submissionId: String, reviewerId: String, notes: String) async throws
    func reject(submissionId: String, reviewerId: String, notes: String) async throws
    func duplicateCandidates(for submission: PlaceSubmission, existing: [Place]) -> [DuplicateCandidate]
}

enum AuthNeed: Error, Equatable {
    case signInRequired
}

enum LocationFailure: Error, Equatable {
    case denied
    case unavailable
}

enum CatalogFailure: Error, Equatable {
    case missingResource
    case decodingFailed
}

enum RouteFailure: Error, Equatable {
    case noWalkableRoute
}
