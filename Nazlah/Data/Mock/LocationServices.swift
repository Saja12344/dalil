import CoreLocation
import Foundation
import UserNotifications

@MainActor
final class SystemLocationService: NSObject, LocationServing {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<GeoCoordinate, Error>?
    private var streamContinuation: AsyncStream<GeoCoordinate>.Continuation?

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 15
        manager.activityType = .fitness
        manager.delegate = self
    }

    var authorization: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestWhenInUse() async -> CLAuthorizationStatus {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            try? await Task.sleep(for: .seconds(0.4))
        }
        return manager.authorizationStatus
    }

    func requestAlways() async -> CLAuthorizationStatus {
        let current = await requestWhenInUse()
        guard current == .authorizedWhenInUse || current == .authorizedAlways else { return current }
        if manager.authorizationStatus != .authorizedAlways {
            manager.requestAlwaysAuthorization()
            try? await Task.sleep(for: .seconds(0.4))
        }
        return manager.authorizationStatus
    }

    func currentCoordinate() async throws -> GeoCoordinate {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            break
        case .denied, .restricted:
            throw LocationFailure.denied
        default:
            throw LocationFailure.unavailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationStream() -> AsyncStream<GeoCoordinate> {
        stopTripUpdates()
        let stream = AsyncStream<GeoCoordinate> { continuation in
            self.streamContinuation = continuation
            continuation.onTermination = { _ in
                Task { @MainActor in
                    self.manager.stopUpdatingLocation()
                    self.manager.allowsBackgroundLocationUpdates = false
                    self.streamContinuation = nil
                }
            }
        }
        manager.pausesLocationUpdatesAutomatically = false
        if manager.authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
        return stream
    }

    func stopTripUpdates() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        streamContinuation?.finish()
        streamContinuation = nil
    }
}

extension SystemLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            let coordinate = GeoCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            continuation?.resume(returning: coordinate)
            continuation = nil
            streamContinuation?.yield(coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

/// Simulator-friendly default near Olaya when Core Location has no fix.
struct PreviewLocationService: LocationServing {
    var authorization: CLAuthorizationStatus { .authorizedWhenInUse }

    func requestWhenInUse() async -> CLAuthorizationStatus { .authorizedWhenInUse }

    func requestAlways() async -> CLAuthorizationStatus { .authorizedWhenInUse }

    func currentCoordinate() async throws -> GeoCoordinate {
        GeoCoordinate(latitude: 24.6965, longitude: 46.6837)
    }

    func locationStream() -> AsyncStream<GeoCoordinate> {
        AsyncStream { continuation in
            continuation.yield(GeoCoordinate(latitude: 24.6965, longitude: 46.6837))
        }
    }

    func stopTripUpdates() {}
}

enum TripNotifier {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "dalil.trip.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
