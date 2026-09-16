import AppKit
import Foundation

struct GoOutsideMain {
    static func main() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--self-test") {
            NSApplication.shared.setActivationPolicy(.accessory)
            runAccountingTests()
            runSolarTests()
            runAtmosphereTests()
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

private final class PreviewBackdrop: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        (dark ? NSColor(calibratedWhite: 0.055, alpha: 1) : NSColor(calibratedWhite: 0.90, alpha: 1)).setFill()
        bounds.fill()
    }
}

private enum PreviewRenderer {
    static func write(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
        }
        let dawn = date(16, 5, 30)
        let noon = date(16, 12)
        let sunset = date(16, 17, 55)
        let night = date(16, 21)
        let nextDayNoon = date(17, 12)
        let solarDaylight = SolarSnapshot(
            remainingSeconds: 2 * 3_600,
            totalDaylightSeconds: 12 * 3_600,
            state: .daylight,
            nextSunrise: nil,
            nextSunset: noon.addingTimeInterval(2 * 3_600)
        )
        let solarAfterSunset = SolarSnapshot(
            remainingSeconds: 0,
            totalDaylightSeconds: 12 * 3_600,
            state: .afterSunset,
            nextSunrise: night.addingTimeInterval(10 * 3_600),
            nextSunset: night.addingTimeInterval(-3 * 3_600)
        )
        let solarDawn = SolarSnapshot(remainingSeconds: 12 * 3_600, totalDaylightSeconds: 12 * 3_600,
                                      state: .beforeSunrise, nextSunrise: date(16, 6), nextSunset: date(16, 18))
        let solarNoon = SolarSnapshot(remainingSeconds: 6 * 3_600, totalDaylightSeconds: 12 * 3_600,
                                      state: .daylight, nextSunrise: nil, nextSunset: date(16, 18))
        let solarSunset = SolarSnapshot(remainingSeconds: 5 * 60, totalDaylightSeconds: 12 * 3_600,
                                        state: .daylight, nextSunrise: nil, nextSunset: date(16, 18))
        let solarNight = SolarSnapshot(remainingSeconds: 0, totalDaylightSeconds: 12 * 3_600,
                                       state: .afterSunset, nextSunrise: date(17, 6), nextSunset: date(16, 18))
        func model(_ computer: Double, _ solar: SolarSnapshot?, _ location: String, lastKnown: Bool = false,
                   away: Bool = false, now: Date = noon) -> OutsideModel {
            OutsideModel(computer: computer, solar: solar, locationName: location, isLastKnown: lastKnown, isAway: away, now: now)
        }
        let cases: [(String, OutsideModel, OutsideScreen, String, Bool, [CityCandidate])] = [
            ("main-share", model(4 * 3_600, solarDaylight, "Brooklyn, NY"), .main, "", false, []),
            ("main-hollow", model(0, solarDaylight, "Brooklyn, NY"), .main, "", false, []),
            ("main-solid", model(4 * 3_600, solarAfterSunset, "Brooklyn, NY", away: true, now: night), .main, "", false, []),
            ("main-empty", model(0, solarAfterSunset, "Brooklyn, NY", now: night), .main, "", false, []),
            ("main-unknown", model(23 * 3_600 + 59 * 60, nil, "Location needed"), .main, "Allow location to find your daylight.", false, []),
            ("main-long", model(23 * 3_600 + 59 * 60, SolarSnapshot(remainingSeconds: 23 * 3_600 + 59 * 60, totalDaylightSeconds: 24 * 3_600, state: .polarDay, nextSunrise: nil, nextSunset: nil), "Last known location", lastKnown: true), .main, "", false, []),
            ("setup", model(0, nil, ""), .setup, "Your location is used to estimate sunrise and sunset.", false, []),
            ("setup-error", model(0, nil, ""), .setup, "Location permission is off. You can choose a city instead.", false, []),
            ("settings", model(82_800, solarDaylight, "Current location", lastKnown: true), .settings, "", false, []),
            ("city-error", model(0, nil, ""), .city, "Couldn't find that city. Check your connection and try a city and country.", false, []),
            ("city-candidates", model(0, nil, ""), .city, "Confirm your city below.", false, [CityCandidate(name: "Portland, Oregon, US", latitude: 45.52, longitude: -122.68), CityCandidate(name: "Portland, Maine, US", latitude: 43.66, longitude: -70.25)]),
            ("atmosphere-dawn", model(2 * 3_600, solarDawn, "Brooklyn, NY", now: dawn), .main, "", false, []),
            ("atmosphere-noon", model(5 * 3_600, solarNoon, "Brooklyn, NY", now: noon), .main, "", false, []),
            ("atmosphere-sunset", model(7 * 3_600, solarSunset, "Brooklyn, NY", now: sunset), .main, "", false, []),
            ("atmosphere-night", model(8 * 3_600, solarNight, "Brooklyn, NY", now: night), .main, "", false, []),
            ("atmosphere-next-day", model(1 * 3_600, solarNoon, "Brooklyn, NY", now: nextDayNoon), .main, "", false, [])
        ]

        for appearance in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            for item in cases {
                let backing = PreviewBackdrop(frame: NSRect(x: 0, y: 0, width: 360, height: 400))
                backing.appearance = NSAppearance(named: appearance.1)
                let glass = NSVisualEffectView(frame: backing.bounds)
                glass.material = .popover
                glass.blendingMode = .behindWindow
                glass.state = .active
                glass.autoresizingMask = [.width, .height]
                glass.appearance = backing.appearance
                backing.addSubview(glass)
                let view = OutsideView(frame: glass.bounds)
                view.autoresizingMask = [.width, .height]
                view.appearance = backing.appearance
                glass.addSubview(view)
                view.render(model: item.1, screen: item.2, locationMessage: item.3, isRequesting: item.4, candidates: item.5, loginEnabled: false)
                backing.setFrameSize(view.preferredSize)
                glass.frame = backing.bounds
                view.frame = glass.bounds
                try png(of: backing).write(to: directory.appendingPathComponent("\(item.0)-\(appearance.0).png"))
            }
            let backing = PreviewBackdrop(frame: NSRect(x: 0, y: 0, width: 360, height: 304))
            backing.appearance = NSAppearance(named: appearance.1)
            let glass = NSVisualEffectView(frame: backing.bounds)
            glass.material = .popover
            glass.blendingMode = .behindWindow
            glass.state = .active
            glass.appearance = backing.appearance
            backing.addSubview(glass)
            let view = OutsideView(frame: glass.bounds)
            view.autoresizingMask = [.width, .height]
            view.appearance = backing.appearance
            view.previewReducedTransparency = true
            glass.addSubview(view)
            view.render(model: model(4 * 3_600, solarNoon, "Brooklyn, NY", now: noon), screen: .main,
                        locationMessage: "", isRequesting: false, candidates: [], loginEnabled: false)
            backing.setFrameSize(view.preferredSize)
            glass.frame = backing.bounds
            view.frame = glass.bounds
            try png(of: backing).write(to: directory.appendingPathComponent("reduced-transparency-\(appearance.0).png"))
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
