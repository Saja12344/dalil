import SwiftUI

struct AroundYouView: View {
    @EnvironmentObject private var session: CatalogSession
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: AppSettings
    @State private var showStatus = false
    @State private var renamingLocation: SavedLocation?

    private var lang: AppLanguage { settings.language }
    private func t(_ key: String) -> String { DalilCopy.t(key, lang) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                header
                searchBox
                quickDestinations
                nearestStation
                browseRow
                nearbySection
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.section)
            .appTabBarClearance()
        }
        .background(AppColors.warmBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showStatus) {
            ServiceStatusSheet(language: lang)
                .presentationDetents([.medium])
        }
        .sheet(item: $renamingLocation) { item in
            SaveLocationSheet(mode: .rename(item), nearestSummary: nil)
        }
        .task {
            await session.loadCatalog()
            openLaunchRoutes()
            if session.rankedPlaces.isEmpty { await session.load() }
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.tight) {
            BrandMark(size: 28)
            Text(t("brand"))
                .appText(.headline)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(1)
            Spacer(minLength: AppSpacing.tight)
            Button { showStatus = true } label: {
                HStack(spacing: AppSpacing.chip) {
                    Circle()
                        .fill(MetroServiceClock.isRunning() ? AppColors.mint : AppColors.secondaryText)
                        .frame(width: AppSpacing.chip, height: AppSpacing.chip)
                    Text(t(MetroServiceClock.isRunning() ? "status.running" : "status.closed"))
                        .appText(.subhead)
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(t("status.sheet.title"))
        }
        .frame(minHeight: AppSize.header)
        .padding(.top, AppSpacing.tight)
    }

    private var searchBox: some View {
        SearchField(
            placeholder: t("home.search"),
            text: .constant(""),
            trailingAccessibilityLabel: t("home.useLocation"),
            trailingAction: { Task { await session.useNearMe() } },
            onActivate: { router.presentSearch() },
            elevated: true
        )
    }

    private var quickDestinations: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.tight) {
                slotChip(kind: .home, location: settings.homeLocation)
                slotChip(kind: .work, location: settings.workLocation)
                ForEach(settings.customLocations) { location in
                    savedChip(location)
                }
                SavedPlaceChip(
                    title: t("home.quick.add"),
                    glyph: .add,
                    isPlaceholder: true
                ) {
                    router.presentMapPicker(.add)
                }
                .accessibilityHint(t("map.pickSaved"))
            }
        }
    }

    private func slotChip(kind: SavedLocation.Kind, location: SavedLocation?) -> some View {
        Group {
            if let location {
                savedChip(location)
            } else {
                SavedPlaceChip(
                    title: t(kind == .home ? "home.quick.addHome" : "home.quick.addWork"),
                    glyph: kind.glyph,
                    isPlaceholder: true
                ) {
                    router.presentMapPicker(kind == .home ? .home : .work)
                }
                .accessibilityHint(t(kind == .home ? "map.pickHome" : "map.pickWork"))
            }
        }
    }

    private func savedChip(_ location: SavedLocation) -> some View {
        SavedPlaceChip(
            title: location.title(lang),
            glyph: location.kind.glyph,
            isPlaceholder: false
        ) {
            useSaved(location)
        }
        .accessibilityHint(t("saved.planHint") + ". " + t("saved.editHint"))
        .contextMenu {
            Button {
                useSaved(location)
            } label: {
                Label(t("saved.planHint"), systemImage: "arrow.triangle.turn.up.right.diamond")
            }
            if location.kind == .custom {
                Button {
                    renamingLocation = location
                } label: {
                    Label(t("saved.rename"), systemImage: "pencil")
                }
            }
            Button {
                router.presentMapPicker(.relocate(location.id))
            } label: {
                Label(t("saved.move"), systemImage: "map")
            }
            Button(role: .destructive) {
                settings.removeSavedLocation(id: location.id)
            } label: {
                Label(t("saved.delete"), systemImage: "trash")
            }
        }
    }

    private func useSaved(_ location: SavedLocation) {
        router.open(.savedTrip(location.id))
    }

    private var nearestStation: some View {
        Group {
            if let station = session.nearestStation, let catalog = session.catalog {
                let meters = Int(session.anchor.distanceMeters(to: station.coordinate).rounded())
                let walkMinutes = max(1, Int((Double(meters) / 80).rounded()))
                HomeStationHero(
                    station: station,
                    lines: catalog.lines(for: station),
                    walkMinutes: walkMinutes,
                    walkMeters: meters,
                    rows: MetroDepartureClock.rows(station: station, catalog: catalog, language: lang),
                    language: lang
                ) {
                    router.open(.station(station.id))
                }
            }
        }
    }

    private var browseRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            Text(t("home.browseBy"))
                .appText(.title)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(2)
            HStack(spacing: AppSpacing.tight) {
                ForEach(BrowseCategory.homeTiles) { browse in
                    Button { router.open(.browse(browse.browse)) } label: {
                        CategoryTile(browse: browse, language: lang)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            HStack(alignment: .firstTextBaseline) {
                Text(t("home.nearbyPlaces"))
                    .appText(.title)
                    .foregroundStyle(AppColors.primaryText)
                    .lineLimit(2)
                Spacer()
                Button(t("home.seeAll")) { router.presentSearch() }
                    .appText(.subhead)
                    .foregroundStyle(AppColors.primaryText)
            }
            let items = Array(session.rankedPlaces.prefix(8))
            if session.isLoading && items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.tight) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                .fill(AppColors.softSand)
                                .frame(width: AppSpacing.xxl * 3 + AppSpacing.item, height: AppSpacing.xxl * 2)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screen)
                }
                .padding(.horizontal, -AppSpacing.screen)
            } else if items.isEmpty {
                Text(t("home.nearbyEmpty"))
                    .appText(.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .padding(AppSpacing.item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: AppSpacing.tight) {
                        ForEach(items) { item in
                            Button { router.open(.place(item.place.id)) } label: {
                                PlacePosterCard(ranked: item, language: lang)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screen)
                }
                .padding(.horizontal, -AppSpacing.screen)
            }
        }
    }

    private func openLaunchRoutes() {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-dalil-open-station"), args.indices.contains(idx + 1) {
            router.open(.station(args[idx + 1]))
        }
        if let idx = args.firstIndex(of: "-dalil-open-browse"),
           args.indices.contains(idx + 1),
           let browse = HomeBrowse(rawValue: args[idx + 1]) {
            router.open(.browse(browse))
        }
        if let idx = args.firstIndex(of: "-dalil-open-place"), args.indices.contains(idx + 1) {
            router.open(.place(args[idx + 1]))
        }
        if let idx = args.firstIndex(of: "-dalil-open-saved"), args.indices.contains(idx + 1) {
            let token = args[idx + 1]
            let match: SavedLocation?
            if token == "home" {
                match = settings.homeLocation
            } else if token == "work" {
                match = settings.workLocation
            } else {
                match = settings.savedLocations.first { $0.id == token }
            }
            if let match {
                router.open(.savedTrip(match.id))
            }
        }
    }
}

struct ServiceStatusSheet: View {
    var language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text(DalilCopy.t("status.sheet.title", language))
                .appText(.title)
                .foregroundStyle(AppColors.primaryText)
            StatusPill(
                state: MetroServiceClock.isRunning() ? .running : .closed,
                subtitle: MetroServiceClock.untilLabel(language: language),
                language: language
            )
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(DalilCopy.t("status.hours", language))
                    .appLiveNumber(.headline)
                    .foregroundStyle(AppColors.primaryText)
                Text(DalilCopy.t("status.sheet.body", language))
                    .appText(.body)
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.section)
        .background(AppColors.warmBackground.ignoresSafeArea())
    }
}

struct SavedPlaceChip: View {
    var title: String
    var glyph: DalilGlyph
    var isPlaceholder: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.chip) {
                DalilIcon(glyph: glyph, size: 22, tint: isPlaceholder ? AppColors.cream : nil, shadow: !isPlaceholder)
                Text(title)
                    .appText(.subhead)
                    .lineLimit(1)
            }
            .foregroundStyle(isPlaceholder ? AppColors.secondaryText : AppColors.primaryText)
            .padding(.leading, AppSpacing.tight)
            .padding(.trailing, AppSpacing.item)
            .frame(height: AppSize.chip + AppSpacing.xxs)
            .background(AppColors.cardSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct SaveLocationSheet: View {
    enum Mode: Identifiable {
        case create(GeoCoordinate)
        case rename(SavedLocation)

        var id: String {
            switch self {
            case .create: return "create"
            case .rename(let item): return item.id
            }
        }
    }

    var mode: Mode
    var nearestSummary: String?
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @State private var customName = ""

    private var lang: AppLanguage { settings.language }
    private func t(_ key: String) -> String { DalilCopy.t(key, lang) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(t(isRename ? "saved.rename" : "saved.saveTitle"))
                        .appText(.title)
                        .foregroundStyle(AppColors.primaryText)
                    if let nearestSummary, !isRename {
                        Text("\(t("map.nearest")): \(nearestSummary)")
                            .appText(.subhead)
                            .foregroundStyle(AppColors.secondaryText)
                            .lineLimit(2)
                    }
                }
                if isRename {
                    nameField
                    PrimaryButton(title: t("saved.save")) { saveCustom() }
                } else {
                    saveRow("house.fill", t("saved.saveHome")) { save(kind: .home) }
                    saveRow("briefcase.fill", t("saved.saveWork")) { save(kind: .work) }
                    VStack(alignment: .leading, spacing: AppSpacing.tight) {
                        Text(t("saved.saveCustom"))
                            .appText(.headline)
                            .foregroundStyle(AppColors.primaryText)
                        nameField
                        PrimaryButton(title: t("saved.save")) { saveCustom() }
                            .disabled(trimmedName.isEmpty)
                            .opacity(trimmedName.isEmpty ? 0.45 : 1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.section)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppColors.warmBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("search.cancel")) { dismissSave() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if case .rename(let item) = mode { customName = item.name }
        }
    }

    private var isRename: Bool {
        if case .rename = mode { return true }
        return false
    }

    private var trimmedName: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameField: some View {
        TextField(t("saved.customPlaceholder"), text: $customName)
            .appText(.body)
            .foregroundStyle(AppColors.primaryText)
            .padding(.horizontal, AppSpacing.item)
            .frame(height: AppSize.search)
            .background(AppColors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppColors.controlBorder, lineWidth: 1)
            )
            .submitLabel(.done)
            .onSubmit { if isRename || !trimmedName.isEmpty { saveCustom() } }
    }

    private func saveRow(_ systemImage: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.item) {
                Image(systemName: systemImage)
                    .font(.system(size: AppTextStyle.body.size, weight: .semibold))
                    .foregroundStyle(AppColors.primaryText)
                    .frame(width: AppSize.touch, height: AppSize.touch)
                    .background(AppColors.cardSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppColors.controlBorder, lineWidth: 1))
                Text(title)
                    .appText(.headline)
                    .foregroundStyle(AppColors.primaryText)
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.item)
            .background(AppColors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.controlBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func save(kind: SavedLocation.Kind) {
        guard let coordinate = coordinate else { return }
        settings.saveSlot(kind, at: coordinate)
        dismissSave()
    }

    private func saveCustom() {
        switch mode {
        case .create(let coordinate):
            guard !trimmedName.isEmpty else { return }
            settings.saveSlot(.custom, at: coordinate, name: trimmedName)
        case .rename(let item):
            settings.renameSavedLocation(id: item.id, to: trimmedName)
        }
        dismissSave()
    }

    private var coordinate: GeoCoordinate? {
        if case .create(let coordinate) = mode { return coordinate }
        return nil
    }

    private func dismissSave() {
        router.pendingSaveCoordinate = nil
        dismiss()
    }
}
