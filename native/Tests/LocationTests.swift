import CoreLocation
import Foundation

func runLocationTests() {
    let suiteName = "go.outside.location-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = LocationStore(defaults: defaults)
    precondition(store.saved == nil && !store.isRequesting)
    store.chooseCity(CityCandidate(name: "Brooklyn, NY, US", latitude: 40.67821, longitude: -73.94416))
    precondition(store.saved?.latitude == 40.68 && store.saved?.longitude == -73.94)
    precondition(store.saved?.mode == .manual && !store.isLastKnown)
    let restored = LocationStore(defaults: defaults)
    precondition(restored.saved?.name == "Brooklyn, NY, US" && !restored.isLastKnown)
    restored.refresh(userInitiated: false)
    precondition(!restored.isRequesting, "Manual-city mode must not request system location")
    restored.locationManager(CLLocationManager(), didUpdateLocations: [CLLocation(latitude: 0, longitude: 0)])
    precondition(restored.saved?.latitude == 40.68, "Unrequested or cancelled fixes must not overwrite a chosen city")
    let automatic = SavedLocation(latitude: 51.5, longitude: -0.12, name: "London", updatedAt: Date(), mode: .automatic)
    defaults.set(try! JSONEncoder().encode(automatic), forKey: "outside.location")
    let cached = LocationStore(defaults: defaults)
    precondition(cached.saved?.latitude == 51.5 && cached.isLastKnown)
    defaults.set(Data("invalid".utf8), forKey: "outside.location")
    precondition(LocationStore(defaults: defaults).saved == nil)
    let invalid = SavedLocation(latitude: 91, longitude: 0, name: "Invalid", updatedAt: Date(), mode: .manual)
    defaults.set(try! JSONEncoder().encode(invalid), forKey: "outside.location")
    precondition(LocationStore(defaults: defaults).saved == nil)
    runWakeRefreshPolicyTests()
    print("PASS: coarse location persistence, offline cache, manual mode, wake policy and invalid/cancelled fixes")
}

private func runWakeRefreshPolicyTests() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 12))!
    let automatic = { (updatedAt: Date) in
        SavedLocation(latitude: 40.68, longitude: -73.94, name: "Brooklyn", updatedAt: updatedAt, mode: .automatic)
    }
    let manual = SavedLocation(latitude: 40.68, longitude: -73.94, name: "Brooklyn", updatedAt: now.addingTimeInterval(-7 * 3_600), mode: .manual)

    precondition(!manual.shouldRefreshAfterWake(at: now, calendar: calendar), "Manual-city mode must never refresh on wake")
    precondition(!automatic(now.addingTimeInterval(-(6 * 3_600 - 1))).shouldRefreshAfterWake(at: now, calendar: calendar), "Automatic refresh must wait through 5h59m59s")
    precondition(automatic(now.addingTimeInterval(-6 * 3_600)).shouldRefreshAfterWake(at: now, calendar: calendar), "Automatic refresh must start at exactly six hours")
    precondition(!automatic(now.addingTimeInterval(-60)).shouldRefreshAfterWake(at: now, calendar: calendar), "A recently saved automatic location must not refresh")

    let firstWakeNextDay = calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 0, minute: 2))!
    let savedMinutesEarlier = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 23, minute: 58))!
    precondition(automatic(savedMinutesEarlier).shouldRefreshAfterWake(at: firstWakeNextDay, calendar: calendar), "The first wake on a new calendar day must refresh even after only minutes")
}
