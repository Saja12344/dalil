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

struct HomeStationHero: View {
    var station: MetroStation
    var lines: [MetroLine]
    var walkMinutes: Int
    var walkMeters: Int
    var rows: [(direction: String, minutes: [Int])]
    var language: AppLanguage
    var onOpen: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                lineBar
                HStack(alignment: .top, spacing: AppSpacing.item) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(station.localizedName(language: language))
                            .appText(.title)
                            .foregroundStyle(ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(verbatim: DalilCopy.walkAndDistance(minutes: walkMinutes, meters: walkMeters, language))
                            .appText(.body)
                            .foregroundStyle(muted)
                        if let first = rows.first {
                            Text(verbatim: DalilCopy.toward(first.direction, language))
                                .appText(.body)
                                .foregroundStyle(muted)
                                .lineLimit(1)
                        }
                        ForEach(Array(rows.dropFirst().enumerated()), id: \.offset) { _, row in
                            secondaryDeparture(row)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let first = rows.first, let minutes = first.minutes.first {
                        countdown(minutes: minutes, following: first.minutes)
                    }
                }
                .padding(AppSpacing.screen)
            }
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(DalilCopy.t("home.details", language))
    }

    private var fill: Color {
        colorScheme == .dark ? AppColors.cream : AppColors.navy
    }

    private var ink: Color {
        colorScheme == .dark ? AppColors.navy : AppColors.cream
    }

    private var muted: Color {
        ink.opacity(0.64)
    }

    private var lineBar: some View {
        HStack(spacing: 0) {
            ForEach(lines) { line in
                Rectangle()
                    .fill(line.lineColor.color)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: AppSpacing.tight)
        .accessibilityHidden(true)
    }

    private func countdown(minutes: Int, following: [Int]) -> some View {
        let then = DalilCopy.thenMinutes(following, language)
        return VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
            Text(verbatim: DalilCopy.shortMinutes(minutes, language))
                .font(AppTypography.extraBold(AppTextStyle.largeTitle.size))
                .monospacedDigit()
                .foregroundStyle(ink)
            if !then.isEmpty {
                Text(verbatim: then)
                    .appLiveNumber(.body)
                    .foregroundStyle(muted)
            }
            Text(DalilCopy.t("home.details", language))
                .appText(.caption)
                .foregroundStyle(muted)
        }
    }

    private func secondaryDeparture(_ row: (direction: String, minutes: [Int])) -> some View {
        let time = row.minutes.first.map { DalilCopy.shortMinutes($0, language) } ?? ""
        return Text(verbatim: [DalilCopy.toward(row.direction, language), time].filter { !$0.isEmpty }.joined(separator: " · "))
            .appText(.subhead)
            .foregroundStyle(muted)
            .lineLimit(1)
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
