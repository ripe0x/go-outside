import AppKit
import Foundation

struct GoOutsideMain {
    static func main() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--self-test") {
            NSApplication.shared.setActivationPolicy(.accessory)
            runAccountingTests()
            runSolarTests()
            runPresentationTests()
            runLocationTests()
            runViewTests()
            print("PASS: go/outside self-test")
            return
        }

        if let previewIndex = arguments.firstIndex(of: "--preview"),
           arguments.indices.contains(previewIndex + 1) {
            NSApplication.shared.setActivationPolicy(.accessory)
            do {
                try PreviewRenderer.write(to: URL(fileURLWithPath: arguments[previewIndex + 1], isDirectory: true))
            } catch {
                fputs("go/outside preview failed: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
            return
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        if let identifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            if arguments.contains("--login-item") { return }
            existing.activate(options: [.activateIgnoringOtherApps])
            return
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

GoOutsideMain.main()

private enum PreviewRenderer {
    static func write(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let solarDaylight = SolarSnapshot(
            remainingSeconds: 2 * 3_600,
            totalDaylightSeconds: 12 * 3_600,
            state: .daylight,
            nextSunrise: nil,
            nextSunset: Date().addingTimeInterval(2 * 3_600)
        )
        let solarAfterSunset = SolarSnapshot(
            remainingSeconds: 0,
            totalDaylightSeconds: 12 * 3_600,
            state: .afterSunset,
            nextSunrise: Date().addingTimeInterval(10 * 3_600),
            nextSunset: Date().addingTimeInterval(-3_600)
        )
        let cases: [(String, OutsideModel, OutsideScreen, String, Bool, [CityCandidate])] = [
            ("main-share", OutsideModel(computer: 4 * 3_600, solar: solarDaylight, locationName: "Brooklyn, NY", isLastKnown: false, isAway: false), .main, "", false, []),
            ("main-hollow", OutsideModel(computer: 0, solar: solarDaylight, locationName: "Brooklyn, NY", isLastKnown: false, isAway: false), .main, "", false, []),
            ("main-solid", OutsideModel(computer: 4 * 3_600, solar: solarAfterSunset, locationName: "Brooklyn, NY", isLastKnown: false, isAway: true), .main, "", false, []),
            ("main-empty", OutsideModel(computer: 0, solar: solarAfterSunset, locationName: "Brooklyn, NY", isLastKnown: false, isAway: false), .main, "", false, []),
            ("main-unknown", OutsideModel(computer: 23 * 3_600 + 59 * 60, solar: nil, locationName: "Location needed", isLastKnown: false, isAway: false), .main, "Allow location to find your daylight.", false, []),
            ("main-long", OutsideModel(computer: 23 * 3_600 + 59 * 60, solar: SolarSnapshot(remainingSeconds: 23 * 3_600 + 59 * 60, totalDaylightSeconds: 24 * 3_600, state: .polarDay, nextSunrise: nil, nextSunset: nil), locationName: "Last known location", isLastKnown: true, isAway: false), .main, "", false, []),
            ("setup", OutsideModel(computer: 0, solar: nil, locationName: "", isLastKnown: false, isAway: false), .setup, "Your location is used to estimate sunrise and sunset.", false, []),
            ("setup-error", OutsideModel(computer: 0, solar: nil, locationName: "", isLastKnown: false, isAway: false), .setup, "Location permission is off. You can choose a city instead.", false, []),
            ("settings", OutsideModel(computer: 82_800, solar: solarDaylight, locationName: "Current location", isLastKnown: true, isAway: false), .settings, "", false, []),
            ("city-error", OutsideModel(computer: 0, solar: nil, locationName: "", isLastKnown: false, isAway: false), .city, "Couldn't find that city. Check your connection and try a city and country.", false, []),
            ("city-candidates", OutsideModel(computer: 0, solar: nil, locationName: "", isLastKnown: false, isAway: false), .city, "Confirm your city below.", false, [CityCandidate(name: "Portland, Oregon, US", latitude: 45.52, longitude: -122.68), CityCandidate(name: "Portland, Maine, US", latitude: 43.66, longitude: -70.25)])
        ]

        for appearance in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            for item in cases {
                let view = OutsideView(frame: NSRect(x: 0, y: 0, width: 360, height: 400))
                view.appearance = NSAppearance(named: appearance.1)
                view.render(model: item.1, screen: item.2, locationMessage: item.3, isRequesting: item.4, candidates: item.5, loginEnabled: false)
                try png(of: view).write(to: directory.appendingPathComponent("\(item.0)-\(appearance.0).png"))
            }
        }
    }

    private static func png(of view: NSView) throws -> Data {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
