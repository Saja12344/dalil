import MapKit
import SwiftUI
import UIKit
import WebKit

enum MetroGeographicLayout {
    static let networkRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 24.72, longitude: 46.70),
        span: MKCoordinateSpan(latitudeDelta: 0.48, longitudeDelta: 0.42)
    )

    static func region(selectedLineId: String?, catalog: MetroCatalog) -> MKCoordinateRegion {
        guard let selectedLineId, let line = catalog.line(id: selectedLineId) else {
            return networkRegion
        }
        let coords = line.mapCoordinates(in: catalog)
        guard let first = coords.first else { return networkRegion }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for coord in coords.dropFirst() {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        let latPad = max((maxLat - minLat) * 0.18, 0.04)
        let lonPad = max((maxLon - minLon) * 0.18, 0.04)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: (maxLat - minLat) + latPad, longitudeDelta: (maxLon - minLon) + lonPad)
        )
    }
}

struct GeographicMetroMap: View {
    var catalog: MetroCatalog
    var selectedLineId: String?
    var selectedStationId: String?
    var language: AppLanguage
    var interactive: Bool = true
    var showsAllStations: Bool = true
    var searchText: String = ""
    var places: [GoogleMapPlacePin] = []
    var walk: [GeoCoordinate] = []
    var followCoordinate: GeoCoordinate? = nil
    var userCoordinate: GeoCoordinate? = nil
    var onSelect: (MetroStation) -> Void
    var onPlace: (String) -> Void = { _ in }
    var onMapTap: (GeoCoordinate) -> Void = { _ in }
    @Binding var camera: MapCameraPosition
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GoogleMetroWebMap(
            payload: payload,
            onStation: { id in
                if let station = catalog.station(id: id) { onSelect(station) }
            },
            onPlace: onPlace,
            onMapTap: onMapTap
        )
        .environment(\.layoutDirection, .leftToRight)
    }

    private var visibleStations: [MetroStation] {
        var stations: [MetroStation]
        if !showsAllStations {
            stations = catalog.stations.filter(\.isInterchange)
        } else if let selectedLineId {
            stations = catalog.stations(on: selectedLineId)
        } else {
            stations = catalog.stations
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            stations = stations.filter { $0.localizedName(language: language).localizedCaseInsensitiveContains(q) }
        }
        return stations
    }

    private var payload: [String: Any] {
        let stations = visibleStations
        let centerStation = stations.first(where: { $0.id == selectedStationId }) ?? stations.first
        let centerLat = followCoordinate?.latitude ?? centerStation?.latitude ?? 24.72
        let centerLng = followCoordinate?.longitude ?? centerStation?.longitude ?? 46.70
        var payload: [String: Any] = [
            "center": [
                "lat": centerLat,
                "lng": centerLng
            ],
            "zoom": followCoordinate != nil || userCoordinate != nil ? 14 : (selectedLineId == nil && walk.isEmpty ? 11 : 14),
            "interactive": interactive,
            "lines": catalog.lines.filter { selectedLineId == nil || $0.id == selectedLineId }.map { line in
                [
                    "color": line.colorHex.hasPrefix("#") ? line.colorHex : "#\(line.colorHex)",
                    "width": selectedLineId == line.id ? 6 : 4,
                    "dim": false,
                    "path": line.mapCoordinates(in: catalog).map { ["lat": $0.latitude, "lng": $0.longitude] }
                ]
            },
            "stations": stations.map { station in
                [
                    "id": station.id,
                    "name": station.localizedName(language: language),
                    "pos": ["lat": station.latitude, "lng": station.longitude],
                    "big": station.isInterchange || station.id == selectedStationId,
                    "swap": station.isInterchange,
                    "color": catalog.line(id: station.lineIds[0])?.colorHex ?? "#FFFFFF"
                ]
            },
            "places": places.map { pin in
                [
                    "id": pin.id,
                    "name": pin.name,
                    "pos": ["lat": pin.latitude, "lng": pin.longitude],
                    "color": pin.color.hasPrefix("#") ? pin.color : "#\(pin.color)"
                ]
            },
            "walk": walk.map { ["lat": $0.latitude, "lng": $0.longitude] },
            "dark": colorScheme == .dark,
            "palette": colorScheme == .dark ? Self.darkPalette : Self.lightPalette
        ]
        if let user = userCoordinate ?? followCoordinate {
            payload["user"] = ["lat": user.latitude, "lng": user.longitude]
        }
        return payload
    }

    private static let lightPalette: [String: String] = [
        "bg": "#F7F5F0",
        "roadMajor": "#FFFFFF",
        "roadMinor": "#E7E1D8",
        "residential": "#F0ECE4",
        "park": "#DCE8D8",
        "water": "#DCE9EB",
        "walk": "#F15A29",
        "text": "#514A43",
        "markerFill": "#FFFFFF",
        "navy": "#111111"
    ]

    private static let darkPalette: [String: String] = [
        "bg": "#171717",
        "roadMajor": "#353535",
        "roadMinor": "#292929",
        "residential": "#202020",
        "park": "#26372B",
        "water": "#202F33",
        "walk": "#FF7547",
        "text": "#D6D0C8",
        "markerFill": "#1A1A1A",
        "navy": "#ECE6DB"
    ]
}

struct GoogleMapPlacePin: Identifiable, Hashable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var color: String = "008E51"
}

enum GoogleMetroMapHTML {
    static var source: String {
        let key = APIKeyStore.googleMapsKey
        return html.replacingOccurrences(of: "KEY_PLACEHOLDER", with: key)
    }

    private static let html = """
    <!DOCTYPE html><html><head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"/>
    <link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css"/>
    <style>
    html,body,#map{height:100%;margin:0}
    #map{background:#F7F5F0}
    html.dark #map{background:#171717}
    .maplibregl-ctrl-attrib{background:transparent!important;color:#514A43;font-size:9px;max-width:46%}
    html.dark .maplibregl-ctrl-attrib{color:#D6D0C8}
    .maplibregl-ctrl-attrib a{color:inherit}
    .maplibregl-ctrl-logo{display:none}
    </style>
    </head><body><div id="map"></div>
    <script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
    <script>
    let map, bootPayload;
    function boot(payload){bootPayload=payload;if(window.maplibregl)draw(payload);}
    if(window.maplibregl&&maplibregl.setRTLTextPlugin){
      try{maplibregl.setRTLTextPlugin('https://unpkg.com/@mapbox/mapbox-gl-rtl-text@0.3.0/dist/mapbox-gl-rtl-text.js',false);}catch(e){}
    }
    function pal(p){
      return Object.assign({
        bg:'#F7F5F0',roadMajor:'#FFFFFF',roadMinor:'#E7E1D8',residential:'#F0ECE4',
        park:'#DCE8D8',water:'#DCE9EB',walk:'#F15A29',text:'#514A43'
      }, p.palette||{});
    }
    function zoomW(stops){return ['interpolate',['exponential',1.2],['zoom']].concat(stops);}
    function nameField(){return ['coalesce',['get','name:ar'],['get','name'],['get','name:en'],['get','name_en']];}
    function styleFor(c){
      var major=['motorway','trunk','primary','secondary'];
      var minor=['tertiary','minor','service','path','track','pedestrian'];
      return {
        version:8,
        glyphs:'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf',
        sources:{osm:{type:'vector',url:'https://tiles.openfreemap.org/planet'}},
        layers:[
          {id:'bg',type:'background',paint:{'background-color':c.bg}},
          {id:'res',type:'fill',source:'osm','source-layer':'landuse',filter:['==',['get','class'],'residential'],paint:{'fill-color':c.residential}},
          {id:'park-fill',type:'fill',source:'osm','source-layer':'park',paint:{'fill-color':c.park}},
          {id:'grass',type:'fill',source:'osm','source-layer':'landcover',filter:['in',['get','class'],['literal',['grass','wood']]],paint:{'fill-color':c.park}},
          {id:'water-fill',type:'fill',source:'osm','source-layer':'water',paint:{'fill-color':c.water}},
          {id:'water-line',type:'line',source:'osm','source-layer':'waterway',paint:{'line-color':c.water,'line-width':zoomW([11,0.6,16,2.4])}},
          {id:'build',type:'fill',source:'osm','source-layer':'building',minzoom:13,paint:{'fill-color':c.residential,'fill-opacity':0.55}},
          {id:'road-minor-case',type:'line',source:'osm','source-layer':'transportation',filter:['in',['get','class'],['literal',minor]],layout:{'line-cap':'round','line-join':'round'},paint:{'line-color':c.darkCasing,'line-width':zoomW([12,1.6,16,7,20,14])}},
          {id:'road-minor',type:'line',source:'osm','source-layer':'transportation',filter:['in',['get','class'],['literal',minor]],layout:{'line-cap':'round','line-join':'round'},paint:{'line-color':c.roadMinor,'line-width':zoomW([12,0.8,16,4.5,20,10])}},
          {id:'road-major-case',type:'line',source:'osm','source-layer':'transportation',filter:['in',['get','class'],['literal',major]],layout:{'line-cap':'round','line-join':'round'},paint:{'line-color':c.roadMinor,'line-width':zoomW([8,1.8,14,8,20,22])}},
          {id:'road-major',type:'line',source:'osm','source-layer':'transportation',filter:['in',['get','class'],['literal',major]],layout:{'line-cap':'round','line-join':'round'},paint:{'line-color':c.roadMajor,'line-width':zoomW([8,0.8,14,5,20,16])}},
          {id:'road-label',type:'symbol',source:'osm','source-layer':'transportation_name',minzoom:13,layout:{'symbol-placement':'line','text-field':nameField(),'text-font':['Noto Sans Regular'],'text-size':11},paint:{'text-color':c.text,'text-halo-color':c.bg,'text-halo-width':1.2}},
          {id:'place-label',type:'symbol',source:'osm','source-layer':'place',minzoom:11,layout:{'text-field':nameField(),'text-font':['Noto Sans Regular'],'text-size':['interpolate',['linear'],['zoom'],11,10,15,13],'text-max-width':8},paint:{'text-color':c.text,'text-halo-color':c.bg,'text-halo-width':1.2}}
        ]
      };
    }
    function fcLine(items, pathKey){
      return {type:'FeatureCollection',features:(items||[]).filter(function(x){return x[pathKey]&&x[pathKey].length>=2;}).map(function(x){
        return {type:'Feature',properties:{color:x.color||'#F15A29',width:x.width||4,opacity:x.dim?0.25:1},geometry:{type:'LineString',coordinates:x[pathKey].map(function(p){return [p.lng,p.lat];})}};
      })};
    }
    function fcPoints(items){
      return {type:'FeatureCollection',features:(items||[]).map(function(x){
        return {type:'Feature',properties:{id:x.id,color:x.color,r:x.big?7:5,swap:!!x.swap},geometry:{type:'Point',coordinates:[x.pos.lng,x.pos.lat]}};
      })};
    }
    function addOverlays(p,c){
      map.addSource('metro',{type:'geojson',data:fcLine(p.lines,'path')});
      map.addLayer({id:'metro-line',type:'line',source:'metro',layout:{'line-cap':'round','line-join':'round'},paint:{'line-color':['get','color'],'line-width':['get','width'],'line-opacity':['get','opacity']}});
      if(p.walk&&p.walk.length>=2){
        map.addSource('walk',{type:'geojson',data:{type:'Feature',geometry:{type:'LineString',coordinates:p.walk.map(function(pt){return [pt.lng,pt.lat];})}}});
        map.addLayer({id:'walk-case',type:'line',source:'walk',layout:{'line-cap':'round','line-join':'round'},paint:{'line-color':c.bg,'line-width':8,'line-opacity':0.7}});
        map.addLayer({id:'walk-line',type:'line',source:'walk',layout:{'line-cap':'round','line-join':'round'},paint:{'line-color':c.walk,'line-width':4}});
        var b=new maplibregl.LngLatBounds();
        p.walk.forEach(function(pt){b.extend([pt.lng,pt.lat]);});
        map.fitBounds(b,{padding:48,duration:0});
      }
      map.addSource('stations',{type:'geojson',data:fcPoints(p.stations)});
      map.addLayer({id:'stations',type:'circle',source:'stations',paint:{
        'circle-radius':['case',['get','swap'],8,5],
        'circle-color':c.markerFill||'#FFFFFF',
        'circle-stroke-width':3,
        'circle-stroke-color':['case',['get','swap'],c.navy||'#111111',['get','color']]
      }});
      map.addSource('places',{type:'geojson',data:fcPoints((p.places||[]).map(function(x){return {id:x.id,pos:x.pos,color:x.color||c.walk,big:false,swap:false};}))});
      map.addLayer({id:'places',type:'circle',source:'places',paint:{
        'circle-radius':4,'circle-color':['get','color'],'circle-stroke-width':1.2,'circle-stroke-color':c.markerFill||c.bg
      }});
      if(p.user){
        map.addSource('user',{type:'geojson',data:{type:'Feature',geometry:{type:'Point',coordinates:[p.user.lng,p.user.lat]}}});
        map.addLayer({id:'user-halo',type:'circle',source:'user',paint:{'circle-radius':16,'circle-color':'#2E7DF0','circle-opacity':0.22}});
        map.addLayer({id:'user',type:'circle',source:'user',paint:{'circle-radius':7,'circle-color':'#2E7DF0','circle-stroke-width':2,'circle-stroke-color':c.markerFill||'#FFFFFF'}});
      }
      map.on('click','stations',function(e){if(e.features[0])post('station',e.features[0].properties.id);});
      map.on('click','places',function(e){if(e.features[0])post('place',e.features[0].properties.id);});
      map.on('click',function(e){
        var hit=map.queryRenderedFeatures(e.point,{layers:['stations','places']});
        if(hit.length) return;
        if(window.webkit&&window.webkit.messageHandlers.nazlah)window.webkit.messageHandlers.nazlah.postMessage({channel:'map',lat:e.lngLat.lat,lng:e.lngLat.lng});
      });
    }
    function draw(p){
      if(map){map.remove();map=null;}
      document.documentElement.classList.toggle('dark', !!p.dark);
      var c=pal(p);
      c.darkCasing=p.dark?'#1C1C1C':'#D8D2C8';
      map=new maplibregl.Map({
        container:'map',
        style:styleFor(c),
        center:[p.center.lng,p.center.lat],
        zoom:p.zoom||12,
        attributionControl:{compact:true,customAttribution:'© OSM'},
        interactive:p.interactive!==false,
        fadeDuration:0
      });
      map.on('load',function(){addOverlays(p,c);});
    }
    function post(channel,id){if(window.webkit&&window.webkit.messageHandlers.nazlah)window.webkit.messageHandlers.nazlah.postMessage({channel:channel,id:id});}
    window.boot=boot;
    </script></body></html>
    """
}

struct GoogleMetroWebMap: UIViewRepresentable {
    var payload: [String: Any]
    var onStation: (String) -> Void
    var onPlace: (String) -> Void
    var onMapTap: (GeoCoordinate) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "nazlah")
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 247 / 255, green: 245 / 255, blue: 240 / 255, alpha: 1)
        web.scrollView.backgroundColor = web.backgroundColor
        web.scrollView.isScrollEnabled = false
        web.loadHTMLString(GoogleMetroMapHTML.source, baseURL: URL(string: "https://unpkg.com"))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.parent = self
        let dark = (payload["dark"] as? Bool) == true
        web.backgroundColor = dark
            ? UIColor(red: 23 / 255, green: 23 / 255, blue: 23 / 255, alpha: 1)
            : UIColor(red: 247 / 255, green: 245 / 255, blue: 240 / 255, alpha: 1)
        web.scrollView.backgroundColor = web.backgroundColor
        context.coordinator.boot(on: web)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: GoogleMetroWebMap
        var ready = false

        init(_ parent: GoogleMetroWebMap) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            boot(on: webView)
        }

        func boot(on web: WKWebView) {
            guard ready, let data = try? JSONSerialization.data(withJSONObject: parent.payload),
                  let json = String(data: data, encoding: .utf8) else { return }
            web.evaluateJavaScript("boot(\(json));", completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let channel = body["channel"] as? String else { return }
            if channel == "map" {
                let lat = (body["lat"] as? NSNumber)?.doubleValue ?? (body["lat"] as? Double)
                let lng = (body["lng"] as? NSNumber)?.doubleValue ?? (body["lng"] as? Double)
                if let lat, let lng {
                    parent.onMapTap(GeoCoordinate(latitude: lat, longitude: lng))
                }
                return
            }
            guard let id = body["id"] as? String else { return }
            if channel == "station" { parent.onStation(id) }
            if channel == "place" { parent.onPlace(id) }
        }
    }
}

struct MiniMetroMap: View {
    var catalog: MetroCatalog
    var onSelect: (MetroStation) -> Void
    @State private var camera: MapCameraPosition = .region(MetroGeographicLayout.networkRegion)

    var body: some View {
        GeographicMetroMap(
            catalog: catalog,
            selectedLineId: nil,
            selectedStationId: nil,
            language: .arabic,
            interactive: false,
            showsAllStations: false,
            onSelect: onSelect,
            camera: $camera
        )
        .accessibilityLabel("metro.mini.label")
    }
}

struct CompactMetroDiagram: View {
    var catalog: MetroCatalog
    var onSelect: (MetroStation) -> Void
    @State private var camera: MapCameraPosition = .region(MetroGeographicLayout.networkRegion)

    var body: some View {
        GeographicMetroMap(
            catalog: catalog,
            selectedLineId: nil,
            selectedStationId: nil,
            language: .arabic,
            interactive: false,
            showsAllStations: false,
            onSelect: onSelect,
            camera: $camera
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .allowsHitTesting(true)
    }
}

struct MetroPreviewCard: View {
    var catalog: MetroCatalog
    var onSelect: (MetroStation) -> Void
    var onOpenFullMap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("home.selectStation")
                .font(AppTypography.semibold(13))
                .foregroundStyle(.white)
            CompactMetroDiagram(catalog: catalog, onSelect: onSelect)
                .frame(height: 118)
            Button(action: onOpenFullMap) {
                Text("home.fullMap")
                    .font(AppTypography.semibold(13))
                    .foregroundStyle(AppColors.navy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(AppColors.navy)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

struct MetroMapView: View {
    @EnvironmentObject private var session: CatalogSession
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedLineId: String?
    @State private var selectedStationId: String?
    @State private var selectedCategory: PlaceCategory?
    @State private var sheetExpanded = false
    @State private var followUser = false
    @State private var camera: MapCameraPosition = .region(MetroGeographicLayout.networkRegion)

    private var lang: AppLanguage { settings.language }
    private func t(_ key: String) -> String { DalilCopy.t(key, lang) }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            VStack(spacing: AppSpacing.item) {
                VStack(alignment: .leading, spacing: AppSpacing.tight) {
                    searchBar
                    lineChips
                }
                .padding(.horizontal, AppSpacing.screen)
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: AppSpacing.tight) {
                        mapButton("location.fill", t("map.locate")) {
                            Task { await lockToNearestFromGPS() }
                        }
                        Menu {
                            Button(t("map.hidePlaces")) { selectedCategory = nil }
                            ForEach(BrowseCategory.allCases) { browse in
                                Button(DalilCopy.t(browse.copyKey, lang)) {
                                    selectedCategory = browse.placeCategory
                                }
                            }
                        } label: {
                            mapButtonLabel("square.3.layers.3d", t("map.layers"))
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
                if router.isPickingMapLocation {
                    Text(pickHint)
                        .appText(.subhead)
                        .foregroundStyle(AppColors.primaryText)
                        .padding(.horizontal, AppSpacing.item)
                        .padding(.vertical, AppSpacing.tight)
                        .background(AppColors.cardSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.controlBorder, lineWidth: 1))
                        .accessibilityLabel(pickHint)
                }
                sheet
            }
            .padding(.top, 8)
        }
        .background(AppColors.warmBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: saveSheetBinding) {
            if let coordinate = router.pendingSaveCoordinate {
                SaveLocationSheet(mode: .create(coordinate), nearestSummary: session.nearestWalkLabel(lang))
            }
        }
        .task {
            await session.loadCatalog()
            if selectedStationId == nil {
                selectedStationId = session.nearestStation?.id
            }
            if session.rankedPlaces.isEmpty { await session.load() }
            applyAnchorFocusIfNeeded()
        }
        .onChange(of: router.shouldFocusAnchor) { _, focus in
            if focus { applyAnchorFocusIfNeeded() }
        }
        .onChange(of: session.activeTrip) { _, trip in
            if trip != nil {
                followUser = true
                sheetExpanded = true
            }
        }
    }

    private var pickHint: String {
        switch router.mapPickIntent {
        case .home: return t("map.pickHome")
        case .work: return t("map.pickWork")
        case .add: return t("map.pickSaved")
        case .relocate: return t("map.pickMove")
        }
    }

    private var saveSheetBinding: Binding<Bool> {
        Binding(
            get: { router.pendingSaveCoordinate != nil },
            set: { if !$0 { router.pendingSaveCoordinate = nil } }
        )
    }

    private var searchBar: some View {
        SearchField(
            placeholder: t("map.search"),
            text: .constant(""),
            trailingSystemImage: nil,
            trailingAction: nil,
            onActivate: { router.presentSearch() }
        )
        .shadow(color: AppColors.navy.opacity(0.08), radius: 12, y: 4)
    }

    private var lineChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.tight) {
                if let catalog = session.catalog {
                    ForEach(catalog.lines) { line in
                        let on = selectedLineId == line.id
                        Button {
                            selectedLineId = on ? nil : line.id
                            followUser = false
                            if let selectedLineId {
                                camera = .region(MetroGeographicLayout.region(selectedLineId: selectedLineId, catalog: catalog))
                            } else {
                                camera = .region(MetroGeographicLayout.networkRegion)
                            }
                        } label: {
                            LineBadge(line: line.lineColor, style: .pill, language: lang, inverted: on)
                                .padding(.horizontal, AppSpacing.item)
                                .frame(height: AppSize.chip)
                                .background(on ? line.lineColor.color : AppColors.cardSurface)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(on ? Color.clear : AppColors.controlBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            Capsule()
                .fill(AppColors.controlBorder)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
            if let trip = session.activeTrip {
                guidanceSheet(trip)
            } else if let station = sheetStation, let catalog = session.catalog {
                let meters = Int(session.anchor.distanceMeters(to: station.coordinate).rounded())
                let walk = max(1, Int((Double(meters) / 80).rounded()))
                let isNearest = station.id == session.nearestStation?.id
                Button {
                    sheetExpanded.toggle()
                } label: {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(isNearest
                             ? "\(t("map.nearest")): \(station.localizedName(language: lang)) · \(DalilCopy.walkAndDistance(minutes: walk, meters: meters, lang))"
                             : "\(station.localizedName(language: lang)) · \(DalilCopy.walkAndDistance(minutes: walk, meters: meters, lang))")
                            .appText(.headline)
                            .foregroundStyle(AppColors.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: AppSpacing.chip) {
                            ForEach(catalog.lines(for: station)) { line in
                                LineBadge(line: line.lineColor, style: .number, language: lang)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                if let row = MetroDepartureClock.rows(station: station, catalog: catalog, language: lang).first {
                    DepartureRow(direction: row.direction, minutes: row.minutes, language: lang)
                }
                if sheetExpanded {
                    Button(t("home.details")) { router.open(.station(station.id)) }
                        .appText(.headline)
                        .foregroundStyle(AppColors.primaryText)
                    if session.usedUserLocation {
                        Button(t("saved.saveTitle")) {
                            router.pendingSaveCoordinate = session.anchor
                        }
                        .appText(.headline)
                        .foregroundStyle(AppColors.primaryText)
                    }
                }
            }
        }
        .padding(AppSpacing.item)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .background(.ultraThinMaterial)
        .background(AppColors.cardSurface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, AppSpacing.tight)
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
    }

    private var sheetStation: MetroStation? {
        if let id = selectedStationId, let station = session.catalog?.station(id: id) { return station }
        return session.nearestStation
    }

    private var mapCanvas: some View {
        Group {
            if let catalog = session.catalog {
                GeographicMetroMap(
                    catalog: catalog,
                    selectedLineId: selectedLineId,
                    selectedStationId: selectedStationId ?? session.nearestStation?.id,
                    language: lang,
                    interactive: true,
                    showsAllStations: true,
                    searchText: "",
                    places: visiblePlaces,
                    followCoordinate: (followUser || session.activeTrip != nil) ? session.anchor : nil,
                    userCoordinate: (session.usedUserLocation || session.activeTrip != nil) ? session.anchor : nil,
                    onSelect: { station in
                        selectedStationId = station.id
                        sheetExpanded = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    },
                    onPlace: { router.open(.place($0)) },
                    onMapTap: { coordinate in
                        guard router.isPickingMapLocation else { return }
                        applyPickedLocation(coordinate)
                    },
                    camera: $camera
                )
            } else {
                AppColors.warmBackground
            }
        }
    }

    private var visiblePlaces: [GoogleMapPlacePin] {
        guard let selectedCategory else { return [] }
        return session.rankedPlaces
            .filter { $0.place.category == selectedCategory }
            .prefix(40)
            .map {
                GoogleMapPlacePin(
                    id: $0.place.id,
                    name: $0.place.localizedName(language: lang),
                    latitude: $0.place.latitude,
                    longitude: $0.place.longitude,
                    color: PlaceCategory.pinHex($0.place.category)
                )
            }
    }

    private func applyPickedLocation(_ coordinate: GeoCoordinate) {
        session.setAnchor(coordinate)
        followUser = true
        selectedLineId = nil
        selectedStationId = session.nearestStation?.id
        sheetExpanded = true
        router.isPickingMapLocation = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch router.mapPickIntent {
        case .home:
            settings.saveSlot(.home, at: coordinate)
        case .work:
            settings.saveSlot(.work, at: coordinate)
        case .relocate(let id):
            settings.relocateSavedLocation(id: id, to: coordinate)
        case .add:
            router.pendingSaveCoordinate = coordinate
        }
        router.mapPickIntent = .add
    }

    private func guidanceSheet(_ trip: ActiveTrip) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            Text(trip.title)
                .appText(.headline)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(1)
            if trip.isComplete {
                Text(t("trip.arrived"))
                    .appText(.title)
                    .foregroundStyle(AppColors.primaryText)
            } else if let waypoint = trip.currentWaypoint {
                Text(t("trip.next"))
                    .appText(.caption)
                    .foregroundStyle(AppColors.secondaryText)
                Text(waypoint.action)
                    .appText(.title)
                    .foregroundStyle(AppColors.primaryText)
                    .lineLimit(2)
                Text(waypoint.label)
                    .appText(.subhead)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
            }
            Button(t("trip.end")) { session.endGuidance() }
                .appText(.headline)
                .foregroundStyle(AppColors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func applyAnchorFocusIfNeeded() {
        guard router.shouldFocusAnchor || session.usedUserLocation || session.activeTrip != nil else { return }
        followUser = true
        selectedStationId = session.nearestStation?.id
        sheetExpanded = true
        router.shouldFocusAnchor = false
    }

    private func lockToNearestFromGPS() async {
        await session.useNearMe()
        followUser = session.usedUserLocation
        selectedLineId = nil
        selectedStationId = session.nearestStation?.id
        sheetExpanded = true
        if session.usedUserLocation {
            router.isPickingMapLocation = false
        }
    }

    private func mapButton(_ system: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            mapButtonLabel(system, label)
        }
        .buttonStyle(.plain)
    }

    private func mapButtonLabel(_ system: String, _ label: String) -> some View {
        Image(systemName: system)
            .font(.system(size: AppTextStyle.body.size, weight: .semibold))
            .foregroundStyle(AppColors.primaryText)
            .frame(width: AppSize.touch, height: AppSize.touch)
            .background(AppColors.cardSurface)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppColors.controlBorder, lineWidth: 1))
            .accessibilityLabel(label)
    }
}

