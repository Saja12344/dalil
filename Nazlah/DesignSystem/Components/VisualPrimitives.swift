import SwiftUI

struct PlacePlaceholderArt: View {
    var category: PlaceCategory

    var body: some View {
        ZStack {
            AppColors.warmBackground
            Canvas { context, size in
                let color = AppColors.navy.opacity(0.55)
                let stroke = StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                switch category {
                case .cafe, .cowork:
                    var cup = Path()
                    cup.addRoundedRect(in: CGRect(x: size.width * 0.38, y: size.height * 0.38, width: size.width * 0.24, height: size.height * 0.28), cornerSize: CGSize(width: 6, height: 6))
                    var handle = Path()
                    handle.addArc(center: CGPoint(x: size.width * 0.64, y: size.height * 0.50), radius: size.width * 0.06, startAngle: .degrees(-70), endAngle: .degrees(70), clockwise: false)
                    var steam = Path()
                    steam.move(to: CGPoint(x: size.width * 0.46, y: size.height * 0.34))
                    steam.addQuadCurve(to: CGPoint(x: size.width * 0.46, y: size.height * 0.22), control: CGPoint(x: size.width * 0.42, y: size.height * 0.28))
                    context.stroke(cup, with: .color(color), style: stroke)
                    context.stroke(handle, with: .color(color), style: stroke)
                    context.stroke(steam, with: .color(color), style: stroke)
                case .restaurant, .dessert:
                    var plate = Path()
                    plate.addEllipse(in: CGRect(x: size.width * 0.32, y: size.height * 0.46, width: size.width * 0.36, height: size.height * 0.16))
                    var fork = Path()
                    fork.move(to: CGPoint(x: size.width * 0.40, y: size.height * 0.32))
                    fork.addLine(to: CGPoint(x: size.width * 0.40, y: size.height * 0.58))
                    context.stroke(plate, with: .color(color), style: stroke)
                    context.stroke(fork, with: .color(color), style: stroke)
                case .park, .viewpoint:
                    var canopy = Path()
                    canopy.addEllipse(in: CGRect(x: size.width * 0.36, y: size.height * 0.28, width: size.width * 0.28, height: size.height * 0.28))
                    var trunk = Path()
                    trunk.move(to: CGPoint(x: size.width * 0.50, y: size.height * 0.54))
                    trunk.addLine(to: CGPoint(x: size.width * 0.50, y: size.height * 0.72))
                    context.stroke(canopy, with: .color(color), style: stroke)
                    context.stroke(trunk, with: .color(color), style: stroke)
                default:
                    var pin = Path()
                    pin.addEllipse(in: CGRect(x: size.width * 0.44, y: size.height * 0.32, width: size.width * 0.12, height: size.width * 0.12))
                    pin.move(to: CGPoint(x: size.width * 0.50, y: size.height * 0.44))
                    pin.addLine(to: CGPoint(x: size.width * 0.50, y: size.height * 0.62))
                    context.stroke(pin, with: .color(color), style: stroke)
                }
            }
        }
        .clipped()
    }
}

struct LineDots: View {
    var lines: [MetroLine]

    var body: some View {
        HStack(spacing: AppSpacing.chip) {
            ForEach(lines.prefix(4)) { line in
                Circle()
                    .fill(line.lineColor.color)
                    .frame(width: AppSpacing.tight, height: AppSpacing.tight)
                    .accessibilityLabel("\(line.lineColor.code) \(line.localizedName(language: .arabic))")
            }
        }
    }
}

struct WalkingAccessMeta: View {
    var access: AccessSummary
    var language: AppLanguage

    var body: some View {
        Text(
            DalilCopy.accessLine(
                exit: access.exit?.exitNumber,
                minutes: access.displayedMinutes,
                meters: Int(access.displayedMeters.rounded()),
                language
            )
        )
        .appText(.caption)
        .foregroundStyle(AppColors.secondaryText)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

struct WalkingAccessBadge: View {
    var access: AccessSummary
    var language: AppLanguage

    var body: some View {
        WalkingAccessMeta(access: access, language: language)
            .padding(.horizontal, AppSpacing.item)
            .padding(.vertical, AppSpacing.tight)
            .background(AppColors.softSand)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous))
    }
}

struct LinePill: View {
    @EnvironmentObject private var settings: AppSettings
    var line: MetroLine
    var compact: Bool = false

    var body: some View {
        HStack(spacing: AppSpacing.chip) {
            Circle()
                .fill(line.lineColor.color)
                .frame(width: AppSpacing.tight, height: AppSpacing.tight)
            if !compact {
                Text("\(line.lineColor.number) \(line.localizedName(language: settings.language))")
                    .appText(.caption)
                    .foregroundStyle(AppColors.primaryText)
            }
        }
        .accessibilityLabel("\(line.lineColor.code) \(line.localizedName(language: settings.language))")
    }
}

enum PlaceCover {
    static func url(for place: Place) -> URL? {
        if let raw = place.imageURLs.first, let url = URL(string: raw), url.scheme?.hasPrefix("http") == true {
            return url
        }
        return nil
    }
}

struct PlacePhotoView: View {
    var place: Place
    var glyph: String = "mappin.and.ellipse"
    @State private var remote: URL?

    var body: some View {
        ZStack {
            glyphView
            if let url = remote ?? PlaceCover.url(for: place) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .task {
            remote = await PlacePhotoStore.shared.url(for: place)
        }
    }

    private var glyphView: some View {
        GeometryReader { geo in
            Image(systemName: glyph)
                .font(.system(size: max(AppTextStyle.body.size, min(geo.size.width, geo.size.height) * 0.28), weight: .semibold))
                .foregroundStyle(AppColors.categoryInk(place.category))
                .frame(width: geo.size.width, height: geo.size.height)
                .background(AppColors.categoryTint(place.category))
        }
    }
}

actor PlacePhotoStore {
    static let shared = PlacePhotoStore()

    private var cache: [String: URL] = [:]
    private var misses: Set<String> = []

    func url(for place: Place) async -> URL? {
        if let bundled = PlaceCover.url(for: place) { return bundled }
        if let cached = cache[place.id] { return cached }
        if misses.contains(place.id) { return nil }
        if let fetched = await fetch(place) {
            cache[place.id] = fetched
            return fetched
        }
        misses.insert(place.id)
        return nil
    }

    private func fetch(_ place: Place) async -> URL? {
        if let wiki = await wikipediaThumb(query: "\(place.nameEn) Riyadh") { return wiki }
        if place.languageLooksArabic, let wiki = await wikipediaThumb(query: "\(place.nameAr) الرياض") {
            return wiki
        }
        return await nominatimImage(place)
    }

    private func wikipediaThumb(query: String) async -> URL? {
        var parts = URLComponents(string: "https://en.wikipedia.org/w/api.php")
        parts?.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "generator", value: "search"),
            .init(name: "gsrsearch", value: query),
            .init(name: "gsrlimit", value: "3"),
            .init(name: "prop", value: "pageimages"),
            .init(name: "piprop", value: "thumbnail"),
            .init(name: "pithumbsize", value: "800"),
            .init(name: "format", value: "json")
        ]
        guard let url = parts?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("Dalil/1.0 (riyadh metro guide)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(WikiQuery.self, from: data) else {
            return nil
        }
        let pages = decoded.query?.pages?.values.sorted { ($0.index ?? 99) < ($1.index ?? 99) } ?? []
        for page in pages {
            let title = page.title.lowercased()
            if title.contains("list of") || title.contains("location") { continue }
            if let raw = page.thumbnail?.source, let thumb = URL(string: raw),
               !raw.lowercased().contains("location") {
                return thumb
            }
        }
        return nil
    }

    private func nominatimImage(_ place: Place) async -> URL? {
        guard let osm = osmLookupID(place.id) else { return nil }
        var parts = URLComponents(string: "https://nominatim.openstreetmap.org/lookup")
        parts?.queryItems = [
            .init(name: "osm_ids", value: osm),
            .init(name: "format", value: "json"),
            .init(name: "extratags", value: "1")
        ]
        guard let url = parts?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("Dalil/1.0 (riyadh metro guide)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let rows = try? JSONDecoder().decode([NominatimRow].self, from: data),
              let tags = rows.first?.extratags else { return nil }
        if let image = tags["image"], let url = URL(string: image), url.scheme?.hasPrefix("http") == true {
            return url
        }
        if let commons = tags["wikimedia_commons"] {
            let file = commons.replacingOccurrences(of: "File:", with: "")
            let encoded = file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file
            return URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/\(encoded)?width=800")
        }
        if let wikipedia = tags["wikipedia"] {
            let title = wikipedia.split(separator: ":").last.map(String.init) ?? wikipedia
            return await wikipediaThumb(query: title)
        }
        return nil
    }

    private func osmLookupID(_ id: String) -> String? {
        if id.hasPrefix("osm-node-") { return "N" + id.replacingOccurrences(of: "osm-node-", with: "") }
        if id.hasPrefix("osm-way-") { return "W" + id.replacingOccurrences(of: "osm-way-", with: "") }
        if id.hasPrefix("osm-relation-") { return "R" + id.replacingOccurrences(of: "osm-relation-", with: "") }
        return nil
    }

    private struct WikiQuery: Decodable {
        var query: WikiPages?
    }

    private struct WikiPages: Decodable {
        var pages: [String: WikiPage]?
    }

    private struct WikiPage: Decodable {
        var title: String
        var index: Int?
        var thumbnail: WikiThumb?
    }

    private struct WikiThumb: Decodable {
        var source: String
    }

    private struct NominatimRow: Decodable {
        var extratags: [String: String]?
    }
}

private extension Place {
    var languageLooksArabic: Bool {
        nameEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
