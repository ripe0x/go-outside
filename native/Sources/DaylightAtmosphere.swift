import AppKit
import Foundation

/// A deterministic monochrome light field for the popover artwork region.
///
/// `phase` progresses from 0 at local midnight through .25 at sunrise, .5 at
/// solar noon, .75 at sunset, and 1 at the next local midnight. Normal solar
/// snapshots use calculated daylight progress. Without a location it falls
/// back to the Mac wall clock solely to choose decorative artwork.
struct AtmosphereConfiguration: Equatable {
    let phase: CGFloat
    let dailySeed: UInt64
    let centerX: CGFloat
    let centerY: CGFloat
    let radius: CGFloat
    let stretchX: CGFloat
    let stretchY: CGFloat
    let angle: CGFloat
    let intensity: CGFloat
}

/// An opaque black-and-white radial field. It has no timers or random ticks:
/// date-stable variation comes only from `dailySeed`.
enum DaylightAtmosphere {
    static func configuration(
        at now: Date,
        solar: SolarSnapshot?,
        calendar: Calendar = .current
    ) -> AtmosphereConfiguration {
        let day = calendar.dateInterval(of: .day, for: now)
            ?? DateInterval(start: now, duration: 86_400)
        let wallPhase = clamped(now.timeIntervalSince(day.start) / day.duration)
        let phase = phase(at: now, solar: solar, day: day, wallPhase: wallPhase)
        let seed = dateSeed(for: now, calendar: calendar)
        let xVariation = (unit(seed) - 0.5) * 0.06
        let angleVariation = (unit(seed &* 0x9E37_79B9_7F4A_7C15) - 0.5) * 0.12

        let dayProgress = clamped((phase - 0.25) / 0.5)
        let daylight = sin(.pi * dayProgress)
        let dawn = bell(phase, centeredAt: 0.25, width: 0.125)
        let dusk = bell(phase, centeredAt: 0.75, width: 0.135)
        let horizon = max(dawn, dusk)
        let polarDay = solar?.state == .polarDay
        let polarNight = solar?.state == .polarNight

        if polarDay {
            return AtmosphereConfiguration(
                phase: phase,
                dailySeed: seed,
                centerX: 0.5 + xVariation,
                centerY: 0.56,
                radius: 0.80,
                stretchX: 1.22,
                stretchY: 1.06,
                angle: angleVariation,
                intensity: 0.84
            )
        }
        if polarNight {
            return AtmosphereConfiguration(
                phase: phase,
                dailySeed: seed,
                centerX: 0.5 + xVariation * 0.45,
                centerY: 0.68,
                radius: 0.26,
                stretchX: 0.62,
                stretchY: 0.74,
                angle: angleVariation * 0.4,
                intensity: 0.30
            )
        }

        // Dawn and dusk pull a thin, tilted field down toward the horizon.
        // At noon it broadens and rises; overnight it narrows and dims.
        return AtmosphereConfiguration(
            phase: phase,
            dailySeed: seed,
            centerX: clamped(0.5 + xVariation + 0.035 * sin((phase - 0.5) * .pi)),
            centerY: clamped(0.68 * (1 - daylight) + 0.58 * daylight - 0.52 * horizon),
            radius: 0.26 + 0.54 * daylight + 0.17 * horizon,
            stretchX: 0.62 + 0.58 * daylight + 0.86 * horizon,
            stretchY: 0.74 + 0.34 * daylight - 0.42 * horizon,
            angle: angleVariation + 0.14 * sin((phase - 0.5) * .pi),
            intensity: clamped(0.30 + 0.54 * daylight + 0.31 * horizon)
        )
    }

    /// Paint only the supplied artwork rectangle, before the separate glass
    /// information region. This remains opaque under Reduce Transparency:
    /// the field is decoration, not a transparency cue.
    static func draw(
        _ configuration: AtmosphereConfiguration,
        in bounds: NSRect,
        dark: Bool,
        reducedTransparency: Bool
    ) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        _ = reducedTransparency
        // The artwork has one visual language in both appearances: a near-black
        // field with white light. This makes solar intensity literal, with
        // brighter rendered pixels at noon than at night.
        let background = NSColor(calibratedWhite: 0.045, alpha: 1)
        background.setFill()
        bounds.fill()

        let core = NSColor(calibratedWhite: 1, alpha: 0.88 * configuration.intensity)
        let transparent = core.withAlphaComponent(0)
        guard let context = NSGraphicsContext.current?.cgContext,
              let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceGray(),
                colors: [core.cgColor, transparent.cgColor] as CFArray,
                locations: [0, 1]
              ) else { return }

        let center = NSPoint(
            x: bounds.minX + bounds.width * configuration.centerX,
            y: bounds.minY + bounds.height * configuration.centerY
        )
        let radius = max(bounds.width, bounds.height) * configuration.radius
        context.saveGState()
        context.addRect(bounds)
        context.clip()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: configuration.angle)
        context.scaleBy(x: configuration.stretchX, y: configuration.stretchY)
        context.drawRadialGradient(
            gradient,
            startCenter: .zero,
            startRadius: 0,
            endCenter: .zero,
            endRadius: radius,
            options: [.drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    private static func phase(at now: Date, solar: SolarSnapshot?, day: DateInterval, wallPhase: CGFloat) -> CGFloat {
        guard let solar else { return wallPhase }
        switch solar.state {
        case .polarDay:
            return 0.25 + wallPhase * 0.5
        case .polarNight:
            return wallPhase
        case .beforeSunrise:
            guard let sunrise = solar.nextSunrise, sunrise > day.start else { return wallPhase }
            return 0.25 * clamped(now.timeIntervalSince(day.start) / sunrise.timeIntervalSince(day.start))
        case .daylight:
            guard solar.totalDaylightSeconds > 0 else { return wallPhase }
            // `nextSunrise` during daylight normally means tomorrow; use the
            // daylight fraction instead so normal transitions remain smooth.
            let elapsed = solar.totalDaylightSeconds - solar.remainingSeconds
            return 0.25 + 0.5 * clamped(elapsed / solar.totalDaylightSeconds)
        case .afterSunset:
            guard let sunset = solar.nextSunset, sunset < day.end else { return wallPhase }
            return 0.75 + 0.25 * clamped(now.timeIntervalSince(sunset) / day.end.timeIntervalSince(sunset))
        }
    }

    private static func dateSeed(for date: Date, calendar: Calendar) -> UInt64 {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let text = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        return text.utf8.reduce(1_469_598_103_934_665_603) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    private static func unit(_ seed: UInt64) -> CGFloat {
        CGFloat(seed % 10_000) / 10_000
    }

    private static func bell(_ value: CGFloat, centeredAt center: CGFloat, width: CGFloat) -> CGFloat {
        exp(-pow(abs(value - center) / width, 2))
    }

    private static func clamped(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value.isFinite ? value : 0))
    }
}
