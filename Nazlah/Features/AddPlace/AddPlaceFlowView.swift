import PhotosUI
import SwiftUI
import UIKit

struct AddPlaceFlowView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var session: CatalogSession
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var draft = AddPlaceDraft()

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(draft.step), total: 5)
                .tint(Color("SunsetOrange"))
                .padding()
            TabView(selection: $draft.step) {
                stepOne.tag(1)
                stepTwo.tag(2)
                stepThree.tag(3)
                stepFour.tag(4)
                stepFive.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack {
                if draft.step > 1 {
                    NazlahButton(title: "add.back", kind: .secondary) { draft.step -= 1 }
                }
                NazlahButton(title: draft.step == 5 ? "add.submit" : "add.next") {
                    if draft.step == 5 {
                        Task { await submit() }
                    } else {
                        draft.step += 1
                    }
                }
            }
            .padding(16)
        }
        .background(Color("Canvas").ignoresSafeArea())
        .navigationTitle("add.title")
        .alert("add.limit.title", isPresented: $draft.showLimit) {
            Button("state.retry", role: .cancel) {}
        }
    }

    private var stepOne: some View {
        Form {
            TextField("add.nameAr", text: $draft.nameAr)
            TextField("add.nameEn", text: $draft.nameEn)
            Picker("add.category", selection: $draft.category) {
                ForEach(PlaceCategory.allCases) { category in
                    Text(LocalizedStringKey("category.\(category.rawValue)")).tag(category)
                }
            }
            TextField("add.description", text: $draft.descriptionAr, axis: .vertical)
        }
    }

    private var stepTwo: some View {
        Form {
            Text("add.location.help")
            TextField("add.mapsURL", text: $draft.mapsURL)
            Button("add.useLocation") {
                Task {
                    _ = await environment.location.requestWhenInUse()
                    if let coord = try? await environment.location.currentCoordinate() {
                        draft.latitude = coord.latitude
                        draft.longitude = coord.longitude
                    }
                }
            }
            HStack {
                Text("add.lat")
                Spacer()
                Text(String(format: "%.5f", draft.latitude)).font(NazlahTypography.mono(13)).foregroundStyle(Color("InkMuted"))
            }
            HStack {
                Text("add.lon")
                Spacer()
                Text(String(format: "%.5f", draft.longitude)).font(NazlahTypography.mono(13)).foregroundStyle(Color("InkMuted"))
            }
        }
    }

    private var stepThree: some View {
        Form {
            Picker("add.station", selection: $draft.stationId) {
                ForEach(suggestedStations) { station in
                    Text(station.localizedName(language: settings.language)).tag(station.id)
                }
            }
            Picker("add.relation", selection: $draft.relation) {
                Text("relation.inside").tag(StationRelation.insideStation)
                Text("relation.connected").tag(StationRelation.directlyConnected)
                Text("relation.nearby").tag(StationRelation.nearby)
                Text("relation.unknown").tag(StationRelation.unverified)
            }
            Text("add.relation.help").font(NazlahTypography.caption(12)).foregroundStyle(Color("InkMuted"))
        }
    }

    private var stepFour: some View {
        Form {
            Text("add.photos.rights")
            PhotosPicker(selection: $draft.photoItems, maxSelectionCount: 4, matching: .images) {
                Text("add.photos.pick")
            }
            Text("add.photos.count \(draft.photoItems.count)")
        }
        .onChange(of: draft.photoItems) { _, items in
            Task { await draft.loadPhotos(items) }
        }
    }

    private var stepFive: some View {
        Form {
            LabeledContent("add.nameAr", value: draft.nameAr)
            LabeledContent("add.station", value: session.catalog?.station(id: draft.stationId)?.localizedName(language: settings.language) ?? "")
            Text("add.review.note")
                .foregroundStyle(Color("InkMuted"))
        }
    }

    private var suggestedStations: [MetroStation] {
        guard let catalog = session.catalog else { return [] }
        let point = GeoCoordinate(latitude: draft.latitude, longitude: draft.longitude)
        return environment.nearestFinder.ranked(to: point, in: catalog, limit: 8)
    }

    private func submit() async {
        do {
            let user = try await environment.auth.requireSignedInUser()
            let images = try await environment.images.uploadPlaceImages(draft.imageData, submissionId: draft.id)
            let item = PlaceSubmission(
                id: draft.id,
                submittedBy: user.id,
                nameAr: draft.nameAr,
                nameEn: draft.nameEn.isEmpty ? draft.nameAr : draft.nameEn,
                category: draft.category,
                descriptionAr: draft.descriptionAr,
                descriptionEn: draft.descriptionAr,
                latitude: draft.latitude,
                longitude: draft.longitude,
                selectedStationId: draft.stationId,
                stationRelationClaim: draft.relation,
                imageURLs: images,
                googleMapsURL: draft.mapsURL.isEmpty ? nil : draft.mapsURL,
                status: .pendingReview,
                moderatorNotes: "",
                createdAt: .now,
                reviewedAt: nil,
                reviewedBy: nil
            )
            _ = try await environment.submissions.submit(item)
            dismiss()
        } catch SubmissionLimitError.tooMany {
            draft.showLimit = true
        } catch AuthNeed.signInRequired {
            environment.router.isShowingAuth = true
        } catch {
            draft.showLimit = true
        }
    }
}

@MainActor
final class AddPlaceDraft: ObservableObject {
    let id = UUID().uuidString
    @Published var step = 1
    @Published var nameAr = ""
    @Published var nameEn = ""
    @Published var category: PlaceCategory = .cafe
    @Published var descriptionAr = ""
    @Published var mapsURL = ""
    @Published var latitude = 24.6965
    @Published var longitude = 46.6837
    @Published var stationId = "bank_albilad"
    @Published var relation: StationRelation = .nearby
    @Published var photoItems: [PhotosPickerItem] = []
    @Published var imageData: [Data] = []
    @Published var showLimit = false

    func loadPhotos(_ items: [PhotosPickerItem]) async {
        var loaded: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                loaded.append(ImagePrep.stripGPSMetadata(from: data))
            }
        }
        imageData = loaded
    }
}
