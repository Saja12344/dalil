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

/// The home station card: a thick metro band (the line's real heading, snapped to
/// 0/45/90°) running off the edge, the station name, then a cream "trains from here" panel.
struct HomeStationHero: View {
    var station: MetroStation
    var lines: [MetroLine]
    var routes: StationRoutes
    var walkMinutes: Int
    var walkMeters: Int
    var rows: [(direction: String, minutes: [Int])]
    var language: AppLanguage
    var onOpen: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private var primary: LineColor { lines.first?.lineColor ?? .blue }
    private let panel = Color(light: "EFEBE4", dark: "ECE6DB")
    private let panelInk = Color(hex: "111111")

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    MetroBand(
                        lines: routes.routes.isEmpty ? [primary] : routes.routes.map(\.line),
                        heading: routes.routes.first?.heading ?? CGVector(dx: 1, dy: -1),
                        horizontalToRight: layoutDirection == .rightToLeft
                    )
                    .frame(height: 116)
                    Text(DalilCopy.t("home.nearestShort", language))
                        .appText(.subhead)
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.top, AppSpacing.screen + AppSpacing.xxs)
                        .padding(.horizontal, AppSpacing.screen + AppSpacing.xxs)
                }
                VStack(alignment: .leading, spacing: AppSpacing.tight) {
                    Text(station.localizedName(language: language))
                        .font(AppTypography.extraBold(40))
                        .foregroundStyle(AppColors.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.leading)
                    Text(verbatim: DalilCopy.walkAndDistance(minutes: walkMinutes, meters: walkMeters, language))
                        .appText(.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(1)
                }
                .padding(.horizontal, AppSpacing.screen + AppSpacing.xxs)
                .padding(.top, AppSpacing.tight)
                trainsPanel
                    .padding(AppSpacing.screen + AppSpacing.xxs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(DalilCopy.t("home.details", language))
    }

    private var trainsPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            Text(DalilCopy.t("home.trainsHere", language))
                .appText(.subhead)
                .foregroundStyle(panelInk.opacity(0.6))
            ForEach(Array(rows.prefix(2).enumerated()), id: \.offset) { _, row in
                HStack(spacing: AppSpacing.item) {
                    Circle()
                        .fill(primary.color)
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                    Text(verbatim: DalilCopy.toward(row.direction, language))
                        .font(AppTypography.semibold(20))
                        .foregroundStyle(panelInk)
                        .lineLimit(1)
                }
            }
        }
        .padding(AppSpacing.screen + AppSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// Thick metro-map band: a straight run off one edge, one bend, then the line's
/// heading snapped to 0/45/90° off the top. Extra lines run parallel below.
struct MetroBand: View {
    var lines: [LineColor]
    var heading: CGVector
    var horizontalToRight: Bool
    var thickness: CGFloat = 28

    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(Array(lines.prefix(3).enumerated()), id: \.offset) { index, line in
                MetroBandShape(
                    angle: snappedAngle,
                    toRight: horizontalToRight,
                    drop: CGFloat(index) * (thickness + 6),
                    thickness: thickness
                )
                .trim(from: 0, to: progress)
                .stroke(line.color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt, lineJoin: .round))
            }
        }
        .clipped()
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
        .onAppear {
            guard progress == 0 else { return }
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(.easeInOut(duration: 1.1)) { progress = 1 }
            }
        }
    }

    /// Degrees above horizontal for the rising part: 0, 45 or 90.
    private var snappedAngle: Double {
        let degrees = abs(atan2(Double(abs(heading.dy)), Double(abs(heading.dx))) * 180 / .pi)
        if degrees < 22.5 { return 0 }
        if degrees < 67.5 { return 45 }
        return 90
    }
}

private struct MetroBandShape: Shape {
    var angle: Double
    var toRight: Bool
    var drop: CGFloat
    var thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        let y = rect.height * 0.62 + drop
        let bendX = rect.width * (toRight ? 0.46 : 0.54) + (toRight ? -1 : 1) * drop * 0.41
        let reach = rect.width + rect.height
        let straightEnd = CGPoint(x: toRight ? rect.maxX + thickness : rect.minX - thickness, y: y)
        let bend = CGPoint(x: bendX, y: y)
        let radians = angle * .pi / 180
        let away: CGFloat = toRight ? -1 : 1
        let far = CGPoint(
            x: bend.x + away * CGFloat(cos(radians)) * reach,
            y: bend.y - CGFloat(sin(radians)) * reach
        )
        var path = Path()
        path.move(to: straightEnd)
        path.addLine(to: bend)
        path.addLine(to: far)
        return path
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
        /// Previous stop to next stop, screen axes (x east, y south).
        var heading: CGVector
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
            let before = local(item.stops[max(0, item.index - 1)])
            let after = local(item.stops[min(item.stops.count - 1, item.index + 1)])
            let heading = CGVector(dx: after.x - before.x, dy: after.y - before.y)
            return Route(line: item.line.lineColor, points: points, neighbors: neighbors, heading: heading)
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
