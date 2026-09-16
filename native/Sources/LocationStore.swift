import CoreLocation
import Foundation

enum LocationMode: String, Codable { case automatic, manual }

struct SavedLocation: Codable {
    let latitude: Double
    let longitude: Double
    let name: String
    let updatedAt: Date
    let mode: LocationMode

    var isValid: Bool {
        latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180
    }

    /// Automatic locations receive a one-shot refresh after six elapsed hours,
    /// or on the first wake in a different Mac calendar day. Manual cities
    /// remain fixed until the user explicitly changes them.
    func shouldRefreshAfterWake(at now: Date, calendar: Calendar) -> Bool {
        guard mode == .automatic else { return false }
        return !calendar.isDate(updatedAt, inSameDayAs: now)
            || now.timeIntervalSince(updatedAt) >= 6 * 3_600
    }
}

struct CityCandidate {
    let name: String
    let latitude: Double
    let longitude: Double
}

final class LocationStore: NSObject, CLLocationManagerDelegate {
    private let defaults: UserDefaults
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var operation = UUID()
    private var automaticRequested = false
    private var locationRequestStarted = false
    private var timeout: Timer?
    private(set) var saved: SavedLocation?
    private(set) var isLastKnown = false
    private(set) var isRequesting = false
    private(set) var message = ""
    private(set) var candidates: [CityCandidate] = []
    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "outside.location"),
           let location = try? JSONDecoder().decode(SavedLocation.self, from: data), location.isValid {
            saved = location
            isLastKnown = location.mode == .automatic
        }
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func refresh(userInitiated: Bool) {
        guard userInitiated || saved?.mode == .automatic else { return }
        if !userInitiated && manager.authorizationStatus != .authorizedAlways { return }
        cancelPending()
        guard CLLocationManager.locationServicesEnabled(),
              manager.authorizationStatus != .denied, manager.authorizationStatus != .restricted else {
            fail("Location is unavailable. Choose a city or enable Location Services in System Settings.")
            return
        }
        automaticRequested = true
        isRequesting = true
        message = "Finding your daylight…"
        onChange?()
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            startOneShot()
        }
    }

    func refreshAfterWake(now: Date = Date(), calendar: Calendar = .current) {
        guard saved?.shouldRefreshAfterWake(at: now, calendar: calendar) == true else { return }
        refresh(userInitiated: false)
    }

    func searchCity(_ query: String) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { message = "Enter a city and country."; onChange?(); return }
        cancelPending()
        let token = operation
        isRequesting = true
        candidates = []
        message = "Looking up your city…"
        onChange?()
        geocoder.geocodeAddressString(query) { [weak self] places, error in
            guard let self = self, self.operation == token else { return }
            self.isRequesting = false
            self.candidates = (places ?? []).compactMap { place in
                guard let location = place.location else { return nil }
                return CityCandidate(name: Self.cityName(place), latitude: location.coordinate.latitude,
                                     longitude: location.coordinate.longitude)
            }
            self.message = self.candidates.isEmpty
                ? "Couldn't find that city. Check your connection and try a city and country."
                : "Confirm your city below."
            self.onChange?()
        }
    }

    func chooseCity(_ city: CityCandidate) {
        cancelPending()
        save(latitude: city.latitude, longitude: city.longitude, name: city.name, mode: .manual)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard saved?.mode != .manual || automaticRequested else { return }
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            cancelPending()
            fail("Location permission is off. You can choose a city instead.")
        } else if automaticRequested && manager.authorizationStatus == .authorizedAlways {
            startOneShot()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard automaticRequested,
              let location = locations.last(where: { $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) < 300 }) else { return }
        automaticRequested = false
        locationRequestStarted = false
        manager.stopUpdatingLocation()
        timeout?.invalidate()
        timeout = nil
        let token = operation
        save(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
             name: "Current location", mode: .automatic)
        // Reverse geocoding is cosmetic. A valid fix already enables offline solar calculations.
        geocoder.reverseGeocodeLocation(location) { [weak self] places, _ in
            guard let self = self, self.operation == token, self.saved?.mode == .automatic,
                  let place = places?.first, let saved = self.saved else { return }
            self.save(latitude: saved.latitude, longitude: saved.longitude,
                      name: Self.cityName(place), mode: .automatic, date: saved.updatedAt)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard automaticRequested else { return }
        cancelPending()
        fail("Couldn't get your location. Try again or choose a city.")
    }

    private func startOneShot() {
        guard automaticRequested, !locationRequestStarted else { return }
        locationRequestStarted = true
        manager.requestLocation()
        timeout?.invalidate()
        timeout = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
            guard let self = self, self.automaticRequested else { return }
            self.cancelPending()
            self.fail("Location took too long. Try again or choose a city.")
        }
    }

    private func cancelPending() {
        operation = UUID()
        automaticRequested = false
        locationRequestStarted = false
        isRequesting = false
        timeout?.invalidate()
        timeout = nil
        manager.stopUpdatingLocation()
        geocoder.cancelGeocode()
    }

    private func fail(_ text: String) {
        isRequesting = false
        isLastKnown = saved?.mode == .automatic
        message = text
        onChange?()
    }

    private func save(latitude: Double, longitude: Double, name: String, mode: LocationMode, date: Date = Date()) {
        let location = SavedLocation(latitude: (latitude * 100).rounded() / 100,
                                     longitude: (longitude * 100).rounded() / 100,
                                     name: name, updatedAt: date, mode: mode)
        guard location.isValid, let data = try? JSONEncoder().encode(location) else { return }
        saved = location
        isLastKnown = false
        isRequesting = false
        message = ""
        defaults.set(data, forKey: "outside.location")
        onChange?()
    }

    private static func cityName(_ place: CLPlacemark) -> String {
        let city = place.locality ?? place.subAdministrativeArea ?? place.name ?? "Selected location"
        return [city, place.administrativeArea, place.isoCountryCode].compactMap { $0 }.joined(separator: ", ")
    }
}
