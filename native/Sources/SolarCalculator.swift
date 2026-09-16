import Foundation

/// The relation between `at` and daylight in its Mac-calendar day.
enum SolarState: String {
    case daylight
    case beforeSunrise
    case afterSunset
    case polarDay
    case polarNight
}

/// A daylight estimate for one Mac-calendar day.
///
/// `remainingSeconds` is the union of daylight intervals in `[at, next local
/// midnight)`. `totalDaylightSeconds` is the same union over the whole local
/// calendar day. Thus, before sunrise, remaining time is the coming daylight,
/// rather than the time until sunset. A polar day uses the calendar day's real
/// duration, which can be 23 or 25 hours at a DST transition.
///
/// `nextSunrise` is the next calculated sunrise at or after `at`. `nextSunset`
/// is the sunset relevant to the current calendar day: an upcoming sunset when
/// one remains, otherwise that day's latest sunset. This makes it useful for an
/// after-sunset UI even though the event has already passed. They are `nil`
/// when no crossing is found in the nearby solar dates, as in sustained polar
/// conditions.
struct SolarSnapshot {
    let remainingSeconds: Double
    let totalDaylightSeconds: Double
    let state: SolarState
    let nextSunrise: Date?
    let nextSunset: Date?
}

/// Local, deterministic sunrise and sunset estimates using NOAA's published
/// Meeus-based equations and the conventional 90.833 degree zenith.
///
/// This deliberately has no location, weather, or network dependency. The
/// resulting times are estimates: terrain, buildings, and weather affect the
/// light a person can actually see.
enum SolarCalculator {
    private static let sunriseZenith = 90.833
    private static let secondsPerDay = 86_400.0

    static func snapshot(
        at now: Date,
        latitude: Double,
        longitude: Double,
        calendar: Calendar
    ) -> SolarSnapshot {
        guard latitude.isFinite, longitude.isFinite else {
            return SolarSnapshot(
                remainingSeconds: 0,
                totalDaylightSeconds: 0,
                state: .afterSunset,
                nextSunrise: nil,
                nextSunset: nil
            )
        }

        let latitude = min(90, max(-90, latitude))
        let longitude = normalizedLongitude(longitude)
        guard let localDay = calendar.dateInterval(of: .day, for: now) else {
            return SolarSnapshot(
                remainingSeconds: 0,
                totalDaylightSeconds: 0,
                state: .afterSunset,
                nextSunrise: nil,
                nextSunset: nil
            )
        }

        // Solar events are calculated on Gregorian civil dates, but their
        // resulting instants are intersected with the caller's calendar day.
        // The neighboring dates cover both IANA timezone and longitude offsets.
        var localGregorian = Calendar(identifier: .gregorian)
        localGregorian.timeZone = calendar.timeZone
        let solarDates = candidateSolarDates(around: localDay.start, calendar: calendar)
        let eventDays = solarDates.map { date in
            let components = localGregorian.dateComponents([.year, .month, .day], from: date)
            return solarDay(
                year: components.year ?? 2000,
                month: components.month ?? 1,
                day: components.day ?? 1,
                latitude: latitude,
                longitude: longitude
            )
        }

        var daylightIntervals: [DateInterval] = []
        var sunrises: [Date] = []
        var sunsets: [Date] = []
        for eventDay in eventDays {
            switch eventDay.condition {
            case .normal:
                guard let sunrise = eventDay.sunrise, let sunset = eventDay.sunset else { continue }
                sunrises.append(sunrise)
                sunsets.append(sunset)
                if sunset > sunrise {
                    daylightIntervals.append(DateInterval(start: sunrise, end: sunset))
                }
            case .polarDay:
                // A no-crossing polar day is daylight for the entire local
                // solar date. Its boundary is mean solar midnight, so shift it
                // for longitude instead of treating UTC midnight as the local
                // date boundary. Neighboring dates cover Mac timezone offsets.
                let start = utcMidnight(eventDay.year, eventDay.month, eventDay.day)
                    .addingTimeInterval(-longitude * 240)
                daylightIntervals.append(DateInterval(start: start, duration: secondsPerDay))
            case .polarNight:
                break
            }
        }

        let union = merged(daylightIntervals)
        let total = overlapSeconds(of: union, with: localDay)
        let remainingRange = DateInterval(start: max(now, localDay.start), end: localDay.end)
        let remaining = overlapSeconds(of: union, with: remainingRange)

        let currentSolarDate = now.addingTimeInterval(longitude * 240)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let currentComponents = utcCalendar.dateComponents([.year, .month, .day], from: currentSolarDate)
        let currentCondition = solarDay(
            year: currentComponents.year ?? 2000,
            month: currentComponents.month ?? 1,
            day: currentComponents.day ?? 1,
            latitude: latitude,
            longitude: longitude
        ).condition

        let daylightInCurrentDay = merged(union.compactMap { $0.intersection(with: localDay) })
        let state: SolarState
        switch currentCondition {
        case .polarDay:
            state = .polarDay
        case .polarNight:
            state = .polarNight
        case .normal:
            if daylightInCurrentDay.contains(where: { $0.start <= now && now < $0.end }) {
                state = .daylight
            } else if let firstDaylight = daylightInCurrentDay.first?.start, now < firstDaylight {
                state = .beforeSunrise
            } else {
                state = .afterSunset
            }
        }

        let futureSunrise = sunrises.filter { $0 >= now }.min()
        let upcomingSunset = sunsets.filter { $0 >= now && localDay.contains($0) }.min()
        let todaySunset = sunsets.filter { localDay.contains($0) }.max()
        let relevantSunset = upcomingSunset ?? todaySunset

        return SolarSnapshot(
            remainingSeconds: finiteNonNegative(remaining),
            totalDaylightSeconds: finiteNonNegative(total),
            state: state,
            nextSunrise: futureSunrise,
            nextSunset: relevantSunset
        )
    }

    private enum DayCondition {
        case normal
        case polarDay
        case polarNight
    }

    private struct SolarDay {
        let year: Int
        let month: Int
        let day: Int
        let condition: DayCondition
        let sunrise: Date?
        let sunset: Date?
    }

    private static func candidateSolarDates(around dayStart: Date, calendar: Calendar) -> [Date] {
        (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: dayStart) }
    }

    private static func solarDay(
        year: Int,
        month: Int,
        day: Int,
        latitude: Double,
        longitude: Double
    ) -> SolarDay {
        let julianDay = julianDayAtUTCStart(year: year, month: month, day: day)
        let firstPass = eventMinutesUTC(
            julianDay: julianDay,
            latitude: latitude,
            longitude: longitude,
            sunrise: true
        )

        switch firstPass {
        case .polarDay:
            return SolarDay(year: year, month: month, day: day, condition: .polarDay, sunrise: nil, sunset: nil)
        case .polarNight:
            return SolarDay(year: year, month: month, day: day, condition: .polarNight, sunrise: nil, sunset: nil)
        case let .minutes(initialSunrise):
            let refinedSunrise = refinedEventMinutes(
                initialSunrise,
                julianDay: julianDay,
                latitude: latitude,
                longitude: longitude,
                sunrise: true
            )
            let initialSunset = eventMinutesUTC(
                julianDay: julianDay,
                latitude: latitude,
                longitude: longitude,
                sunrise: false
            )
            guard case let .minutes(sunsetMinutes) = initialSunset else {
                // The same solar date cannot be both normal and polar. This is
                // defensive against floating-point behavior at a transition.
                return SolarDay(year: year, month: month, day: day, condition: .polarNight, sunrise: nil, sunset: nil)
            }
            let refinedSunset = refinedEventMinutes(
                sunsetMinutes,
                julianDay: julianDay,
                latitude: latitude,
                longitude: longitude,
                sunrise: false
            )
            return SolarDay(
                year: year,
                month: month,
                day: day,
                condition: .normal,
                sunrise: utcMidnight(year, month, day).addingTimeInterval(refinedSunrise * 60),
                sunset: utcMidnight(year, month, day).addingTimeInterval(refinedSunset * 60)
            )
        }
    }

    private enum EventResult {
        case minutes(Double)
        case polarDay
        case polarNight
    }

    private static func refinedEventMinutes(
        _ initial: Double,
        julianDay: Double,
        latitude: Double,
        longitude: Double,
        sunrise: Bool
    ) -> Double {
        switch eventMinutesUTC(
            julianDay: julianDay + initial / 1_440,
            latitude: latitude,
            longitude: longitude,
            sunrise: sunrise
        ) {
        case let .minutes(refined):
            return refined
        case .polarDay, .polarNight:
            return initial
        }
    }

    private static func eventMinutesUTC(
        julianDay: Double,
        latitude: Double,
        longitude: Double,
        sunrise: Bool
    ) -> EventResult {
        let centuries = (julianDay - 2_451_545.0) / 36_525
        let equation = equationOfTime(centuries)
        let declination = solarDeclination(centuries)
        let latitudeRadians = radians(latitude)
        let declinationRadians = radians(declination)
        let numerator = cos(radians(sunriseZenith)) - sin(latitudeRadians) * sin(declinationRadians)
        let denominator = cos(latitudeRadians) * cos(declinationRadians)

        guard denominator.isFinite, abs(denominator) > Double.ulpOfOne else {
            // At the exact poles, the declination alone determines whether the
            // sun is continuously above or below the conventional zenith.
            return sin(declinationRadians) * sin(latitudeRadians) > cos(radians(sunriseZenith)) ? .polarDay : .polarNight
        }

        let cosineHourAngle = numerator / denominator
        if cosineHourAngle > 1 { return .polarNight }
        if cosineHourAngle < -1 { return .polarDay }
        let hourAngle = degrees(acos(min(1, max(-1, cosineHourAngle))))
        let solarNoon = 720 - 4 * longitude - equation
        return .minutes(solarNoon + (sunrise ? -4 * hourAngle : 4 * hourAngle))
    }

    private static func equationOfTime(_ centuries: Double) -> Double {
        let obliquity = obliquityCorrection(centuries)
        let eccentricity = eccentricityEarthOrbit(centuries)
        let meanLongitude = geomMeanLongSun(centuries)
        let meanAnomaly = geomMeanAnomalySun(centuries)
        let y = pow(tan(radians(obliquity) / 2), 2)
        let l0 = radians(meanLongitude)
        let m = radians(meanAnomaly)
        let value = y * sin(2 * l0)
            - 2 * eccentricity * sin(m)
            + 4 * eccentricity * y * sin(m) * cos(2 * l0)
            - 0.5 * y * y * sin(4 * l0)
            - 1.25 * eccentricity * eccentricity * sin(2 * m)
        return 4 * degrees(value)
    }

    private static func solarDeclination(_ centuries: Double) -> Double {
        degrees(asin(sin(radians(obliquityCorrection(centuries))) * sin(radians(sunApparentLong(centuries)))))
    }

    private static func geomMeanLongSun(_ centuries: Double) -> Double {
        normalizedDegrees(280.46646 + centuries * (36_000.76983 + 0.0003032 * centuries))
    }

    private static func geomMeanAnomalySun(_ centuries: Double) -> Double {
        357.52911 + centuries * (35_999.05029 - 0.0001537 * centuries)
    }

    private static func eccentricityEarthOrbit(_ centuries: Double) -> Double {
        0.016708634 - centuries * (0.000042037 + 0.0000001267 * centuries)
    }

    private static func sunEqOfCenter(_ centuries: Double) -> Double {
        let meanAnomaly = radians(geomMeanAnomalySun(centuries))
        return sin(meanAnomaly) * (1.914602 - centuries * (0.004817 + 0.000014 * centuries))
            + sin(2 * meanAnomaly) * (0.019993 - 0.000101 * centuries)
            + sin(3 * meanAnomaly) * 0.000289
    }

    private static func sunTrueLong(_ centuries: Double) -> Double {
        geomMeanLongSun(centuries) + sunEqOfCenter(centuries)
    }

    private static func sunApparentLong(_ centuries: Double) -> Double {
        let omega = 125.04 - 1_934.136 * centuries
        return sunTrueLong(centuries) - 0.00569 - 0.00478 * sin(radians(omega))
    }

    private static func meanObliqEcliptic(_ centuries: Double) -> Double {
        let seconds = 21.448 - centuries * (46.815 + centuries * (0.00059 - centuries * 0.001813))
        return 23 + (26 + seconds / 60) / 60
    }

    private static func obliquityCorrection(_ centuries: Double) -> Double {
        meanObliqEcliptic(centuries) + 0.00256 * cos(radians(125.04 - 1_934.136 * centuries))
    }

    private static func julianDayAtUTCStart(year: Int, month: Int, day: Int) -> Double {
        var adjustedYear = year
        var adjustedMonth = month
        if adjustedMonth <= 2 {
            adjustedYear -= 1
            adjustedMonth += 12
        }
        let century = floor(Double(adjustedYear) / 100)
        let correction = 2 - century + floor(century / 4)
        return floor(365.25 * Double(adjustedYear + 4_716))
            + floor(30.6001 * Double(adjustedMonth + 1))
            + Double(day) + correction - 1_524.5
    }

    private static func utcMidnight(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func merged(_ intervals: [DateInterval]) -> [DateInterval] {
        let ordered = intervals.sorted { $0.start < $1.start }
        var result: [DateInterval] = []
        for interval in ordered {
            guard interval.duration.isFinite, interval.duration > 0 else { continue }
            guard let previous = result.last else {
                result.append(interval)
                continue
            }
            if interval.start <= previous.end {
                result[result.count - 1] = DateInterval(start: previous.start, end: max(previous.end, interval.end))
            } else {
                result.append(interval)
            }
        }
        return result
    }

    private static func overlapSeconds(of intervals: [DateInterval], with target: DateInterval) -> Double {
        intervals.reduce(0) { partial, interval in
            guard let overlap = interval.intersection(with: target) else { return partial }
            return partial + overlap.duration
        }
    }

    private static func normalizedLongitude(_ longitude: Double) -> Double {
        let value = longitude.truncatingRemainder(dividingBy: 360)
        return value > 180 ? value - 360 : (value <= -180 ? value + 360 : value)
    }

    private static func normalizedDegrees(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
    private static func finiteNonNegative(_ value: Double) -> Double { value.isFinite ? max(0, value) : 0 }
}
