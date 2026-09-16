import AppKit
import Foundation

/// A deterministic visual treatment for the current Mac calendar day.
///
/// `phase` progresses from 0 at local midnight through .25 at sunrise, .5 at
/// solar noon, .75 at sunset, and 1 at the next local midnight. With a normal
/// solar snapshot it is derived from the calculated event times and daylight
/// duration. Without a location it falls back to the Mac wall clock. The
/// fallback is intentionally only visual, and makes no daylight claim.
struct AtmosphereConfiguration: Equatable {
    let phase: CGFloat
    let dailySeed: UInt64
    let hueOffset: CGFloat
    let centerX: CGFloat
    let centerY: CGFloat
    let intensity: CGFloat
    let warmth: CGFloat
    let nightness: CGFloat
    let paletteShift: CGFloat
}

/// Dreamy, low-contrast radial glows for the space behind the app's glass UI.
/// The configuration is pure, date-stable, and contains no animation state.
enum DaylightAtmosphere {
    static func configuration(
        at now: Date,
        solar: SolarSnapshot?,
        calendar: Calendar = .current
    ) -> AtmosphereConfiguration {
        let day = calendar.dateInterval(of: .day, for: now)
            ?? DateInterval(start: now, duration: 86_400)
        let wallPhase = clamped((now.timeIntervalSince(day.start) / day.duration))
        let seed = dateSeed(for: now, calendar: calendar)
        let unitA = unit(seed)
        let unitB = unit(seed &* 0x9E37_79B9_7F4A_7C15)
        let hueOffset = (unitA - 0.5) * 0.045
        let paletteShift = (unitB - 0.5) * 0.08

        let solarPhase = phase(at: now, solar: solar, day: day, wallPhase: wallPhase)
        let dayFraction = clamped((solarPhase - 0.25) / 0.5)
        let daylightCore = sin(.pi * dayFraction)
        let sunriseWarmth = bell(solarPhase, centeredAt: 0.25, width: 0.115)
        let sunsetWarmth = bell(solarPhase, centeredAt: 0.75, width: 0.135)
        let polarDay = solar?.state == .polarDay
        let polarNight = solar?.state == .polarNight

        let intensity: CGFloat
        let nightness: CGFloat
        let warmth: CGFloat
        if polarDay {
            intensity = 0.66 + 0.08 * sin(.pi * wallPhase)
            nightness = 0.08
            warmth = 0.13
        } else if polarNight {
            intensity = 0.16
            nightness = 0.95
            warmth = 0.04
        } else {
            intensity = clamped(0.22 + 0.46 * daylightCore + 0.14 * max(sunriseWarmth, sunsetWarmth))
            nightness = clamped(0.80 - 0.68 * daylightCore)
            warmth = clamped(0.10 + 0.72 * max(sunriseWarmth, sunsetWarmth))
        }

        return AtmosphereConfiguration(
            phase: solarPhase,
            dailySeed: seed,
            hueOffset: hueOffset,
            centerX: clamped(0.50 + (unitA - 0.5) * 0.16),
            centerY: clamped(0.45 + (unitB - 0.5) * 0.12),
            intensity: intensity,
            warmth: warmth,
            nightness: nightness,
            paletteShift: paletteShift
        )
    }

    /// Draw this before glass panels and controls. Reduced Transparency uses a
    /// single opaque, neutral wash instead of overlapping translucent glows.
    static func draw(
        _ configuration: AtmosphereConfiguration,
        in bounds: NSRect,
        dark: Bool,
        reducedTransparency: Bool
    ) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        if reducedTransparency {
            (dark
                ? NSColor(calibratedWhite: 0.105, alpha: 1)
                : NSColor(calibratedWhite: 0.965, alpha: 1)
            ).setFill()
            bounds.fill()
            return
        }

        let lightBase = NSColor(calibratedHue: wrappedHue(0.60 + configuration.hueOffset), saturation: 0.13, brightness: 0.99, alpha: 0.24)
        let darkBase = NSColor(calibratedHue: wrappedHue(0.64 + configuration.hueOffset), saturation: 0.23, brightness: 0.15, alpha: 0.34)
        (dark ? darkBase : lightBase).setFill()
        bounds.fill()

        // The content view lays a translucent glass wash over this layer, so
        // the glow cores need enough pigment to survive that wash. Their wide
        // radial falloff still leaves the result airy at the edges.
        let alphaScale: CGFloat = dark ? 0.94 : 0.98
        let center = NSPoint(
            x: bounds.minX + bounds.width * configuration.centerX,
            y: bounds.minY + bounds.height * configuration.centerY
        )
        let radius = max(bounds.width, bounds.height) * 0.82
        let sunriseOrSunset = configuration.warmth
        let dayGlow = 1 - configuration.nightness

        let dayCoreAlpha = alphaScale * (0.18 + 0.55 * dayGlow) * (0.55 + 0.45 * configuration.intensity)
        let lilacCoreAlpha = alphaScale * (0.12 + 0.43 * dayGlow) * (0.55 + 0.45 * configuration.intensity)
        let warmCoreAlpha = alphaScale * (0.10 + 0.70 * sunriseOrSunset) * (0.55 + 0.45 * configuration.intensity)
        let roseCoreAlpha = alphaScale * (0.06 + 0.58 * sunriseOrSunset) * (0.55 + 0.45 * configuration.intensity)
        let nightBlueAlpha = alphaScale * (0.08 + 0.34 * configuration.nightness) * (0.52 + 0.36 * configuration.intensity)

        radialGlow(
            color: color(hue: 0.53 + configuration.hueOffset, saturation: 0.60, brightness: dark ? 0.80 : 1, alpha: dayCoreAlpha),
            center: center,
            radius: radius,
            in: bounds
        )
        radialGlow(
            color: color(hue: 0.76 + configuration.paletteShift, saturation: 0.52, brightness: dark ? 0.76 : 1, alpha: lilacCoreAlpha),
            center: NSPoint(x: bounds.minX + bounds.width * 0.86, y: bounds.minY + bounds.height * 0.78),
            radius: radius * 0.78,
            in: bounds
        )
        radialGlow(
            color: color(hue: 0.075 + configuration.hueOffset, saturation: 0.72, brightness: dark ? 0.90 : 1, alpha: warmCoreAlpha),
            center: NSPoint(x: bounds.minX + bounds.width * 0.16, y: bounds.minY + bounds.height * (0.18 + 0.18 * configuration.phase)),
            radius: radius * 0.72,
            in: bounds
        )
        radialGlow(
            color: color(hue: 0.98 + configuration.paletteShift, saturation: 0.62, brightness: dark ? 0.80 : 1, alpha: roseCoreAlpha),
            center: NSPoint(x: bounds.minX + bounds.width * 0.74, y: bounds.minY + bounds.height * 0.24),
            radius: radius * 0.64,
            in: bounds
        )
        radialGlow(
            color: color(hue: 0.61 + configuration.hueOffset, saturation: 0.48, brightness: dark ? 0.64 : 0.92, alpha: nightBlueAlpha),
            center: NSPoint(x: bounds.minX + bounds.width * 0.48, y: bounds.minY + bounds.height * 0.86),
            radius: radius * 0.92,
            in: bounds
        )
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
            let progress = clamped(now.timeIntervalSince(day.start) / sunrise.timeIntervalSince(day.start))
            return 0.25 * progress
        case .daylight:
            guard solar.totalDaylightSeconds > 0 else { return wallPhase }
            // This uses daylight already elapsed, rather than `nextSunrise`:
            // during daylight that event normally refers to tomorrow. It also
            // remains stable when the Mac day intersects remote solar dates.
            let progress = clamped((solar.totalDaylightSeconds - solar.remainingSeconds) / solar.totalDaylightSeconds)
            return 0.25 + 0.5 * progress
        case .afterSunset:
            guard let sunset = solar.nextSunset, sunset < day.end else { return wallPhase }
            let progress = clamped(now.timeIntervalSince(sunset) / day.end.timeIntervalSince(sunset))
            return 0.75 + 0.25 * progress
        }
    }

    private static func radialGlow(color: NSColor, center: NSPoint, radius: CGFloat, in bounds: NSRect) {
        let transparent = color.withAlphaComponent(0)
        guard let context = NSGraphicsContext.current?.cgContext,
              let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [color.cgColor, transparent.cgColor] as CFArray,
                locations: [0, 1]
              ) else { return }
        context.saveGState()
        context.addRect(bounds)
        context.clip()
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    private static func color(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> NSColor {
        NSColor(calibratedHue: wrappedHue(hue), saturation: saturation, brightness: brightness, alpha: clamped(alpha))
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
        let distance = abs(value - center)
        return exp(-pow(distance / width, 2))
    }

    private static func clamped(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value.isFinite ? value : 0))
    }

    private static func wrappedHue(_ value: CGFloat) -> CGFloat {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
    }
}
