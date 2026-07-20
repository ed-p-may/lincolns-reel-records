import CoreLocation
import Observation

enum LocationAuthorizationAvailability: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
    case restricted
    case servicesDisabled

    static func resolve(
        authorizationStatus: CLAuthorizationStatus,
        servicesEnabled: Bool
    ) -> LocationAuthorizationAvailability {
        guard servicesEnabled else { return .servicesDisabled }
        return switch authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorizedAlways, .authorizedWhenInUse: .allowed
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }
}

enum LocationCaptureState: Equatable, Sendable {
    case idle
    case requestingPermission
    case locating
    case captured(coordinate: CatchCoordinate, accuracy: Double)
    case denied
    case restricted
    case servicesDisabled
    case unavailable

    var message: String {
        switch self {
        case .idle:
            "No GPS pin selected."
        case .requestingPermission:
            "Waiting for location permission…"
        case .locating:
            "Finding an accurate current location…"
        case let .captured(_, accuracy):
            "Current location captured within \(Int(accuracy.rounded())) m."
        case .denied:
            "Location access is denied. Choose a pin on the map instead."
        case .restricted:
            "Location access is restricted. Choose a pin on the map instead."
        case .servicesDisabled:
            "Location Services are off. Choose a pin on the map instead."
        case .unavailable:
            "A current accurate fix was not available. Choose a pin on the map instead."
        }
    }
}

@MainActor
@Observable
final class CatchLocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var timeoutTask: Task<Void, Never>?
    private var settleTask: Task<Void, Never>?
    private var bestSample: LocationSample?
    private var isCaptureRequested = false

    private(set) var state: LocationCaptureState = .idle

    init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestCurrentLocation() {
        guard !isCaptureRequested else { return }
        isCaptureRequested = true
        let availability = LocationAuthorizationAvailability.resolve(
            authorizationStatus: manager.authorizationStatus,
            servicesEnabled: CLLocationManager.locationServicesEnabled()
        )
        switch availability {
        case .notDetermined:
            state = .requestingPermission
            manager.requestWhenInUseAuthorization()
        case .allowed:
            beginLocating()
        case .denied:
            finish(with: .denied)
        case .restricted:
            finish(with: .restricted)
        case .servicesDisabled:
            finish(with: .servicesDisabled)
        }
    }

    func reset() {
        finish(with: .idle)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isCaptureRequested else { return }
        let availability = LocationAuthorizationAvailability.resolve(
            authorizationStatus: manager.authorizationStatus,
            servicesEnabled: CLLocationManager.locationServicesEnabled()
        )
        switch availability {
        case .allowed:
            if state != .locating {
                beginLocating()
            }
        case .denied:
            finish(with: .denied)
        case .restricted:
            finish(with: .restricted)
        case .servicesDisabled:
            finish(with: .servicesDisabled)
        case .notDetermined:
            state = .requestingPermission
        }
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations.reversed() {
            guard let coordinate = CatchCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ) else { continue }
            let sample = LocationSample(
                coordinate: coordinate,
                horizontalAccuracy: location.horizontalAccuracy,
                timestamp: location.timestamp
            )
            guard LocationFixPolicy.rejection(for: sample) == nil else { continue }
            if let bestSample {
                if sample.horizontalAccuracy < bestSample.horizontalAccuracy {
                    self.bestSample = sample
                }
            } else {
                bestSample = sample
            }
            scheduleSettleIfNeeded()
        }
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        guard isCaptureRequested else { return }
        if let locationError = error as? CLError, locationError.code == .locationUnknown {
            return
        }
        finish(with: .unavailable)
    }

    private func beginLocating() {
        guard isCaptureRequested else { return }
        timeoutTask?.cancel()
        settleTask?.cancel()
        bestSample = nil
        state = .locating
        manager.startUpdatingLocation()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if let bestSample {
                finish(with: .captured(
                    coordinate: bestSample.coordinate,
                    accuracy: bestSample.horizontalAccuracy
                ))
            } else {
                finish(with: .unavailable)
            }
        }
    }

    private func scheduleSettleIfNeeded() {
        guard settleTask == nil else { return }
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self, let bestSample else { return }
            finish(with: .captured(
                coordinate: bestSample.coordinate,
                accuracy: bestSample.horizontalAccuracy
            ))
        }
    }

    private func finish(with state: LocationCaptureState) {
        timeoutTask?.cancel()
        timeoutTask = nil
        settleTask?.cancel()
        settleTask = nil
        bestSample = nil
        isCaptureRequested = false
        manager.stopUpdatingLocation()
        self.state = state
    }
}
