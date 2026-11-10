import SwiftUI

struct PlaceCard: View {
    var ranked: RankedPlace
    var language: AppLanguage
    var lines: [MetroLine]
    var isSaved: Bool = false
    var showsExit: Bool = true
    var onSave: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.item) {
            thumb
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(ranked.place.localizedName(language: language))
                    .appText(.headline)
                    .foregroundStyle(AppColors.primaryText)
                    .lineLimit(2)
                Text(accessLine)
                    .appText(.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
                HStack(spacing: AppSpacing.tight) {
                    Text(DalilCopy.t(categoryKey, language))
                        .appText(.subhead)
                        .foregroundStyle(AppColors.secondaryText)
                    LineDots(lines: lines)
                }
            }
            Spacer(minLength: AppSpacing.tight)
            if let onSave {
                Button(action: onSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: AppTextStyle.body.size, weight: .semibold))
                        .foregroundStyle(isSaved ? AppColors.mint : AppColors.secondaryText)
                        .frame(width: AppSize.touch, height: AppSize.touch)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(DalilCopy.t("place.save", language))
            }
            Image(systemName: "chevron.left")
                .font(.system(size: AppTextStyle.caption.size, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(AppSpacing.item)
        .background(AppColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            }
        }
        .accessibilityElement(children: onSave == nil ? .combine : .contain)
        .accessibilityLabel(
            [
                ranked.place.localizedName(language: language),
                DalilCopy.t(categoryKey, language),
                accessLine
            ].joined(separator: ", ")
        )
    }

    private var accessLine: String {
        DalilCopy.accessLine(
            exit: showsExit ? ranked.access.exit?.exitNumber : nil,
            minutes: ranked.access.displayedMinutes,
            meters: Int(ranked.access.displayedMeters.rounded()),
            language
        )
    }

    private var categoryKey: String {
        switch ranked.place.category {
        case .cafe: return "cat.cafe"
        case .restaurant: return "cat.restaurant"
        case .dessert: return "cat.dessert"
        case .park, .viewpoint: return "cat.nature"
        case .gym: return "cat.gym"
        case .pharmacy: return "cat.pharmacy"
        default: return "cat.place"
        }
    }

    private var thumb: some View {
        PlacePhotoView(place: ranked.place, glyph: glyphName)
            .frame(width: AppSize.thumb, height: AppSize.thumb)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.item, style: .continuous))
    }

    private var glyphName: String {
        switch ranked.place.category {
        case .cafe, .cowork: return "cup.and.saucer.fill"
        case .restaurant, .dessert: return "fork.knife"
        case .park, .viewpoint: return "leaf.fill"
        case .gym: return "figure.strengthtraining.traditional"
        case .pharmacy: return "cross.case.fill"
        default: return "mappin.and.ellipse"
        }
    }
}

struct StationCard: View {
    var station: MetroStation
    var lines: [MetroLine]
    var placeCount: Int
    var language: AppLanguage
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(station.localizedName(language: language))
                        .appText(.headline)
                        .foregroundStyle(AppColors.primaryText)
                        .lineLimit(2)
                    Text(station.hasVerifiedExits ? "station.exits.ready" : "station.exits.updating.short")
                        .appText(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
                Spacer()
                Text("\(placeCount)")
                    .appLiveNumber(.subhead)
                    .foregroundStyle(AppColors.mintInk)
                    .padding(AppSpacing.tight)
                    .background(AppColors.mint.opacity(0.15))
                    .clipShape(Circle())
                    .accessibilityLabel(Text("station.placesCount \(placeCount)"))
            }
            LineDots(lines: lines)
        }
        .padding(AppSpacing.screen)
        .background(AppColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            }
        }
    }
}

/// The home station sign, Music OS style: the real metro line drawn around the station
/// (true angle and direction from the station coordinates), then one row per direction.
struct HomeStationHero: View {
    var station: MetroStation
    var lines: [MetroLine]
    var routes: StationRoutes
    var walkMinutes: Int
    var walkMeters: Int
    var rows: [(direction: String, minutes: [Int])]
    var language: AppLanguage
    var onOpen: () -> Void

    private var primary: LineColor { lines.first?.lineColor ?? .blue }
    private let signInk = AppColors.cream
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                signHead
                VStack(spacing: 0) {
                    ForEach(Array(rows.prefix(2).enumerated()), id: \.offset) { index, row in
                        if index > 0 {
                            AppColors.divider.frame(height: 1)
                        }
                        directionRow(row)
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
                .background(AppColors.cardSurface)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(DalilCopy.t("home.details", language))
    }

    private var signHead: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            HStack(spacing: AppSpacing.chip) {
                ForEach(lines) { line in
                    Text(line.lineColor.code)
                        .font(AppTypography.bold(13))
                        .foregroundStyle(line.lineColor.onChip)
                        .padding(.horizontal, AppSpacing.tight)
                        .frame(height: 22)
                        .background(line.lineColor.chipColor)
                        .clipShape(Capsule())
                }
            }
            Text(station.localizedName(language: language))
                .font(AppTypography.extraBold(30))
                .foregroundStyle(signInk)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
            Text(verbatim: DalilCopy.walkAndDistance(minutes: walkMinutes, meters: walkMeters, language))
                .appText(.subhead)
                .foregroundStyle(signInk.opacity(0.75))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .padding(AppSpacing.screen)
        .background {
            StationLineMap(
                routes: routes,
                stationFill: signInk,
                ink: AppColors.night,
                anchor: UnitPoint(x: layoutDirection == .rightToLeft ? 0.26 : 0.74, y: 0.55)
            )
        }
        .background(AppColors.night)
    }

    private func directionRow(_ row: (direction: String, minutes: [Int])) -> some View {
        HStack(spacing: AppSpacing.item) {
            Circle()
                .fill(primary.color)
                .frame(width: 12, height: 12)
            Text(verbatim: DalilCopy.toward(row.direction, language))
                .appText(.headline)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let next = row.minutes.first {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: DalilCopy.shortMinutes(next, language))
                        .font(AppTypography.extraBold(22))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.primaryText)
                    let then = DalilCopy.thenMinutes(row.minutes, language)
                    if !then.isEmpty {
                        Text(verbatim: then)
                            .appLiveNumber(.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
        }
        .padding(.vertical, AppSpacing.item)
    }
}

/// Each line through a station, as points in meters around it (x east, y south).
/// Ends that are not a real terminus are extended so the line runs off the edge
/// instead of stopping mid-card.
struct StationRoutes {
    struct Route {
        var line: LineColor
        var points: [CGPoint]
        var neighbors: [CGPoint]
    }

    var routes: [Route]
    /// Meters from the station to the edge of the drawing's short side.
    var radius: Double

    init(station: MetroStation, catalog: MetroCatalog) {
        let lat0 = station.latitude
        let lon0 = station.longitude
        let metersPerLon = 111_320 * cos(lat0 * .pi / 180)
        func local(_ stop: MetroStation) -> CGPoint {
            CGPoint(
                x: (stop.longitude - lon0) * metersPerLon,
                y: -(stop.latitude - lat0) * 110_540
            )
        }

        var found: [(line: MetroLine, stops: [MetroStation], index: Int)] = []
        var nearest: [Double] = []
        for line in catalog.lines(for: station) {
            let stops = catalog.stations(on: line.id)
            guard let index = stops.firstIndex(where: { $0.id == station.id }), stops.count > 1 else { continue }
            found.append((line, stops, index))
            for offset in [-1, 1] where stops.indices.contains(index + offset) {
                let p = local(stops[index + offset])
                nearest.append(Double(hypot(p.x, p.y)))
            }
        }
        let radius = min(max((nearest.min() ?? 1_200) * 1.25, 600), 2_500)
        self.radius = radius

        func extend(_ from: CGPoint, away other: CGPoint) -> CGPoint {
            let dx = from.x - other.x
            let dy = from.y - other.y
            let length = max(hypot(dx, dy), 1)
            let reach = CGFloat(radius * 4)
            return CGPoint(x: from.x + dx / length * reach, y: from.y + dy / length * reach)
        }

        self.routes = found.map { item in
            let lower = max(0, item.index - 5)
            let upper = min(item.stops.count - 1, item.index + 5)
            let window = Array(item.stops[lower...upper])
            var points = window.map(local)
            if lower > 0, points.count > 1 {
                points.insert(extend(points[0], away: points[1]), at: 0)
            }
            if upper < item.stops.count - 1, points.count > 1 {
                points.append(extend(points[points.count - 1], away: points[points.count - 2]))
            }
            let neighbors = window.filter { $0.id != station.id }.map(local)
            return Route(line: item.line.lineColor, points: points, neighbors: neighbors)
        }
    }
}

/// Draws the station's lines at their real angle; the line draws itself in,
/// then neighbor stations and the station dot appear.
/// `anchor` places the station inside the frame (left-to-right coordinates).
struct StationLineMap: View {
    var routes: StationRoutes
    var stationFill: Color
    var ink: Color
    var anchor: UnitPoint = .center
    var lineWidth: CGFloat = 9

    @State private var progress: CGFloat = 0
    @State private var settled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let scale = (min(geo.size.width, geo.size.height) / 2) / CGFloat(routes.radius)
            let center = CGPoint(x: geo.size.width * anchor.x, y: geo.size.height * anchor.y)
            ZStack {
                ForEach(Array(routes.routes.enumerated()), id: \.offset) { _, route in
                    ProjectedPolyline(points: route.points, scale: scale, center: center)
                        .trim(from: 0, to: progress)
                        .stroke(route.line.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    ForEach(Array(route.neighbors.enumerated()), id: \.offset) { _, stop in
                        Circle()
                            .fill(stationFill)
                            .frame(width: lineWidth * 0.55, height: lineWidth * 0.55)
                            .position(x: center.x + stop.x * scale, y: center.y + stop.y * scale)
                            .opacity(settled ? 1 : 0)
                    }
                }
                Circle()
                    .fill(stationFill)
                    .overlay(Circle().stroke(ink, lineWidth: 3))
                    .frame(width: lineWidth * 2.2, height: lineWidth * 2.2)
                    .scaleEffect(settled ? 1 : 0.1)
                    .position(center)
            }
        }
        .clipped()
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
        .onAppear {
            guard progress == 0 else { return }
            if reduceMotion {
                progress = 1
                settled = true
                return
            }
            withAnimation(.easeInOut(duration: 1.4)) { progress = 1 }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7).delay(1.1)) { settled = true }
        }
    }
}

private struct ProjectedPolyline: Shape {
    var points: [CGPoint]
    var scale: CGFloat
    var center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            let projected = CGPoint(x: center.x + point.x * scale, y: center.y + point.y * scale)
            if index == 0 {
                path.move(to: projected)
            } else {
                path.addLine(to: projected)
            }
        }
        return path
    }
}

struct PlacePosterCard: View {
    var ranked: RankedPlace
    var language: AppLanguage

    private let width: CGFloat = AppSpacing.xxl * 3 + AppSpacing.item
    private let photoHeight: CGFloat = AppSpacing.xxl * 2

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            PlacePhotoView(place: ranked.place, glyph: ranked.place.category.symbolName)
                .frame(width: width, height: photoHeight)
                .background(AppColors.categoryTint(ranked.place.category))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            Text(ranked.place.localizedName(language: language))
                .appText(.headline)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: width, alignment: .leading)
            Text(verbatim: DalilCopy.walkFromStation(
                minutes: ranked.access.displayedMinutes,
                station: ranked.access.station.localizedName(language: language),
                language
            ))
            .appText(.caption)
            .foregroundStyle(AppColors.secondaryText)
            .lineLimit(2)
            .frame(width: width, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
