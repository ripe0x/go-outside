import Foundation

func runPresentationTests() {
    precondition(RatioState.make(computer: 4 * 3600, daylight: 2 * 3600) == .share(2.0 / 3))
    precondition(RatioState.make(computer: 0, daylight: 3600) == .share(0))
    precondition(RatioState.make(computer: 3600, daylight: 0) == .share(1))
    precondition(RatioState.make(computer: 0, daylight: 0) == .empty)
    precondition(RatioState.make(computer: 0, daylight: nil) == .unknown)
    precondition(RatioState.make(computer: -.infinity, daylight: 0) == .unknown)
    precondition(RatioState.make(computer: .greatestFiniteMagnitude, daylight: .greatestFiniteMagnitude) == .unknown)
    precondition(OutsideFormat.duration(59) == "0m")
    precondition(OutsideFormat.duration(0.1, remaining: true) == "1m")
    precondition(OutsideFormat.duration(0, remaining: true) == "0m")
    precondition(OutsideFormat.duration(4 * 3600 + 12 * 60 + 59) == "4h12")
    precondition(OutsideFormat.duration(59 * 60 + 1, remaining: true) == "1h00")
    precondition(OutsideFormat.duration(.nan) == "—")
    precondition(OutsideFormat.duration(.greatestFiniteMagnitude) == "168h00")
    precondition(OutsideFormat.clock(59.9) == "59s")
    precondition(OutsideFormat.clock(59.9, remaining: true) == "1m")
    precondition(OutsideFormat.clock(3599.9, remaining: true) == "1h")
    precondition(OutsideFormat.clock(0.1, remaining: true) == "1s")
    precondition(OutsideFormat.clock(0, remaining: true) == "0s")
    precondition(OutsideFormat.clock(-1) == "0s")
    precondition(OutsideFormat.clock(4 * 3600 + 12 * 60 + 59) == "4h 12m 59s")
    precondition(OutsideFormat.clock(3600 + 12) == "1h 12s")
    precondition(OutsideFormat.clock(34 * 60 + 12) == "34m 12s")
    precondition(OutsideFormat.clock(3600 + 34 * 60 + 12) == "1h 34m 12s")
    precondition(OutsideFormat.accessibleDuration(3600 + 12) == "1 hour 12 seconds")
    precondition(OutsideFormat.accessibleDuration(0) == "0 seconds")
    precondition(OutsideFormat.clock(.nan) == "—")
    precondition(OutsideFormat.clock(.infinity) == "—")
    precondition(OutsideFormat.clock(.greatestFiniteMagnitude) == "168h")
    precondition(OutsideFormat.accessibleDuration(3660) == "1 hour 1 minute")
    precondition(OutsideFormat.accessibleDuration(0.1, remaining: true) == "1 second")
    let evening = Date(timeIntervalSince1970: 1_800_000_000)
    let sunrise = evening.addingTimeInterval(9 * 3600 + 12)
    let sunset = evening.addingTimeInterval(-2 * 3600)
    func model(at now: Date, state: SolarState, remaining: Double = 0, nextSunrise: Date? = sunrise) -> OutsideModel {
        OutsideModel(computer: 4 * 3600, solar: SolarSnapshot(remainingSeconds: remaining, totalDaylightSeconds: 12 * 3600,
                     state: state, nextSunrise: nextSunrise, nextSunset: sunset),
                     locationName: "Test location", isLastKnown: false, isAway: false, now: now)
    }
    let night = model(at: evening, state: .afterSunset)
    precondition(night.solarClock == "9h 12s" && night.solarLabel == "Until sunrise")
    precondition(night.accessibility.contains("9 hours 12 seconds until sunrise"))
    precondition(night.ratio == .share(1), "Sunrise countdown must not be treated as available daylight")
    precondition(model(at: evening.addingTimeInterval(1), state: .afterSunset).solarClock == "9h 11s")
    precondition(model(at: evening.addingTimeInterval(3 * 3600), state: .beforeSunrise, remaining: 12 * 3600).solarClock == "6h 12s")
    precondition(model(at: sunrise.addingTimeInterval(-0.1), state: .beforeSunrise).solarClock == "1s")
    let daylight = model(at: sunrise, state: .daylight, remaining: 12 * 3600)
    precondition(daylight.solarLabel == "Daylight left" && daylight.solarClock == "12h")
    precondition(daylight.accessibility.contains("12 hours of daylight remaining"))
    let polarNight = model(at: evening, state: .polarNight, nextSunrise: nil)
    precondition(polarNight.solarClock == "—" && polarNight.accessibility.contains("Next sunrise is unavailable"))
    let unknown = OutsideModel(computer: 0, solar: nil, locationName: "", isLastKnown: false, isAway: false, now: evening)
    precondition(unknown.solarClock == "—" && !unknown.isNight)

    // Real snapshots exercise the switch at sunset, through midnight, and at sunrise.
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 12))!
    func actual(_ date: Date) -> OutsideModel {
        OutsideModel(computer: 3600, solar: SolarCalculator.snapshot(at: date, latitude: 40.68, longitude: -73.94, calendar: calendar),
                     locationName: "Test location", isLastKnown: false, isAway: false, now: date)
    }
    let actualSunset = actual(date).solar!.nextSunset!
    precondition(!actual(actualSunset.addingTimeInterval(-1)).isNight)
    let afterSunset = actual(actualSunset)
    precondition(afterSunset.isNight && afterSunset.solarSeconds! > 0)
    let actualSunrise = afterSunset.solar!.nextSunrise!
    let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date)!)
    precondition(abs(actual(midnight).solarSeconds! - actualSunrise.timeIntervalSince(midnight)) < 0.01)
    precondition(actual(actualSunrise.addingTimeInterval(-1)).isNight)
    precondition(!actual(actualSunrise).isNight)
    print("PASS: ratio shares, second clocks, sunrise countdown, solar boundaries and spoken precision")
}
