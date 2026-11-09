import Foundation

enum SampleDataLoader {
    static func data(named name: String, ext: String = "json") throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw CatalogFailure.missingResource
        }
        return try Data(contentsOf: url)
    }
}

struct JSONMetroCatalogService: MetroCatalogServing {
    func catalog() async throws -> MetroCatalog {
        let data = try SampleDataLoader.data(named: "metro_catalog")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let raw = try decoder.decode(RawCatalog.self, from: data)
        return MetroCatalog(
            lines: raw.lines,
            stations: raw.stations,
            exits: raw.exits,
            attribution: raw.attribution
        )
    }

    private struct RawCatalog: Decodable {
        var attribution: DataAttribution
        var lines: [MetroLine]
        var stations: [MetroStation]
        var exits: [StationExit]
    }
}

struct JSONPlaceStore {
    func allPlaces() throws -> [Place] {
        let data = try SampleDataLoader.data(named: "places")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RawPlaces.self, from: data).places.map { raw in
            Place(
                id: raw.id,
                googlePlaceId: raw.googlePlaceId,
                nameAr: raw.nameAr,
                nameEn: raw.nameEn,
                latitude: raw.latitude,
                longitude: raw.longitude,
                category: raw.category,
                stationId: raw.stationId,
                stationRelation: raw.stationRelation,
                floor: raw.floor,
                ticketGatePosition: raw.ticketGatePosition,
                nearestExitId: raw.nearestExitId,
                editorialTags: raw.editorialTags,
                verificationStatus: raw.verificationStatus,
                source: raw.source,
                priceLevel: raw.priceLevel,
                rating: raw.rating,
                reviewCount: raw.reviewCount,
                isOpenNow: raw.isOpenNow,
                shortDescriptionAr: raw.shortDescriptionAr,
                shortDescriptionEn: raw.shortDescriptionEn,
                indoorLocationNoteAr: raw.indoorLocationNoteAr,
                indoorLocationNoteEn: raw.indoorLocationNoteEn,
                lastVerifiedAt: raw.lastVerifiedAt,
                verificationSource: raw.verificationSource,
                neighborhoodAr: raw.neighborhoodAr,
                neighborhoodEn: raw.neighborhoodEn,
                imageURLs: raw.imageURLs ?? [],
                sourceURL: raw.sourceURL,
                mapsURL: raw.mapsURL,
                updatedAt: raw.updatedAt
            )
        }
    }

    private struct RawPlaces: Decodable {
        var places: [RawPlace]
    }

    private struct RawPlace: Decodable {
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
        var imageURLs: [String]?
        var sourceURL: String?
        var mapsURL: String?
        var updatedAt: Date
    }
}

struct MockPlaceDiscoveryService: PlaceDiscovering {
    private let store = JSONPlaceStore()

    func places(near station: MetroStation, radiusMeters: Double) async throws -> [Place] {
        try store.allPlaces().filter { place in
            guard place.isPublished else { return false }
            if place.stationId == station.id { return true }
            return place.coordinate.distanceMeters(to: station.coordinate) <= radiusMeters
        }
    }

    func place(id: String) async throws -> Place? {
        try store.allPlaces().first { $0.id == id }
    }

    func search(query: String, catalog: MetroCatalog) async throws -> [Place] {
        let index = PlaceSearchIndex()
        return try store.allPlaces().filter { place in
            guard place.isPublished else { return false }
            return index.matches(place, station: catalog.station(id: place.stationId), query: query, language: .arabic)
                || index.matches(place, station: catalog.station(id: place.stationId), query: query, language: .english)
        }
    }

    func editorialWorthTheStop() async throws -> [Place] {
        try store.allPlaces().filter { $0.editorialTags.contains(.worthTheStop) && $0.isPublished }
    }

    func publishedPlaces() async throws -> [Place] {
        try store.allPlaces().filter(\.isPublished)
    }
}
