import Foundation

/// Grid-aware walking estimate for development. This is a Routes API stand-in,
/// not a straight-line ranking shortcut. Exit selection still goes through this protocol.
struct MockWalkingRouteService: WalkingRouting {
    func walkingRoute(from: GeoCoordinate, to: GeoCoordinate) async throws -> WalkingRoute {
        let straight = from.distanceMeters(to: to)
        // Riyadh blocks are closer to a Manhattan / fragmented grid than a crow-fly path.
        let latDelta = abs(from.latitude - to.latitude) * 111_320
        let meanLat = (from.latitude + to.latitude) / 2 * .pi / 180
        let lonDelta = abs(from.longitude - to.longitude) * 111_320 * cos(meanLat)
        let grid = latDelta + lonDelta
        let walkingMeters = max(straight * 1.18, grid * 0.92)
        if walkingMeters > 3_800 {
            throw RouteFailure.noWalkableRoute
        }
        let speedMps = 1.28
        let corner = GeoCoordinate(latitude: from.latitude, longitude: to.longitude)
        return WalkingRoute(
            from: from,
            to: to,
            distanceMeters: walkingMeters,
            durationSeconds: walkingMeters / speedMps,
            isEstimated: true,
            source: .mockGrid,
            calculatedAt: .now,
            path: [from, corner, to]
        )
    }
}

@MainActor
final class InMemoryAuthService: AuthServing {
    private(set) var currentUser: UserProfile?

    func signInWithApple(identityToken: Data, authorizationCode: Data, fullName: String?) async throws -> UserProfile {
        let profile = UserProfile(
            id: "apple-\(UUID().uuidString)",
            displayName: fullName?.isEmpty == false ? fullName! : "Nazlah",
            role: .user,
            appleUserID: UUID().uuidString
        )
        currentUser = profile
        return profile
    }

    func signInMockModerator() {
        currentUser = UserProfile(id: "mod-local", displayName: "Moderator", role: .moderator, appleUserID: "mod")
    }

    func signInMockUser() {
        currentUser = UserProfile(id: "user-local", displayName: "Guest User", role: .user, appleUserID: "local")
    }

    func signOut() async throws {
        currentUser = nil
    }

    func deleteAccount() async throws {
        currentUser = nil
    }

    func requireSignedInUser() async throws -> UserProfile {
        guard let currentUser else { throw AuthNeed.signInRequired }
        return currentUser
    }
}

actor InMemoryFavoritesService: FavoritesServing {
    private var records: [FavoriteRecord] = []

    func favorites(for userId: String) async throws -> [FavoriteRecord] {
        records.filter { $0.userId == userId }
    }

    func isFavorite(userId: String, targetId: String, kind: FavoriteRecord.Kind) async throws -> Bool {
        records.contains { $0.userId == userId && $0.targetId == targetId && $0.targetKind == kind }
    }

    func toggle(userId: String, targetId: String, kind: FavoriteRecord.Kind) async throws -> Bool {
        if let index = records.firstIndex(where: { $0.userId == userId && $0.targetId == targetId && $0.targetKind == kind }) {
            records.remove(at: index)
            return false
        }
        records.append(FavoriteRecord(userId: userId, targetId: targetId, targetKind: kind, createdAt: .now))
        return true
    }
}

actor InMemorySubmissionService: SubmissionServing {
    private var items: [PlaceSubmission] = []
    private let limiter = RateLimiter()

    func submit(_ draft: PlaceSubmission) async throws -> PlaceSubmission {
        guard await limiter.allow(key: "submit-\(draft.submittedBy)", limit: 8, window: 24 * 60 * 60) else {
            throw SubmissionLimitError.tooMany
        }
        items.append(draft)
        return draft
    }

    func submissions(for userId: String) async throws -> [PlaceSubmission] {
        items.filter { $0.submittedBy == userId }.sorted { $0.createdAt > $1.createdAt }
    }

    func submission(id: String) async throws -> PlaceSubmission? {
        items.first { $0.id == id }
    }

    func update(_ item: PlaceSubmission) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }

    func all() -> [PlaceSubmission] { items }
}

enum SubmissionLimitError: Error {
    case tooMany
}

actor InMemoryReportService: ReportServing {
    private var items: [PlaceReport] = []
    private let limiter = RateLimiter()

    func submit(_ report: PlaceReport) async throws {
        guard await limiter.allow(key: "report-\(report.userId)", limit: 12, window: 24 * 60 * 60) else {
            throw SubmissionLimitError.tooMany
        }
        items.append(report)
    }

    func reports(for userId: String) async throws -> [PlaceReport] {
        items.filter { $0.userId == userId }
    }
}

actor InMemoryImageUploader: ImageUploading {
    func uploadPlaceImages(_ images: [Data], submissionId: String) async throws -> [String] {
        images.enumerated().map { index, _ in
            "local://submissions/\(submissionId)/\(index).jpg"
        }
    }
}

struct InMemoryModeratorService: ModeratorServing {
    let submissions: InMemorySubmissionService

    func pendingSubmissions() async throws -> [PlaceSubmission] {
        await submissions.all().filter { $0.status == .pendingReview || $0.status == .needsInfo }
    }

    func approve(submissionId: String, reviewerId: String, edits: PlaceSubmission?) async throws {
        guard var item = try await submissions.submission(id: submissionId) else { return }
        if let edits { item = edits }
        item.status = .approved
        item.reviewedAt = .now
        item.reviewedBy = reviewerId
        await submissions.update(item)
    }

    func requestInfo(submissionId: String, reviewerId: String, notes: String) async throws {
        guard var item = try await submissions.submission(id: submissionId) else { return }
        item.status = .needsInfo
        item.moderatorNotes = notes
        item.reviewedAt = .now
        item.reviewedBy = reviewerId
        await submissions.update(item)
    }

    func reject(submissionId: String, reviewerId: String, notes: String) async throws {
        guard var item = try await submissions.submission(id: submissionId) else { return }
        item.status = .rejected
        item.moderatorNotes = notes
        item.reviewedAt = .now
        item.reviewedBy = reviewerId
        await submissions.update(item)
    }

    func duplicateCandidates(for submission: PlaceSubmission, existing: [Place]) -> [DuplicateCandidate] {
        let origin = GeoCoordinate(latitude: submission.latitude, longitude: submission.longitude)
        return existing.compactMap { place in
            let meters = place.coordinate.distanceMeters(to: origin)
            let nameHit = place.nameAr == submission.nameAr || place.nameEn.caseInsensitiveCompare(submission.nameEn) == .orderedSame
            let googleHit = false
            guard meters < 120 || nameHit else { return nil }
            return DuplicateCandidate(
                placeId: place.id,
                name: place.nameEn,
                meters: meters,
                googlePlaceIdMatch: googleHit
            )
        }
    }
}
