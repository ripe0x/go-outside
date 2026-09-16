import Foundation

/// Lightweight, dependency-free regression checks for ActivityTracker and TodayStore.
func runAccountingTests() {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(secondsFromGMT: 0)!

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0, calendar: Calendar = utc) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    func reading(_ now: Date, _ uptime: Double, idle: Double = 0, sleep: Bool = false, display: Bool = false, session: Bool = true) -> ActivitySample {
        ActivitySample(now: now, uptime: uptime, idleSeconds: idle, systemSleeping: sleep, displaySleeping: display, sessionActive: session)
    }

    let start = date(2026, 9, 16)
    var tracker = ActivityTracker(date: start, calendar: utc)
    tracker.sample(reading(start, 0), calendar: utc)
    for second in 1...120 {
        tracker.sample(reading(start.addingTimeInterval(Double(second)), Double(second)), calendar: utc)
    }
    precondition(tracker.computerSeconds == 120)

    tracker.sample(reading(start.addingTimeInterval(121), 121, idle: 59), calendar: utc)
    tracker.sample(reading(start.addingTimeInterval(122), 122, idle: 60.5), calendar: utc)
    precondition(abs(tracker.computerSeconds - 122) < 0.001)
    tracker.sample(reading(start.addingTimeInterval(123), 123, idle: 61), calendar: utc)
    precondition(abs(tracker.computerSeconds - 122) < 0.001)
    tracker.sample(reading(start.addingTimeInterval(124), 124, idle: 0), calendar: utc)
    precondition(abs(tracker.computerSeconds - 122) < 0.001) // away resume is free
    tracker.sample(reading(start.addingTimeInterval(125), 125, idle: 0), calendar: utc)
    precondition(abs(tracker.computerSeconds - 123) < 0.001)

    // Keep the Mac awake and session active for an hour of unattended work.
    // Only the initial reading grace can count; output/CPU work is not input.
    var unattended = ActivityTracker(seconds: 120, date: start, calendar: utc)
    unattended.sample(reading(start, 0), calendar: utc)
    for second in 1...3_600 {
        let elapsed = Double(second)
        unattended.sample(reading(start.addingTimeInterval(elapsed), elapsed, idle: elapsed), calendar: utc)
    }
    precondition(unattended.computerSeconds == 180 && unattended.isAway,
                 "An awake Mac must stop counting after 60 seconds without hardware input")
    unattended.sample(reading(start.addingTimeInterval(3_601), 3_601), calendar: utc)
    precondition(unattended.computerSeconds == 180, "Returning must not charge the unattended interval")
    unattended.sample(reading(start.addingTimeInterval(3_602), 3_602), calendar: utc)
    precondition(unattended.computerSeconds == 181 && !unattended.isAway)

    var overlapping = ActivityTracker(date: start, calendar: utc)
    overlapping.sample(reading(start, 0), calendar: utc)
    overlapping.sample(reading(start.addingTimeInterval(1), 1, sleep: true), calendar: utc)
    overlapping.sample(reading(start.addingTimeInterval(2), 2, sleep: true, display: true, session: false), calendar: utc)
    overlapping.sample(reading(start.addingTimeInterval(3), 3, display: true, session: false), calendar: utc)
    overlapping.sample(reading(start.addingTimeInterval(4), 4), calendar: utc)
    overlapping.sample(reading(start.addingTimeInterval(5), 5), calendar: utc)
    precondition(overlapping.computerSeconds == 1)

    let midnight = date(2026, 9, 17, 0, 0, 0)
    var midnightTracker = ActivityTracker(seconds: 5, date: midnight.addingTimeInterval(-1), calendar: utc)
    midnightTracker.sample(reading(midnight.addingTimeInterval(-1), 0), calendar: utc)
    midnightTracker.sample(reading(midnight.addingTimeInterval(1), 2), calendar: utc)
    precondition(midnightTracker.computerSeconds == 1)

    // DST days have 23 and 25 real hours; midnight still comes from Calendar.
    var eastern = Calendar(identifier: .gregorian)
    eastern.timeZone = TimeZone(identifier: "America/New_York")!
    for (year, month, day, duration) in [(2026, 3, 8, 82_800.0), (2026, 11, 1, 90_000.0)] {
        let localStart = date(year, month, day, 23, 59, 59, calendar: eastern)
        let nextMidnight = eastern.date(byAdding: .second, value: 2, to: localStart)!
        precondition(eastern.dateInterval(of: .day, for: localStart)?.duration == duration)
        var dstTracker = ActivityTracker(date: localStart, calendar: eastern)
        dstTracker.sample(reading(localStart, 10), calendar: eastern)
        dstTracker.sample(reading(nextMidnight, 12), calendar: eastern)
        precondition(dstTracker.computerSeconds == 1)
    }

    var gapAndClock = ActivityTracker(date: start, calendar: utc)
    gapAndClock.sample(reading(start, 0), calendar: utc)
    gapAndClock.sample(reading(start.addingTimeInterval(4), 4), calendar: utc)
    precondition(gapAndClock.computerSeconds == 0)
    gapAndClock.sample(reading(start.addingTimeInterval(5), 5), calendar: utc)
    precondition(gapAndClock.computerSeconds == 1)
    gapAndClock.sample(reading(start.addingTimeInterval(3_605), 6), calendar: utc)
    precondition(gapAndClock.computerSeconds == 1)

    var invalidIdle = ActivityTracker(date: start, calendar: utc)
    invalidIdle.sample(reading(start, 0), calendar: utc)
    invalidIdle.sample(reading(start.addingTimeInterval(1), 1, idle: -1), calendar: utc)
    precondition(invalidIdle.computerSeconds == 0 && invalidIdle.isAway)

    let suite = "go.outside.accounting.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = TodayStore(defaults: defaults)
    store.save(seconds: 42.5, now: start, calendar: utc)
    precondition(store.load(now: start, calendar: utc) == 42.5)
    precondition(store.load(now: start.addingTimeInterval(86_400), calendar: utc) == 0)
    defaults.set("not a number", forKey: "go.outside.today.seconds")
    precondition(store.load(now: start, calendar: utc) == 0)
    defaults.set(99_999_999.0, forKey: "go.outside.today.seconds")
    precondition(store.load(now: start, calendar: utc) == 0)
    defaults.set(true, forKey: "go.outside.today.seconds")
    precondition(store.load(now: start, calendar: utc) == 0)
    store.save(seconds: 99_999_999.0, now: start, calendar: utc)
    precondition(store.load(now: start, calendar: utc) == 86_400)
    print("PASS: active/away accounting, unattended hour, return, lifecycle, clock and persistence")
}
