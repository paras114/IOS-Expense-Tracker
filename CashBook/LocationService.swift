import CoreLocation

/// One-shot location lookup used when adding an expense.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var waiting: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func current() async -> CLLocation? {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted { return nil }

        return await withCheckedContinuation { (c: CheckedContinuation<CLLocation?, Never>) in
            waiting.append(c)
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                self.finish(nil)
            }
        }
    }

    func placeName(for location: CLLocation) async -> String {
        guard let p = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return "" }
        var seen = Set<String>()
        return [p.name, p.subLocality, p.locality]
            .compactMap { $0 }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .joined(separator: ", ")
    }

    private func finish(_ location: CLLocation?) {
        let list = waiting
        waiting = []
        list.forEach { $0.resume(returning: location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let loc = locations.last
        Task { @MainActor in self.finish(loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch self.manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if !self.waiting.isEmpty { self.manager.requestLocation() }
            case .denied, .restricted:
                self.finish(nil)
            default:
                break
            }
        }
    }
}
