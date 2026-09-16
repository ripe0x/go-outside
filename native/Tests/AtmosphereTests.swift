import AppKit
import Foundation

func runAtmosphereTests() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let dayStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16))!
    let sunrise = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 6))!
    let sunset = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 18))!
    let total = 12 * 3_600.0

    let midday = DaylightAtmosphere.configuration(
        at: dayStart.addingTimeInterval(12 * 3_600),
        solar: solar(total: total, remaining: 6 * 3_600, state: .daylight, sunrise: nil, sunset: sunset),
        calendar: calendar
    )
    let repeatedMidday = DaylightAtmosphere.configuration(
        at: dayStart.addingTimeInterval(12 * 3_600),
        solar: solar(total: total, remaining: 6 * 3_600, state: .daylight, sunrise: nil, sunset: sunset),
        calendar: calendar
    )
    atmosphereCheck(midday == repeatedMidday, "The same date and instant must produce the same atmosphere")
    atmosphereCheck(abs(midday.phase - 0.5) < 0.0001, "Normal solar noon should map to phase .5")

    let dusk = DaylightAtmosphere.configuration(
        at: sunset.addingTimeInterval(-60),
        solar: solar(total: total, remaining: 60, state: .daylight, sunrise: nil, sunset: sunset),
        calendar: calendar
    )
    atmosphereCheck(dusk.phase > 0.74 && dusk.phase < 0.75, "Dusk must approach the sunset phase")
    atmosphereCheck(midday.radius > dusk.radius && midday.intensity > dusk.intensity, "Noon must be broader and brighter than dusk")
    atmosphereCheck(dusk.stretchX > dusk.stretchY, "Dusk must become a low, elongated horizon field")

    let preSunrise = DaylightAtmosphere.configuration(
        at: sunrise.addingTimeInterval(-1),
        solar: solar(total: total, remaining: total, state: .beforeSunrise, sunrise: sunrise, sunset: sunset),
        calendar: calendar
    )
    let atSunrise = DaylightAtmosphere.configuration(
        at: sunrise,
        solar: solar(total: total, remaining: total, state: .daylight, sunrise: nil, sunset: sunset),
        calendar: calendar
    )
    let atSunset = DaylightAtmosphere.configuration(
        at: sunset,
        solar: solar(total: total, remaining: 0, state: .afterSunset, sunrise: nil, sunset: sunset),
        calendar: calendar
    )
    atmosphereCheck(abs(preSunrise.phase - atSunrise.phase) < 0.001, "Phase must remain continuous through sunrise")
    atmosphereCheck(abs(atSunset.phase - 0.75) < 0.0001, "Phase must remain continuous at sunset")

    // Exercise the same boundaries with real calculator snapshots, where the
    // daytime `nextSunrise` is tomorrow rather than today's sunrise.
    let calculatorEarly = SolarCalculator.snapshot(
        at: dayStart.addingTimeInterval(5 * 3_600),
        latitude: 40.68,
        longitude: -73.94,
        calendar: calendar
    )
    if let calculatedSunrise = calculatorEarly.nextSunrise {
        let actualBeforeSunrise = SolarCalculator.snapshot(
            at: calculatedSunrise.addingTimeInterval(-1),
            latitude: 40.68,
            longitude: -73.94,
            calendar: calendar
        )
        let actualAtSunrise = SolarCalculator.snapshot(
            at: calculatedSunrise,
            latitude: 40.68,
            longitude: -73.94,
            calendar: calendar
        )
        let beforeConfiguration = DaylightAtmosphere.configuration(at: calculatedSunrise.addingTimeInterval(-1), solar: actualBeforeSunrise, calendar: calendar)
        let sunriseConfiguration = DaylightAtmosphere.configuration(at: calculatedSunrise, solar: actualAtSunrise, calendar: calendar)
        atmosphereCheck(abs(beforeConfiguration.phase - sunriseConfiguration.phase) < 0.001, "Real solar snapshots must remain continuous through sunrise")
        if let calculatedSunset = actualAtSunrise.nextSunset {
            let actualBeforeSunset = SolarCalculator.snapshot(
                at: calculatedSunset.addingTimeInterval(-1),
                latitude: 40.68,
                longitude: -73.94,
                calendar: calendar
            )
            let actualAtSunset = SolarCalculator.snapshot(
                at: calculatedSunset,
                latitude: 40.68,
                longitude: -73.94,
                calendar: calendar
            )
            let sunsetBeforeConfiguration = DaylightAtmosphere.configuration(at: calculatedSunset.addingTimeInterval(-1), solar: actualBeforeSunset, calendar: calendar)
            let sunsetConfiguration = DaylightAtmosphere.configuration(at: calculatedSunset, solar: actualAtSunset, calendar: calendar)
            atmosphereCheck(abs(sunsetBeforeConfiguration.phase - sunsetConfiguration.phase) < 0.001, "Real solar snapshots must remain continuous through sunset")
        }
    } else {
        preconditionFailure("Brooklyn fixture must have a sunrise")
    }

    let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)!
    let variation = DaylightAtmosphere.configuration(at: nextDay.addingTimeInterval(12 * 3_600), solar: nil, calendar: calendar)
    atmosphereCheck(midday.dailySeed != variation.dailySeed, "Each calendar date needs a stable distinct seed")
    for configuration in [midday, variation] {
        atmosphereCheck(configuration.centerX >= 0.42 && configuration.centerX <= 0.58, "Daily horizontal drift must stay bounded")
        atmosphereCheck(configuration.centerY >= 0 && configuration.centerY <= 1, "Field center must stay in the artwork region")
        atmosphereCheck(configuration.radius > 0 && configuration.radius <= 1, "Field radius must remain bounded")
        atmosphereCheck(configuration.stretchX > 0 && configuration.stretchY > 0 && abs(configuration.angle) < 0.3, "Daily shape variation must remain subtle and valid")
    }

    let unknown = DaylightAtmosphere.configuration(at: dayStart.addingTimeInterval(12 * 3_600), solar: nil, calendar: calendar)
    atmosphereCheck(abs(unknown.phase - 0.5) < 0.0001, "Unknown location uses only the Mac wall-clock phase")
    let night = DaylightAtmosphere.configuration(at: dayStart, solar: nil, calendar: calendar)
    atmosphereCheck(night.radius < unknown.radius && night.intensity < unknown.intensity, "Night must be dimmer and narrower than noon")
    let noonPixels = atmospherePixels(midday)
    let nightPixels = atmospherePixels(night)
    let duskPixels = atmospherePixels(dusk)
    atmosphereCheck(noonPixels.mean > nightPixels.mean, "Rendered noon artwork must be brighter than rendered night artwork")
    atmosphereCheck(abs(noonPixels.centroidY - duskPixels.centroidY) > 8, "Rendered dusk and noon volumes must occupy visibly different shapes")
    atmosphereCheck(noonPixels.chroma > 0.12 && duskPixels.chroma > 0.12, "Luminous volumes must retain visible cyan and warm color contrast")

    let polarDay = DaylightAtmosphere.configuration(
        at: dayStart.addingTimeInterval(12 * 3_600),
        solar: solar(total: 86_400, remaining: 43_200, state: .polarDay, sunrise: nil, sunset: nil),
        calendar: calendar
    )
    let polarNight = DaylightAtmosphere.configuration(
        at: dayStart.addingTimeInterval(12 * 3_600),
        solar: solar(total: 0, remaining: 0, state: .polarNight, sunrise: nil, sunset: nil),
        calendar: calendar
    )
    atmosphereCheck(polarDay.intensity > polarNight.intensity && polarDay.radius > polarNight.radius, "Polar conditions must remain visually distinct")
    for configuration in [midday, dusk, preSunrise, atSunrise, atSunset, unknown, night, polarDay, polarNight] {
        atmosphereCheck(
            configuration.phase.isFinite && configuration.centerX.isFinite && configuration.centerY.isFinite
                && configuration.radius.isFinite && configuration.stretchX.isFinite && configuration.stretchY.isFinite
                && configuration.angle.isFinite && configuration.intensity.isFinite,
            "Atmosphere geometry and brightness must remain finite"
        )
    }
    print("PASS: deterministic colored atmosphere phase, light volumes, transitions and polar fallbacks")
}

private func solar(
    total: Double,
    remaining: Double,
    state: SolarState,
    sunrise: Date?,
    sunset: Date?
) -> SolarSnapshot {
    SolarSnapshot(
        remainingSeconds: remaining,
        totalDaylightSeconds: total,
        state: state,
        nextSunrise: sunrise,
        nextSunset: sunset
    )
}

private func atmosphereCheck(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String) {
    precondition(condition(), message())
}

private func atmospherePixels(_ configuration: AtmosphereConfiguration) -> (mean: CGFloat, centroidY: CGFloat, chroma: CGFloat) {
    let size = NSSize(width: 180, height: 96)
    let image = NSImage(size: size)
    image.lockFocus()
    DaylightAtmosphere.draw(configuration, in: NSRect(origin: .zero, size: size), dark: false, reducedTransparency: false)
    image.unlockFocus()
    guard let bitmap = image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)) else {
        preconditionFailure("Atmosphere artwork must render to a bitmap")
    }
    var luminanceTotal: CGFloat = 0
    var weightedY: CGFloat = 0
    var chromaTotal: CGFloat = 0
    var luminousCount = 0
    let count = bitmap.pixelsWide * bitmap.pixelsHigh
    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
            let red = color?.redComponent ?? 0
            let green = color?.greenComponent ?? 0
            let blue = color?.blueComponent ?? 0
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            luminanceTotal += luminance
            weightedY += luminance * CGFloat(y)
            // Measure the colored light separately from intentional black space.
            if luminance > 0.06 {
                chromaTotal += max(red, green, blue) - min(red, green, blue)
                luminousCount += 1
            }
        }
    }
    return (luminanceTotal / CGFloat(count), weightedY / max(luminanceTotal, 0.0001), chromaTotal / CGFloat(max(1, luminousCount)))
}
