import SwiftUI

enum LineBadgeStyle {
    case dot
    case pill
    case number
}

struct LineBadge: View {
    var line: LineColor
    var style: LineBadgeStyle = .pill
    var language: AppLanguage = .arabic
    var inverted: Bool = false

    var body: some View {
        switch style {
        case .dot:
            Circle()
                .fill(line.color)
                .frame(width: AppSpacing.tight, height: AppSpacing.tight)
                .accessibilityLabel(accessibilityName)
        case .pill:
            HStack(spacing: AppSpacing.chip) {
                Circle().fill(inverted ? AppColors.onFill(line) : line.color).frame(width: AppSpacing.tight, height: AppSpacing.tight)
                Text(line.localizedName(language: language))
                    .appText(.subhead)
                    .foregroundStyle(inverted ? AppColors.onFill(line) : AppColors.primaryText)
                    .lineLimit(1)
            }
            .accessibilityLabel(accessibilityName)
        case .number:
            Text(line.number)
                .appText(.subhead)
                .foregroundStyle(AppColors.onFill(line))
                .frame(width: AppSpacing.xl, height: AppSpacing.xl)
                .background(line.color)
                .clipShape(Circle())
                .accessibilityLabel(accessibilityName)
        }
    }

    private var accessibilityName: String {
        "\(line.code) \(line.localizedName(language: language))"
    }
}

struct StationMarker: View {
    var lines: [LineColor]
    var isInterchange: Bool

    private var ring: Color {
        isInterchange ? AppColors.navy : (lines.first?.color ?? AppColors.navy)
    }

    var body: some View {
        Circle()
            .fill(AppColors.cardSurface)
            .frame(width: isInterchange ? 20 : 14, height: isInterchange ? 20 : 14)
            .overlay(
                Circle().stroke(ring, lineWidth: 3)
            )
            .accessibilityLabel(isInterchange ? lines.map(\.code).joined(separator: " ") : (lines.first?.code ?? ""))
    }
}

struct DepartureRow: View {
    var direction: String
    var minutes: [Int]
    var language: AppLanguage = .arabic

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.tight) {
            Text(verbatim: DalilCopy.toward(direction, language))
                .appText(.subhead)
                .foregroundStyle(AppColors.secondaryText)
                .lineLimit(2)
            Spacer(minLength: AppSpacing.tight)
            if let first = minutes.first {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: DalilCopy.shortMinutes(first, language))
                        .appLiveNumber(.title)
                        .foregroundStyle(AppColors.primaryText)
                    if !then.isEmpty {
                        Text(verbatim: then)
                            .appLiveNumber(.subhead)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
        }
        .frame(minHeight: AppSize.touch, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private var then: String {
        DalilCopy.thenMinutes(minutes, language)
    }
}

struct PlaceRow: View {
    var place: Place
    var stationName: String? = nil
    var walkMinutes: Int? = nil
    var showsStation: Bool = true
    var language: AppLanguage = .arabic
    @Environment(\.colorScheme) private var colorScheme

    init(
        place: Place,
        stationName: String? = nil,
        walkMinutes: Int? = nil,
        showsStation: Bool = true,
        language: AppLanguage = .arabic
    ) {
        self.place = place
        self.stationName = stationName
        self.walkMinutes = walkMinutes
        self.showsStation = showsStation
        self.language = language
    }

    init(ranked: RankedPlace, showsStation: Bool = true, language: AppLanguage = .arabic) {
        self.init(
            place: ranked.place,
            stationName: ranked.access.station.localizedName(language: language),
            walkMinutes: ranked.access.displayedMinutes,
            showsStation: showsStation,
            language: language
        )
    }

    var body: some View {
        HStack(spacing: AppSpacing.item) {
            PlacePhotoView(place: place, glyph: place.category.symbolName)
                .frame(width: AppSize.thumb, height: AppSize.thumb)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.item, style: .continuous))
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(place.localizedName(language: language))
                    .appText(.headline)
                    .foregroundStyle(AppColors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .appText(.subhead)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: AppSpacing.tight)
            if let walkMinutes {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "figure.walk")
                    Text(DalilCopy.shortMinutes(walkMinutes, language))
                        .monospacedDigit()
                }
                .appText(.subhead)
                .foregroundStyle(AppColors.secondaryText)
            }
            Image(systemName: "chevron.forward")
                .font(.system(size: AppTextStyle.caption.size, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, AppSpacing.screen)
        .frame(minHeight: AppSize.placeRow)
        .background(AppColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let category = DalilCopy.t(place.category.copyKey, language)
        guard showsStation, let stationName, !stationName.isEmpty else { return category }
        return "\(category) · \(DalilCopy.t("place.near", language)) \(stationName)"
    }
}

struct SearchField: View {
    var placeholder: String
    @Binding var text: String
    var trailingSystemImage: String? = "location.fill"
    var trailingAccessibilityLabel: String = ""
    var trailingAction: (() -> Void)? = nil
    var onSubmit: () -> Void = {}
    var autoFocus: Bool = false
    var onActivate: (() -> Void)? = nil
    var elevated: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: AppSpacing.tight) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppTextStyle.body.size, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)
                .accessibilityHidden(true)
            if let onActivate {
                Text(placeholder)
                    .appText(.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onActivate)
            } else {
                TextField(placeholder, text: $text)
                    .appText(.body)
                    .foregroundStyle(AppColors.primaryText)
                    .multilineTextAlignment(.leading)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($focused)
                    .onSubmit(onSubmit)
            }
            if let trailingAction, let trailingSystemImage {
                Button(action: trailingAction) {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: AppTextStyle.body.size, weight: .semibold))
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(width: AppSize.touch, height: AppSize.touch)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(trailingAccessibilityLabel)
            }
        }
        .padding(.leading, AppSpacing.screen)
        .padding(.trailing, trailingAction == nil ? AppSpacing.screen : AppSpacing.xxs)
        .frame(height: AppSize.search)
        .background(AppColors.cardSurface)
        .clipShape(Capsule())
        .overlay {
            if !elevated {
                Capsule().stroke(AppColors.controlBorder, lineWidth: 1)
            }
        }
        .shadow(color: elevated ? AppColors.navy.opacity(0.08) : .clear, radius: 10, y: 3)
        .onAppear {
            guard autoFocus, onActivate == nil else { return }
            focused = true
        }
        .task {
            guard autoFocus, onActivate == nil else { return }
            try? await Task.sleep(for: .milliseconds(80))
            focused = true
        }
        .accessibilityAddTraits(onActivate == nil ? AccessibilityTraits() : .isButton)
    }
}

enum BrowseCategory: String, CaseIterable, Identifiable {
    case park, tourism, restaurant, cafe, gym, pharmacy

    var id: String { rawValue }

    var copyKey: String {
        switch self {
        case .park: return "home.cat.parks"
        case .tourism: return "home.cat.tourism"
        case .restaurant: return "cat.restaurant"
        case .cafe: return "cat.cafe"
        case .gym: return "home.cat.clubs"
        case .pharmacy: return "cat.pharmacy"
        }
    }

    var placeCategory: PlaceCategory {
        switch self {
        case .park: return .park
        case .tourism: return .family
        case .restaurant: return .restaurant
        case .cafe: return .cafe
        case .gym: return .gym
        case .pharmacy: return .pharmacy
        }
    }

    var browse: HomeBrowse {
        switch self {
        case .park: return .parks
        case .tourism: return .tourism
        case .restaurant: return .restaurant
        case .cafe: return .cafe
        case .gym: return .clubs
        case .pharmacy: return .pharmacy
        }
    }

    static let homeTiles: [BrowseCategory] = [.tourism, .restaurant, .cafe, .park]
}

struct CategoryChip: View {
    var category: PlaceCategory
    var title: String
    var isSelected: Bool

    init(category: PlaceCategory, title: String, isSelected: Bool) {
        self.category = category
        self.title = title
        self.isSelected = isSelected
    }

    init(browse: BrowseCategory, language: AppLanguage, isSelected: Bool) {
        self.init(
            category: browse.placeCategory,
            title: DalilCopy.t(browse.copyKey, language),
            isSelected: isSelected
        )
    }

    var body: some View {
        HStack(spacing: AppSpacing.chip) {
            Image(systemName: category.symbolName)
                .font(.system(size: AppTextStyle.subhead.size, weight: .semibold))
                .foregroundStyle(isSelected ? AppColors.cream : AppColors.categoryInk(category))
            Text(title)
                .appText(.subhead)
                .foregroundStyle(isSelected ? AppColors.cream : AppColors.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.item)
        .frame(height: AppSize.categoryChip)
        .background(isSelected ? AppColors.navy : AppColors.categoryTint(category))
        .clipShape(Capsule())
    }
}

struct CategoryTile: View {
    var browse: BrowseCategory
    var language: AppLanguage

    var body: some View {
        VStack(spacing: AppSpacing.tight) {
            Image(systemName: browse.placeCategory.symbolName)
                .font(.system(size: AppSpacing.section, weight: .semibold))
                .foregroundStyle(AppColors.categoryInk(browse.placeCategory))
            Text(DalilCopy.t(browse.copyKey, language))
                .appText(.subhead)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: AppSize.thumb + AppSpacing.section)
        .background(AppColors.categoryTint(browse.placeCategory))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(DalilCopy.t(browse.copyKey, language))
    }
}

struct TimelineStep: View {
    var index: Int
    var title: String
    var subtitle: String
    var isFirst: Bool
    var isLast: Bool

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.item) {
            VStack(spacing: 0) {
                Circle()
                    .fill(AppColors.mint)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text("\(index)")
                            .appText(.subhead)
                            .foregroundStyle(AppColors.onAccent)
                    }
                if !isLast {
                    AppColors.border
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 28)
            .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .appText(.headline)
                    .foregroundStyle(AppColors.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .appText(.subhead)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: AppSize.timelineRow)
        .accessibilityElement(children: .combine)
    }
}

struct PrimaryButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.bold(19))
                .foregroundStyle(AppColors.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.button)
        }
        .buttonStyle(.plain)
        .background(AppColors.accent)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
    }
}

struct SecondaryButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .appText(.headline)
                .foregroundStyle(AppColors.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.search)
        }
        .buttonStyle(.plain)
        .background(AppColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                .stroke(AppColors.controlBorder, lineWidth: 1)
        )
    }
}

enum ServiceState {
    case running
    case closed
    case disrupted
}

struct StatusPill: View {
    var state: ServiceState
    var subtitle: String? = nil
    var language: AppLanguage = .arabic

    var body: some View {
        HStack(spacing: AppSpacing.chip) {
            Circle()
                .fill(ink)
                .frame(width: AppSpacing.tight, height: AppSpacing.tight)
            Text(label)
                .appText(.subhead)
                .foregroundStyle(ink)
                .lineLimit(1)
            if let subtitle {
                Text("· \(subtitle)")
                    .appText(.subhead)
                    .foregroundStyle(ink)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AppSpacing.item)
        .frame(height: AppSize.chip)
        .background(ink.opacity(0.15))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }

    private var label: String {
        switch state {
        case .running: return DalilCopy.t("status.running", language)
        case .closed: return DalilCopy.t("status.closed", language)
        case .disrupted: return DalilCopy.t("status.disrupted", language)
        }
    }

    private var ink: Color {
        switch state {
        case .running: return AppColors.mintInk
        case .closed: return AppColors.secondaryText
        case .disrupted: return AppColors.electricInk
        }
    }
}

extension PlaceCategory {
    var copyKey: String {
        switch self {
        case .cafe: return "cat.cafe"
        case .restaurant: return "cat.restaurant"
        case .dessert: return "cat.dessert"
        case .park, .viewpoint: return "home.cat.parks"
        case .gym: return "cat.gym"
        case .pharmacy: return "cat.pharmacy"
        case .family, .cowork: return "home.cat.tourism"
        default: return "cat.place"
        }
    }

    var symbolName: String {
        switch self {
        case .cafe, .cowork: return "cup.and.saucer.fill"
        case .restaurant, .dessert: return "fork.knife"
        case .park, .viewpoint: return "leaf.fill"
        case .gym: return "figure.strengthtraining.traditional"
        case .pharmacy: return "cross.case.fill"
        case .family: return "building.columns.fill"
        default: return "mappin.and.ellipse"
        }
    }

    static func pinHex(_ category: PlaceCategory) -> String {
        switch category {
        case .cafe, .cowork: return "E6007E"
        case .family: return "2E7DF0"
        case .park, .viewpoint, .pharmacy: return "008E51"
        case .restaurant, .dessert, .gym: return "F2A20C"
        default: return "F2A20C"
        }
    }
}

#if DEBUG
private enum DalilPreviewData {
    static let place = Place(
        id: "preview-olaya",
        googlePlaceId: nil,
        nameAr: "صحن العليا",
        nameEn: "Olaya Court",
        latitude: 24.69,
        longitude: 46.68,
        category: .restaurant,
        stationId: "bank_albilad",
        stationRelation: .nearby,
        floor: nil,
        ticketGatePosition: nil,
        nearestExitId: nil,
        editorialTags: [],
        verificationStatus: .verified,
        source: .sample,
        priceLevel: 2,
        rating: 4.5,
        reviewCount: 12,
        isOpenNow: true,
        shortDescriptionAr: "مطبخ نجدي",
        shortDescriptionEn: "Najdi kitchen",
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

private struct DalilAtomGallery: View {
    @State private var query = ""
    var language: AppLanguage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                StatusPill(state: .running, subtitle: language == .arabic ? "حتى ١٢ م" : "until 12 PM", language: language)
                SearchField(
                    placeholder: DalilCopy.t("home.search", language),
                    text: $query,
                    trailingAccessibilityLabel: DalilCopy.t("home.useLocation", language),
                    trailingAction: {}
                )
                HStack(spacing: AppSpacing.tight) {
                    LineBadge(line: .blue, style: .dot)
                    LineBadge(line: .blue, style: .pill, language: language)
                    LineBadge(line: .blue, style: .number)
                    StationMarker(lines: [.blue], isInterchange: false)
                    StationMarker(lines: [.blue, .red], isInterchange: true)
                }
                DepartureRow(direction: language == .arabic ? "المطار" : "Airport", minutes: [3, 11], language: language)
                SectionHeader(title: "home.nearbyPlaces", action: {})
                PlaceRow(place: DalilPreviewData.place, stationName: language == .arabic ? "بنك البلاد" : "Bank Albilad", walkMinutes: 5, language: language)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.tight) {
                        ForEach(BrowseCategory.allCases) { item in
                            CategoryChip(browse: item, language: language, isSelected: item == .restaurant)
                        }
                    }
                }
                TimelineStep(index: 1, title: language == .arabic ? "اخرج من مخرج 3" : "Take Exit 3", subtitle: language == .arabic ? "طريق الأمير محمد" : "Prince Mohammed Rd", isFirst: true, isLast: false)
                TimelineStep(index: 2, title: language == .arabic ? "امشِ نحو المكان" : "Walk to the place", subtitle: language == .arabic ? "٣ د · ٢٣١ م" : "3 min · 231 m", isFirst: false, isLast: true)
                PrimaryButton(title: language == .arabic ? "ابدأ الرحلة" : "Start trip", action: {})
                SecondaryButton(title: language == .arabic ? "التفاصيل" : "Details", action: {})
            }
            .padding(AppSpacing.screen)
        }
        .background(AppColors.warmBackground)
        .environment(\.layoutDirection, language == .arabic ? .rightToLeft : .leftToRight)
    }
}

#Preview("RTL light") {
    DalilAtomGallery(language: .arabic).preferredColorScheme(.light)
}

#Preview("RTL dark") {
    DalilAtomGallery(language: .arabic).preferredColorScheme(.dark)
}

#Preview("LTR light") {
    DalilAtomGallery(language: .english).preferredColorScheme(.light)
}

#Preview("LTR dark") {
    DalilAtomGallery(language: .english).preferredColorScheme(.dark)
}
#endif
