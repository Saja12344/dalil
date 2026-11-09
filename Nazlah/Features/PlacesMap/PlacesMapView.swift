import MapKit
import SwiftUI

struct PlacesMapView: View {
    @EnvironmentObject private var session: CatalogSession
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @State private var mode: MapDisplayMode = .map
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753),
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
        )
    )
    @State private var selected: RankedPlace?
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("map.mode", selection: $mode) {
                Text("map.mode.map").tag(MapDisplayMode.map)
                Text("map.mode.list").tag(MapDisplayMode.list)
            }
            .pickerStyle(.segmented)
            .padding(16)
            if mode == .map {
                mapCanvas
                    .environment(\.layoutDirection, .leftToRight)
            } else {
                listCanvas
            }
        }
        .background(Color("Canvas").ignoresSafeArea())
        .navigationTitle("map.title")
        .task {
            if session.catalog == nil { await session.load() }
        }
        .sheet(item: $selected) { item in
            PlacePreviewSheet(ranked: item) {
                selected = nil
                router.open(.place(item.place.id))
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var mapCanvas: some View {
        Group {
            if let catalog = session.catalog {
                GeographicMetroMap(
                    catalog: catalog,
                    selectedLineId: nil,
                    selectedStationId: nil,
                    language: settings.language,
                    interactive: true,
                    showsAllStations: true,
                    places: filteredPlaces.prefix(80).map {
                        GoogleMapPlacePin(
                            id: $0.place.id,
                            name: $0.place.localizedName(language: settings.language),
                            latitude: $0.place.latitude,
                            longitude: $0.place.longitude
                        )
                    },
                    onSelect: { router.open(.station($0.id)) },
                    onPlace: { router.open(.place($0)) },
                    camera: $camera
                )
            } else {
                AppColors.navy
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let selected {
                PlacePreviewSheet(ranked: selected) {
                    router.open(.place(selected.place.id))
                }
                .padding(12)
            }
        }
    }

    private var listCanvas: some View {
        List(filteredPlaces) { item in
            Button {
                router.open(.place(item.place.id))
            } label: {
                PlaceCard(ranked: item, language: settings.language, lines: session.catalog?.lines(for: item.access.station) ?? [])
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .searchable(text: $query, prompt: "home.search.placeholder")
    }

    private var filteredPlaces: [RankedPlace] {
        guard !query.isEmpty else { return session.rankedPlaces }
        return session.rankedPlaces.filter {
            $0.place.localizedName(language: settings.language).localizedCaseInsensitiveContains(query)
        }
    }
}

struct MapMarkerDot: View {
    var category: PlaceCategory
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(Color("OffWhite"), lineWidth: 2))
    }

    private var color: Color {
        switch category {
        case .cafe, .cowork: return AppColors.brandOrange
        case .restaurant, .dessert: return Color(hex: "#B8572A")
        case .park, .viewpoint: return Color("PalmGreen")
        default: return AppColors.navy
        }
    }
}

struct PlacePreviewSheet: View {
    var ranked: RankedPlace
    var open: () -> Void
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ranked.place.localizedName(language: settings.language))
                .font(NazlahTypography.title(20))
            WalkingAccessBadge(access: ranked.access, language: settings.language)
            NazlahButton(title: "place.openDetails", action: open)
        }
        .padding(16)
        .background(Color("CanvasElevated"))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
