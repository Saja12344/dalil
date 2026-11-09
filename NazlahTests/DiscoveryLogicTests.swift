import XCTest
@testable import Nazlah

final class NearestStationFinderTests: XCTestCase {
    func testNearestStationUsesGeographicDistance() async throws {
        let catalog = try await JSONMetroCatalogService().catalog()
        let finder = NearestStationFinder()
        let olaya = GeoCoordinate(latitude: 24.6965, longitude: 46.6837)
        let station = finder.nearest(to: olaya, in: catalog)
        XCTAssertEqual(station?.id, "bank_albilad")
    }

    func testRankedStationsAreOrderedByDistance() async throws {
        let catalog = try await JSONMetroCatalogService().catalog()
        let finder = NearestStationFinder()
        let ranked = finder.ranked(to: GeoCoordinate(latitude: 24.7674, longitude: 46.6432), in: catalog, limit: 3)
        XCTAssertEqual(ranked.first?.id, "kafd")
        XCTAssertGreaterThan(ranked.count, 1)
    }
}

struct ScriptedWalkingRouter: WalkingRouting {
    var secondsByStartLatitude: [Double: Double]

    func walkingRoute(from: GeoCoordinate, to: GeoCoordinate) async throws -> WalkingRoute {
        let seconds = secondsByStartLatitude[from.latitude] ?? 9_999
        return WalkingRoute(
            from: from,
            to: to,
            distanceMeters: seconds * 1.3,
            durationSeconds: seconds,
            isEstimated: false,
            source: .googleRoutes,
            calculatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

final class VerifiedExitSelectorTests: XCTestCase {
    func testDoesNotChooseExitWithoutVerifiedRecords() async throws {
        let router = ScriptedWalkingRouter(secondsByStartLatitude: [24.1: 30, 24.2: 10])
        let selector = VerifiedExitSelector(routing: router)
        let station = sampleStation(hasVerifiedExits: false)
        let exits = [
            sampleExit(id: "a", lat: 24.1, number: "1"),
            sampleExit(id: "b", lat: 24.2, number: "2")
        ]
        let result = try await selector.bestExit(
            station: station,
            exits: exits,
            destination: GeoCoordinate(latitude: 24.3, longitude: 46.7)
        )
        XCTAssertNil(result)
    }

    func testChoosesShortestWalkingRouteNotClosestCoordinate() async throws {
        let router = ScriptedWalkingRouter(secondsByStartLatitude: [
            24.6960: 420,
            24.6970: 90
        ])
        let selector = VerifiedExitSelector(routing: router)
        let station = sampleStation(hasVerifiedExits: true)
        let nearButSlow = sampleExit(id: "near", lat: 24.6960, number: "1")
        let fartherButFaster = sampleExit(id: "far", lat: 24.6970, number: "3")
        let result = try await selector.bestExit(
            station: station,
            exits: [nearButSlow, fartherButFaster],
            destination: GeoCoordinate(latitude: 24.6965, longitude: 46.6850)
        )
        XCTAssertEqual(result?.exit.exitNumber, "3")
        XCTAssertEqual(result?.route.durationSeconds, 90)
    }

    func testIgnoresUnverifiedExitsEvenIfFaster() async throws {
        let router = ScriptedWalkingRouter(secondsByStartLatitude: [
            24.6960: 40,
            24.6970: 200
        ])
        let selector = VerifiedExitSelector(routing: router)
        let station = sampleStation(hasVerifiedExits: true)
        var unverified = sampleExit(id: "x", lat: 24.6960, number: "9")
        unverified.verificationStatus = .unverified
        let verified = sampleExit(id: "y", lat: 24.6970, number: "2")
        let result = try await selector.bestExit(
            station: station,
            exits: [unverified, verified],
            destination: GeoCoordinate(latitude: 24.70, longitude: 46.68)
        )
        XCTAssertEqual(result?.exit.exitNumber, "2")
    }

    private func sampleStation(hasVerifiedExits: Bool) -> MetroStation {
        MetroStation(
            id: "bank_albilad",
            nameAr: "بنك البلاد",
            nameEn: "Bank Albilad",
            lineIds: ["blue"],
            latitude: 24.6965,
            longitude: 46.6837,
            stationType: .underground,
            facilities: [],
            hasVerifiedExits: hasVerifiedExits,
            hasVerifiedIndoorPlaces: false,
            heroImageURL: nil,
            coordinateSource: .openStreetMap,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func sampleExit(id: String, lat: Double, number: String) -> StationExit {
        StationExit(
            id: id,
            stationId: "bank_albilad",
            exitNumber: number,
            nameAr: "مخرج \(number)",
            nameEn: "Exit \(number)",
            latitude: lat,
            longitude: 46.6837,
            directionAr: "العليا",
            directionEn: "Olaya",
            nearbyLandmarkAr: "",
            nearbyLandmarkEn: "",
            accessibilityType: .unknown,
            verificationStatus: .verified,
            verifiedAt: Date(timeIntervalSince1970: 0),
            verifiedBy: "test"
        )
    }
}

final class PlaceRankerTests: XCTestCase {
    func testEditorialWorthTheStopOutranksWeakNearbyPlace() {
        let ranker = PlaceRanker()
        let station = MetroStation(
            id: "stc",
            nameAr: "STC",
            nameEn: "STC",
            lineIds: ["blue"],
            latitude: 24.72,
            longitude: 46.66,
            stationType: .interchangeHub,
            facilities: [],
            hasVerifiedExits: false,
            hasVerifiedIndoorPlaces: true,
            heroImageURL: nil,
            coordinateSource: .openStreetMap,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let accessFast = AccessSummary(
            station: station,
            routeFromStation: route(seconds: 120),
            exit: nil,
            routeFromExit: nil,
            stationHasVerifiedExits: false
        )
        let accessSlow = AccessSummary(
            station: station,
            routeFromStation: route(seconds: 180),
            exit: nil,
            routeFromExit: nil,
            stationHasVerifiedExits: false
        )
        var editorial = samplePlace(id: "a", rating: 4.2, reviews: 40, open: true)
        editorial.editorialTags = [.worthTheStop]
        editorial.source = .editorial
        var generic = samplePlace(id: "b", rating: 4.9, reviews: 12, open: false)
        generic.editorialTags = []
        let ranked = ranker.rank([
            RankedPlace(place: editorial, access: accessSlow, score: ranker.score(place: editorial, access: accessSlow)),
            RankedPlace(place: generic, access: accessFast, score: ranker.score(place: generic, access: accessFast))
        ])
        XCTAssertEqual(ranked.first?.place.id, "a")
    }

    func testDropsUnwalkableRoutesUnlessInsideStation() {
        let ranker = PlaceRanker()
        let station = MetroStation(
            id: "kafd",
            nameAr: "كافد",
            nameEn: "KAFD",
            lineIds: ["blue"],
            latitude: 24.76,
            longitude: 46.64,
            stationType: .interchangeHub,
            facilities: [],
            hasVerifiedExits: false,
            hasVerifiedIndoorPlaces: true,
            heroImageURL: nil,
            coordinateSource: .openStreetMap,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        var indoor = samplePlace(id: "in", rating: 4.0, reviews: 10, open: true)
        indoor.stationRelation = .insideStation
        var far = samplePlace(id: "far", rating: 5.0, reviews: 900, open: true)
        far.stationRelation = .nearby
        let indoorRanked = RankedPlace(
            place: indoor,
            access: AccessSummary(station: station, routeFromStation: route(seconds: 20), exit: nil, routeFromExit: nil, stationHasVerifiedExits: false),
            score: 1
        )
        let farRanked = RankedPlace(
            place: far,
            access: AccessSummary(station: station, routeFromStation: route(seconds: 8_000, meters: 9_000), exit: nil, routeFromExit: nil, stationHasVerifiedExits: false),
            score: 1
        )
        let ranked = ranker.rank([indoorRanked, farRanked])
        XCTAssertEqual(ranked.map(\.place.id), ["in"])
    }

    private func route(seconds: Double, meters: Double = 200) -> WalkingRoute {
        WalkingRoute(
            from: GeoCoordinate(latitude: 24, longitude: 46),
            to: GeoCoordinate(latitude: 24.001, longitude: 46.001),
            distanceMeters: meters,
            durationSeconds: seconds,
            isEstimated: true,
            source: .mockGrid,
            calculatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func samplePlace(id: String, rating: Double, reviews: Int, open: Bool) -> Place {
        Place(
            id: id,
            googlePlaceId: nil,
            nameAr: "مكان",
            nameEn: "Place",
            latitude: 24.72,
            longitude: 46.66,
            category: .cafe,
            stationId: "stc",
            stationRelation: .nearby,
            floor: nil,
            ticketGatePosition: nil,
            nearestExitId: nil,
            editorialTags: [],
            verificationStatus: .verified,
            source: .sample,
            priceLevel: 2,
            rating: rating,
            reviewCount: reviews,
            isOpenNow: open,
            shortDescriptionAr: "وصف",
            shortDescriptionEn: "desc",
            indoorLocationNoteAr: nil,
            indoorLocationNoteEn: nil,
            lastVerifiedAt: nil,
            verificationSource: nil,
            neighborhoodAr: "العليا",
            neighborhoodEn: "Olaya",
            imageURLs: [],
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

final class LineColorTests: XCTestCase {
    func testCatalogHexesResolveToOfficialLines() {
        XCTAssertEqual(LineColor.from(hex: "#00ADE5"), .blue)
        XCTAssertEqual(LineColor.from(hex: "F0493A"), .red)
        XCTAssertEqual(LineColor.from(hex: "#f68d39"), .orange)
        XCTAssertEqual(LineColor.from(hex: "FFD105"), .yellow)
        XCTAssertEqual(LineColor.from(hex: "#43B649"), .green)
        XCTAssertEqual(LineColor.from(hex: "984C9D"), .purple)
    }

    func testLineIdsAndNumbersMatchRCRCOrder() {
        XCTAssertEqual(LineColor.from(id: "blue")?.number, "1")
        XCTAssertEqual(LineColor.from(id: "purple")?.code, "M6")
        XCTAssertEqual(LineColor.resolving(id: "green", hex: "#FFFFFF"), .green)
        XCTAssertEqual(LineColor.resolving(hex: "#00ADE5"), .blue)
    }

    func testMetroLineFallsBackForUnknownHex() {
        XCTAssertNotNil(LineColor.from(hex: "#00ADE5"))
        XCTAssertNil(LineColor.from(hex: "#123456"))
    }

    func testTextStyleScale() {
        XCTAssertEqual(AppTextStyle.largeTitle.size, 32)
        XCTAssertEqual(AppTextStyle.title.size, 22)
        XCTAssertEqual(AppTextStyle.headline.size, 17)
        XCTAssertEqual(AppTextStyle.body.size, 16)
        XCTAssertEqual(AppTextStyle.subhead.size, 14)
        XCTAssertEqual(AppTextStyle.caption.size, 12)
        XCTAssertEqual(AppSpacing.screen, 16)
        XCTAssertEqual(AppSpacing.section, 24)
    }
}
