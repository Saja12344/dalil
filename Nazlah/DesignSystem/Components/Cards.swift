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

/// The home "station sign": your Sahm arrow + the station name on the line's color,
/// then one row per direction with its own arrow, like a platform sign.
struct HomeStationHero: View {
    var station: MetroStation
    var lines: [MetroLine]
    var walkMinutes: Int
    var walkMeters: Int
    var rows: [(direction: String, minutes: [Int])]
    var language: AppLanguage
    var onOpen: () -> Void

    private var primary: LineColor { lines.first?.lineColor ?? .blue }
    private var signInk: Color { primary.onChip }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                signHead
                MetroStripes(lines: lines.map(\.lineColor))
                VStack(spacing: 0) {
                    ForEach(Array(rows.prefix(2).enumerated()), id: \.offset) { index, row in
                        if index > 0 {
                            AppColors.divider.frame(height: 1)
                        }
                        directionRow(row, pointing: index == 0 ? .trailing : .leading)
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
        HStack(alignment: .top, spacing: AppSpacing.item) {
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
                            .overlay(Capsule().stroke(signInk.opacity(0.55), lineWidth: 1))
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
                    .foregroundStyle(signInk.opacity(0.85))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SahmArrow(pointing: .forward, color: signInk)
                .frame(width: 64, height: 64)
        }
        .padding(AppSpacing.screen)
        .background(primary.chipColor)
    }

    private func directionRow(_ row: (direction: String, minutes: [Int]), pointing: SahmArrow.Pointing) -> some View {
        HStack(spacing: AppSpacing.item) {
            SahmArrow(pointing: pointing, color: primary.color)
                .frame(width: 26, height: 26)
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

/// Dalil's Sahm arrow (the hand-drawn arrow mark). `.forward` keeps the drawn up-and-ahead
/// angle; `.leading` / `.trailing` lay it flat. All three mirror in Arabic.
struct SahmArrow: View {
    enum Pointing {
        case forward
        case leading
        case trailing
    }

    var pointing: Pointing = .forward
    var color: Color = AppColors.accent

    var body: some View {
        Image("SahmMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .rotationEffect(.degrees(pointing == .forward ? 0 : 68))
            .scaleEffect(x: pointing == .leading ? -1 : 1, y: 1)
            .flipsForRightToLeftLayoutDirection(true)
            .accessibilityHidden(true)
    }
}

/// Thin parallel metro-line stripes (the Music OS line motif, kept light).
struct MetroStripes: View {
    var lines: [LineColor]
    var stripe: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array((lines.isEmpty ? [LineColor.blue] : lines).enumerated()), id: \.offset) { _, line in
                line.color.frame(height: stripe)
            }
        }
        .accessibilityHidden(true)
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
