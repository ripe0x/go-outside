import Foundation

/// A point-in-time reading of the activity signals used for computer-time accounting.
struct ActivitySample {
    let now: Date
    let uptime: Double
    let idleSeconds: Double
    let systemSleeping: Bool
    let displaySleeping: Bool
    let sessionActive: Bool
}

/// Counts eligible local computer use for one Mac calendar day.
struct ActivityTracker {
    private struct Day: Equatable {
        let era: Int
        let year: Int
        let month: Int
        let day: Int

        init(_ date: Date, calendar: Calendar) {
            let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
            era = components.era ?? 0
            year = components.year ?? 0
            month = components.month ?? 0
            day = components.day ?? 0
        }
    }

    private let maximumTickInterval = 3.0
    private let idleCutoff = 60.0

    private var day: Day
    private var timeZoneIdentifier: String
    private var previous: ActivitySample?

    private(set) var computerSeconds: Double
    private(set) var isAway: Bool

    init(seconds: Double = 0, date: Date, calendar: Calendar) {
        computerSeconds = seconds.isFinite ? max(0, seconds) : 0
        day = Day(date, calendar: calendar)
        timeZoneIdentifier = calendar.timeZone.identifier
        previous = nil
        isAway = false
    }

    /// Incorporates one activity reading. Time is measured by uptime; wall time only
    /// establishes the local-day boundary.
    mutating func sample(_ sample: ActivitySample, calendar: Calendar) {
        let sampleDay = Day(sample.now, calendar: calendar)
        let timeZoneChanged = calendar.timeZone.identifier != timeZoneIdentifier

        // A timezone change has ambiguous ownership for the interval immediately
        // before it, so begin the new local accounting context at this sample.
        if timeZoneChanged {
            if sampleDay != day {
                computerSeconds = 0
            }
            day = sampleDay
            timeZoneIdentifier = calendar.timeZone.identifier
            previous = sample
            isAway = !isEligible(sample)
            return
        }

        guard let previous else {
            if sampleDay != day {
                computerSeconds = 0
                day = sampleDay
            }
            self.previous = sample
            isAway = !isEligible(sample)
            return
        }

        let uptimeDelta = sample.uptime - previous.uptime
        let wallDelta = sample.now.timeIntervalSince(previous.now)
        let dateChanged = sampleDay != day

        // Uptime makes sleep and wall-clock edits harmless. Require matching wall
        // progress before using wall time to split an otherwise valid tick.
        guard uptimeDelta > 0,
              uptimeDelta <= maximumTickInterval,
              wallDelta >= 0,
              abs(wallDelta - uptimeDelta) <= 0.25 else {
            if dateChanged {
                computerSeconds = 0
                day = sampleDay
            }
            self.previous = sample
            isAway = !isEligible(sample)
            return
        }

        let eligibleSeconds = eligiblePrefix(of: uptimeDelta, from: previous, to: sample)

        if dateChanged {
            // The interval can be safely partitioned by real Date values. This is
            // valid across DST because Calendar supplies the actual local midnight.
            let newDayStart = calendar.startOfDay(for: sample.now)
            let prefixEnding = previous.now.addingTimeInterval(eligibleSeconds)
            let secondsInNewDay = max(0, prefixEnding.timeIntervalSince(newDayStart))
            computerSeconds = min(eligibleSeconds, secondsInNewDay)
            day = sampleDay
        } else {
            computerSeconds += eligibleSeconds
        }

        self.previous = sample
        isAway = !isEligible(sample)
    }

    /// For lifecycle and wall-clock notifications: keep the total and discard any
    /// interval whose beginning is no longer known.
    mutating func resetBaseline() {
        previous = nil
    }

    private func isEligible(_ sample: ActivitySample) -> Bool {
        sample.idleSeconds.isFinite && sample.idleSeconds >= 0 && sample.idleSeconds < idleCutoff &&
            !sample.systemSleeping && !sample.displaySleeping && sample.sessionActive
    }

    /// Returns the countable prefix of a monotonic tick. Hardware/session state must
    /// be good at both endpoints. Idle time is clipped at the 60-second cutoff, so a
    /// tick that crosses it counts only the reading grace that occurred before it.
    private func eligiblePrefix(of delta: Double, from start: ActivitySample, to end: ActivitySample) -> Double {
        guard !start.systemSleeping, !start.displaySleeping, start.sessionActive,
              !end.systemSleeping, !end.displaySleeping, end.sessionActive,
              start.idleSeconds.isFinite, end.idleSeconds.isFinite,
              start.idleSeconds >= 0, end.idleSeconds >= 0,
              start.idleSeconds < idleCutoff else {
            return 0
        }

        guard end.idleSeconds >= idleCutoff else {
            return delta
        }

        return min(delta, max(0, idleCutoff - start.idleSeconds))
    }
}
