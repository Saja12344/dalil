import MapKit
import SwiftUI

struct ModeratorInboxView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var router: AppRouter
    @State private var items: [PlaceSubmission] = []

    var body: some View {
        List(items) { item in
            Button {
                router.open(.submissionDetail(item.id))
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.nameAr).font(NazlahTypography.title(18))
                    Text(LocalizedStringKey("submission.\(item.status.rawValue)"))
                    Text(item.createdAt.formatted()).font(NazlahTypography.caption(12)).foregroundStyle(Color("InkMuted"))
                }
            }
        }
        .navigationTitle("moderator.title")
        .task {
            items = (try? await environment.moderator.pendingSubmissions()) ?? []
        }
    }
}

struct ModeratorSubmissionView: View {
    var submissionId: String
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var session: CatalogSession
    @State private var item: PlaceSubmission?
    @State private var notes = ""
    @State private var duplicates: [DuplicateCandidate] = []

    var body: some View {
        Group {
            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(item.nameAr).font(NazlahTypography.display(28))
                        Text(item.descriptionAr)
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude),
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        ))) {
                            Marker(item.nameAr, coordinate: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude))
                            if let station = session.catalog?.station(id: item.selectedStationId) {
                                Marker(station.nameAr, coordinate: station.coordinate.clCoordinate)
                            }
                        }
                        .frame(height: 220)
                        .environment(\.layoutDirection, .leftToRight)
                        if !duplicates.isEmpty {
                            Text("moderator.duplicates").font(NazlahTypography.title(18))
                            ForEach(duplicates, id: \.placeId) { dup in
                                Text("\(dup.name) — \(Int(dup.meters))m")
                            }
                        }
                        TextField("moderator.notes", text: $notes, axis: .vertical)
                        NazlahButton(title: "moderator.approve") {
                            Task { try? await environment.moderator.approve(submissionId: item.id, reviewerId: environment.auth.currentUser?.id ?? "mod", edits: nil) }
                        }
                        NazlahButton(title: "moderator.info", kind: .secondary) {
                            Task { try? await environment.moderator.requestInfo(submissionId: item.id, reviewerId: environment.auth.currentUser?.id ?? "mod", notes: notes) }
                        }
                        NazlahButton(title: "moderator.reject", kind: .ghost) {
                            Task { try? await environment.moderator.reject(submissionId: item.id, reviewerId: environment.auth.currentUser?.id ?? "mod", notes: notes) }
                        }
                    }
                    .padding(AppSpacing.screen)
                }
            } else {
                ProgressView().task { await load() }
            }
        }
        .navigationTitle("moderator.review")
    }

    private func load() async {
        item = try? await environment.submissions.submission(id: submissionId)
        if let item, let catalog = session.catalog {
            let existing = session.rankedPlaces.map(\.place)
            duplicates = environment.moderator.duplicateCandidates(for: item, existing: existing)
            _ = catalog
        }
    }
}
