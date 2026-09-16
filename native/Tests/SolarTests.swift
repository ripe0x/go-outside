import Foundation

/// Lightweight checks invoked by the native build's self-test target.
/// They intentionally use no XCTest so `build.sh` can compile a temporary main
/// which calls `runSolarTests()` alongside this file.
func runSolarTests() {
    testIndependentReferences()
    testBeforeSunriseAndAfterSunset()
    testPolarConditions()
    testTimezoneMismatchAndPolarSolarDate()
    testDSTCalendarDaysAndFiniteValues()
}

private func testIndependentReferences() {
    // Fixed US Naval Observatory one-day API reference fixtures, captured
    // 2026-09-16. They are embedded values, so tests remain fully offline.
    // https://aa.usno.navy.mil/api/rstt/oneday
    assertSolarReference(
        name: "Brooklyn",
        timeZone: "America/New_York",
        date: (2026, 9, 16),
        latitude: 40.68,
        longitude: -73.94,
        sunrise: (6, 38),
        sunset: (19, 3)
    )
    assertSolarReference(
        name: "Quito",
        timeZone: "America/Guayaquil",
        date: (2026, 3, 20),
        latitude: -0.18,
        longitude: -78.47,
        sunrise: (6, 18),
        sunset: (18, 25)
    )
    assertSolarReference(
        name: "London",
        timeZone: "Europe/London",
        date: (2026, 6, 21),
        latitude: 51.5,
        longitude: -0.12,
        sunrise: (4, 43),
        sunset: (21, 21)
    )
    assertSolarReference(
        name: "Tokyo",
        timeZone: "Asia/Tokyo",
        date: (2026, 9, 16),
        latitude: 35.68,
        longitude: 139.69,
        sunrise: (5, 24),
        sunset: (17, 48)
    )
}

private func testBeforeSunriseAndAfterSunset() {
    let calendar = gregorianCalendar("America/New_York")
    let beforeSunrise = SolarCalculator.snapshot(
        at: localDate(calendar, 2026, 9, 16, 5, 0),
        latitude: 40.68,
        longitude: -73.94,
        calendar: calendar
    )
    solarCheck(beforeSunrise.state == .beforeSunrise, "5 AM Brooklyn should be before sunrise")
    solarCheck(beforeSunrise.remainingSeconds > 12 * 3_600, "before sunrise should include daylight still to come")
    solarCheck(abs(beforeSunrise.remainingSeconds - beforeSunrise.totalDaylightSeconds) < 1, "before sunrise must exclude dark hours")

    let afterSunset = SolarCalculator.snapshot(
        at: localDate(calendar, 2026, 9, 16, 21, 0),
        latitude: 40.68,
        longitude: -73.94,
        calendar: calendar
    )
    solarCheck(afterSunset.state == .afterSunset, "9 PM Brooklyn should be after sunset")
    solarCheck(afterSunset.remainingSeconds == 0, "after sunset should have no remaining daylight")
    solarCheck(afterSunset.nextSunset != nil, "after sunset should retain today's sunset for UI context")
    if let sunset = afterSunset.nextSunset {
        solarCheck(calendar.isDate(sunset, inSameDayAs: localDate(calendar, 2026, 9, 16, 12, 0)), "after-sunset context must be today's sunset, not tomorrow's")
        solarCheck(sunset < localDate(calendar, 2026, 9, 16, 21, 0), "after-sunset context should already have passed")
    }
}

private func testPolarConditions() {
    let oslo = gregorianCalendar("Europe/Oslo")
    let polarDay = SolarCalculator.snapshot(
        at: localDate(oslo, 2026, 6, 21, 12, 0),
        latitude: 69.6492,
        longitude: 18.9553,
        calendar: oslo
    )
    solarCheck(polarDay.state == .polarDay, "Tromsø at the June solstice should be polar day")
    solarCheck(abs(polarDay.totalDaylightSeconds - 86_400) < 1, "polar day should fill the whole local day")
    solarCheck(polarDay.nextSunrise == nil && polarDay.nextSunset == nil, "polar day has no crossing events")

    let polarNight = SolarCalculator.snapshot(
        at: localDate(oslo, 2026, 12, 21, 12, 0),
        latitude: 69.6492,
        longitude: 18.9553,
        calendar: oslo
    )
    solarCheck(polarNight.state == .polarNight, "Tromsø at the December solstice should be polar night")
    solarCheck(polarNight.totalDaylightSeconds == 0 && polarNight.remainingSeconds == 0, "polar night should have no daylight")
}

private func testTimezoneMismatchAndPolarSolarDate() {
    let newYork = gregorianCalendar("America/New_York")
    let tokyoInNewYorkDay = SolarCalculator.snapshot(
        at: localDate(newYork, 2026, 9, 16, 1, 0),
        latitude: 35.68,
        longitude: 139.69,
        calendar: newYork
    )
    solarCheck(tokyoInNewYorkDay.state == .daylight, "Tokyo sunlight should remain daylight after intersecting a New York calendar day")
    solarCheck(tokyoInNewYorkDay.totalDaylightSeconds > 12 * 3_600 && tokyoInNewYorkDay.totalDaylightSeconds < 13 * 3_600, "a mismatched clock day must retain both intersecting Tokyo daylight windows")
    solarCheck(tokyoInNewYorkDay.remainingSeconds > 11 * 3_600 && tokyoInNewYorkDay.remainingSeconds < 12 * 3_600, "remaining daylight must include the later remote-date sunrise window")

    // At this instant the Mac UTC date is 21 October, while longitude +179°
    // makes the current solar date 22 October. At 80°N the 21st still has a
    // few minutes of intersecting light, but the actual current solar date is
    // polar night. This catches choosing an adjacent candidate date for state.
    let utc = gregorianCalendar("GMT")
    let boundary = SolarCalculator.snapshot(
        at: localDate(utc, 2024, 10, 21, 13, 0),
        latitude: 80,
        longitude: 179,
        calendar: utc
    )
    solarCheck(boundary.state == .polarNight, "state must use the current longitude-shifted solar date")
    solarCheck(boundary.totalDaylightSeconds > 0 && boundary.remainingSeconds == 0, "neighboring intervals may overlap today without changing the current polar-night state")
}

private func testDSTCalendarDaysAndFiniteValues() {
    let newYork = gregorianCalendar("America/New_York")
    let shortDay = localDate(newYork, 2026, 3, 8, 12, 0)
    let longDay = localDate(newYork, 2026, 11, 1, 12, 0)
    let shortDuration = newYork.dateInterval(of: .day, for: shortDay)!.duration
    let longDuration = newYork.dateInterval(of: .day, for: longDay)!.duration
    solarCheck(shortDuration == 23 * 3_600 && longDuration == 25 * 3_600, "fixtures must exercise 23- and 25-hour calendar days")

    for date in [shortDay, longDay] {
        let snapshot = SolarCalculator.snapshot(at: date, latitude: 40.68, longitude: -73.94, calendar: newYork)
        let dayDuration = newYork.dateInterval(of: .day, for: date)!.duration
        solarCheck(snapshot.totalDaylightSeconds.isFinite && snapshot.remainingSeconds.isFinite, "solar values must never be NaN or infinity")
        solarCheck(snapshot.totalDaylightSeconds >= 0 && snapshot.totalDaylightSeconds <= dayDuration, "daylight must stay inside its DST-aware calendar day")
        solarCheck(snapshot.remainingSeconds >= 0 && snapshot.remainingSeconds <= dayDuration, "remaining daylight must stay inside its DST-aware calendar day")
    }
}

private func assertSolarReference(
    name: String,
    timeZone: String,
    date: (Int, Int, Int),
    latitude: Double,
    longitude: Double,
    sunrise: (Int, Int),
    sunset: (Int, Int)
) {
    let calendar = gregorianCalendar(timeZone)
    let midnight = localDate(calendar, date.0, date.1, date.2, 0, 0)
    let snapshot = SolarCalculator.snapshot(at: midnight, latitude: latitude, longitude: longitude, calendar: calendar)
    let expectedSunrise = localDate(calendar, date.0, date.1, date.2, sunrise.0, sunrise.1)
    let expectedSunset = localDate(calendar, date.0, date.1, date.2, sunset.0, sunset.1)
    solarCheck(snapshot.nextSunrise != nil && snapshot.nextSunset != nil, "\(name) should have ordinary sunrise and sunset")
    if let actualSunrise = snapshot.nextSunrise, let actualSunset = snapshot.nextSunset {
        solarCheck(abs(actualSunrise.timeIntervalSince(expectedSunrise)) <= 120, "\(name) sunrise must agree with USNO within two minutes")
        solarCheck(abs(actualSunset.timeIntervalSince(expectedSunset)) <= 120, "\(name) sunset must agree with USNO within two minutes")
    }
}

private func gregorianCalendar(_ timeZoneID: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZoneID)!
    return calendar
}

private func localDate(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private func solarCheck(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String) {
    precondition(condition(), message())
}
