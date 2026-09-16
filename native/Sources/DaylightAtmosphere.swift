import AppKit
import Foundation

/// A deterministic geometry for the popover's procedural artwork.
///
/// `phase` progresses from local midnight (0), through sunrise (.25), solar
/// noon (.5), sunset (.75), and the following midnight (1). Without a saved
/// location it falls back to the Mac wall clock only for decorative color.
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

/// Native procedural color studies for the dedicated top artwork region.
///
/// The renderer combines warped horizontal bands, asymmetric folds, and fine
/// deterministic grain. It never downloads or copies visual assets. Images
/// are cached by artwork state, so an open popover redraw does not re-run the
/// pixel field until its minute-level appearance changes.
enum DaylightAtmosphere {
    private struct RGB {
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat

        static func mix(_ first: RGB, _ second: RGB, _ amount: CGFloat) -> RGB {
            let amount = clamped(amount)
            return RGB(
                red: first.red + (second.red - first.red) * amount,
                green: first.green + (second.green - first.green) * amount,
                blue: first.blue + (second.blue - first.blue) * amount
            )
        }

        func adjustedBrightness(_ amount: CGFloat) -> RGB {
            RGB(
                red: clamped(red + amount),
                green: clamped(green + amount),
                blue: clamped(blue + amount)
            )
        }
    }

    private struct Palette {
        let base: RGB
        let cool: RGB
        let warm: RGB
        let accent: RGB
        let edge: RGB

        static func mix(_ first: Palette, _ second: Palette, _ amount: CGFloat) -> Palette {
            Palette(
                base: .mix(first.base, second.base, amount),
                cool: .mix(first.cool, second.cool, amount),
                warm: .mix(first.warm, second.warm, amount),
                accent: .mix(first.accent, second.accent, amount),
                edge: .mix(first.edge, second.edge, amount)
            )
        }
    }

    private static let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 36
        return cache
    }()

    static func configuration(
        at now: Date,
        solar: SolarSnapshot?,
        calendar: Calendar = .current
    ) -> AtmosphereConfiguration {
        let day = calendar.dateInterval(of: .day, for: now)
            ?? DateInterval(start: now, duration: 86_400)
        let wallPhase = clamped(now.timeIntervalSince(day.start) / day.duration)
        // Keep the expensive artwork stable between small phase steps while
        // the duration labels continue refreshing each second.
        let phase = (phase(at: now, solar: solar, day: day, wallPhase: wallPhase) * 1_440).rounded() / 1_440
        let seed = dateSeed(for: now, calendar: calendar)
        let xVariation = (unit(seed) - 0.5) * 0.07
        let angleVariation = (unit(seed &* 0x9E37_79B9_7F4A_7C15) - 0.5) * 0.16

        let dayProgress = clamped((phase - 0.25) / 0.5)
        let daylight = sin(.pi * dayProgress)
        let horizon = max(
            bell(phase, centeredAt: 0.25, width: 0.13),
            bell(phase, centeredAt: 0.75, width: 0.14)
        )

        if solar?.state == .polarDay {
            return AtmosphereConfiguration(
                phase: phase, dailySeed: seed, centerX: 0.5 + xVariation,
                centerY: 0.57, radius: 0.82, stretchX: 1.28, stretchY: 1.10,
                angle: angleVariation, intensity: 0.86
            )
        }
        if solar?.state == .polarNight {
            return AtmosphereConfiguration(
                phase: phase, dailySeed: seed, centerX: 0.5 + xVariation * 0.5,
                centerY: 0.63, radius: 0.40, stretchX: 0.82, stretchY: 0.78,
                angle: angleVariation * 0.5, intensity: 0.34
            )
        }

        // Sunrise and sunset become narrow, low, tilted flows. Noon becomes a
        // broad, high cyan field; night contracts into a deep violet study.
        return AtmosphereConfiguration(
            phase: phase,
            dailySeed: seed,
            centerX: clamped(0.5 + xVariation + 0.055 * sin((phase - 0.5) * .pi)),
            centerY: clamped(0.64 * (1 - daylight) + 0.57 * daylight - 0.40 * horizon),
            radius: 0.40 + 0.38 * daylight + 0.14 * horizon,
            stretchX: 0.82 + 0.46 * daylight + 0.68 * horizon,
            stretchY: 0.78 + 0.34 * daylight - 0.26 * horizon,
            angle: angleVariation + 0.17 * sin((phase - 0.5) * .pi),
            intensity: clamped(0.36 + 0.48 * daylight + 0.23 * horizon)
        )
    }

    /// Draw only the supplied top-artwork rectangle. The image is opaque and
    /// intentionally unchanged by Reduce Transparency because text lives in a
    /// separate glass information region below it.
    static func draw(
        _ configuration: AtmosphereConfiguration,
        in bounds: NSRect,
        dark: Bool,
        reducedTransparency: Bool
    ) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        _ = dark
        _ = reducedTransparency
        let width = max(1, Int(bounds.width.rounded()))
        let height = max(1, Int(bounds.height.rounded()))
        let key = cacheKey(for: configuration, width: width, height: height)
        let image = imageCache.object(forKey: key) ?? makeImage(configuration, width: width, height: height)
        imageCache.setObject(image, forKey: key)
        image.draw(in: bounds, from: NSRect(x: 0, y: 0, width: width, height: height), operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    private static func makeImage(_ configuration: AtmosphereConfiguration, width: Int, height: Int) -> NSImage {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let palette = palette(for: configuration.phase)
        let phase = configuration.phase
        let seedA = unit(configuration.dailySeed)
        let seedB = unit(configuration.dailySeed &* 0xD1B5_4A32_D192_ED03)
        let centerX = configuration.centerX
        let centerY = configuration.centerY
        let slope = tan(configuration.angle) * 0.20

        for y in 0..<height {
            let vertical = CGFloat(y) / CGFloat(max(1, height - 1))
            for x in 0..<width {
                let horizontal = CGFloat(x) / CGFloat(max(1, width - 1))
                let broadWarp = 0.16 * sin((horizontal * 0.78 + seedA) * .pi * 2 + phase * .pi)
                let fineWarp = 0.025 * sin((horizontal * 2.1 - vertical * 0.7 + seedB) * .pi * 2)
                let flow = vertical + broadWarp + fineWarp + (horizontal - centerX) * slope
                let primaryCenter = centerY + 0.10 * sin((horizontal * 0.65 + seedB) * .pi * 2)
                let warmCenter = centerY - 0.18 + 0.14 * sin((horizontal * 0.85 + phase) * .pi * 2)
                let coolBand = gaussian(flow - primaryCenter, width: 0.27 * configuration.stretchY)
                let warmBand = gaussian(flow - warmCenter, width: 0.17 * configuration.stretchY)
                let violetBand = gaussian(flow - (primaryCenter + 0.23), width: 0.22 * configuration.stretchY)
                let foldCenter = primaryCenter + 0.18 * sin((horizontal * 0.85 + phase * 1.6) * .pi)
                let fold = gaussian(flow - foldCenter, width: 0.026 + 0.018 * configuration.radius)
                let sideDistance = abs(horizontal - centerX) / max(configuration.stretchX, 0.1)
                let sideVignette = clamped(pow(sideDistance, 1.7) * 0.42 + pow(abs(vertical - 0.5), 3) * 0.18)
                let organicMask = clamped(0.30 + 0.70 * gaussian(horizontal - centerX, width: configuration.radius * 0.85))

                var color = RGB.mix(palette.base, palette.cool, coolBand * (0.34 + 0.54 * organicMask))
                color = RGB.mix(color, palette.warm, warmBand * (0.18 + 0.58 * horizonStrength(phase)))
                color = RGB.mix(color, palette.accent, violetBand * 0.36)
                color = RGB.mix(color, RGB(red: 1, green: 0.96, blue: 0.90), fold * (0.14 + 0.43 * configuration.intensity))
                color = RGB.mix(color, palette.edge, sideVignette)

                let grain = deterministicGrain(x: x, y: y, seed: configuration.dailySeed) * 0.014 - 0.007
                color = color.adjustedBrightness(grain)
                write(color, to: bitmap, x: x, y: y)
            }
        }

        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(bitmap)
        image.isTemplate = false
        return image
    }

    private static func palette(for phase: CGFloat) -> Palette {
        let night = Palette(
            base: RGB(red: 0.075, green: 0.035, blue: 0.16),
            cool: RGB(red: 0.20, green: 0.14, blue: 0.43),
            warm: RGB(red: 0.35, green: 0.07, blue: 0.28),
            accent: RGB(red: 0.28, green: 0.10, blue: 0.48),
            edge: RGB(red: 0.055, green: 0.012, blue: 0.10)
        )
        let dawn = Palette(
            base: RGB(red: 0.22, green: 0.06, blue: 0.23),
            cool: RGB(red: 0.14, green: 0.62, blue: 0.76),
            warm: RGB(red: 1.0, green: 0.55, blue: 0.36),
            accent: RGB(red: 0.98, green: 0.20, blue: 0.48),
            edge: RGB(red: 0.17, green: 0.025, blue: 0.12)
        )
        let noon = Palette(
            base: RGB(red: 0.10, green: 0.28, blue: 0.52),
            cool: RGB(red: 0.18, green: 0.85, blue: 0.96),
            warm: RGB(red: 0.98, green: 0.66, blue: 0.73),
            accent: RGB(red: 0.68, green: 0.36, blue: 0.88),
            edge: RGB(red: 0.11, green: 0.05, blue: 0.28)
        )
        let dusk = Palette(
            base: RGB(red: 0.24, green: 0.045, blue: 0.20),
            cool: RGB(red: 0.24, green: 0.42, blue: 0.78),
            warm: RGB(red: 1.0, green: 0.54, blue: 0.34),
            accent: RGB(red: 0.90, green: 0.14, blue: 0.46),
            edge: RGB(red: 0.15, green: 0.012, blue: 0.10)
        )
        let wrapped = phase == 1 ? 0 : phase
        if wrapped < 0.25 { return .mix(night, dawn, wrapped / 0.25) }
        if wrapped < 0.5 { return .mix(dawn, noon, (wrapped - 0.25) / 0.25) }
        if wrapped < 0.75 { return .mix(noon, dusk, (wrapped - 0.5) / 0.25) }
        return .mix(dusk, night, (wrapped - 0.75) / 0.25)
    }

    private static func cacheKey(for configuration: AtmosphereConfiguration, width: Int, height: Int) -> NSString {
        let values = [
            configuration.dailySeed.description,
            String(Int((configuration.phase * 1_440).rounded())),
            String(Int((configuration.centerX * 1_000).rounded())),
            String(Int((configuration.centerY * 1_000).rounded())),
            String(Int((configuration.radius * 1_000).rounded())),
            String(Int((configuration.stretchX * 1_000).rounded())),
            String(Int((configuration.stretchY * 1_000).rounded())),
            String(Int((configuration.angle * 1_000).rounded())),
            String(Int((configuration.intensity * 1_000).rounded())),
            "\(width)x\(height)"
        ]
        return values.joined(separator: ":") as NSString
    }

    private static func write(_ color: RGB, to bitmap: NSBitmapImageRep, x: Int, y: Int) {
        guard let data = bitmap.bitmapData else { return }
        let index = y * bitmap.bytesPerRow + x * 4
        data[index] = UInt8((clamped(color.red) * 255).rounded())
        data[index + 1] = UInt8((clamped(color.green) * 255).rounded())
        data[index + 2] = UInt8((clamped(color.blue) * 255).rounded())
        data[index + 3] = 255
    }

    private static func horizonStrength(_ phase: CGFloat) -> CGFloat {
        max(bell(phase, centeredAt: 0.25, width: 0.15), bell(phase, centeredAt: 0.75, width: 0.16))
    }

    private static func deterministicGrain(x: Int, y: Int, seed: UInt64) -> CGFloat {
        var value = UInt64(x &* 73_856_093) ^ UInt64(y &* 19_349_663) ^ seed
        value ^= value >> 33
        value &*= 0xff51afd7ed558ccd
        value ^= value >> 33
        return CGFloat(value & 0xffff) / CGFloat(0xffff)
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

    private static func gaussian(_ value: CGFloat, width: CGFloat) -> CGFloat {
        exp(-pow(value / max(width, 0.001), 2))
    }

    private static func bell(_ value: CGFloat, centeredAt center: CGFloat, width: CGFloat) -> CGFloat {
        gaussian(value - center, width: width)
    }

    private static func clamped(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value.isFinite ? value : 0))
    }
}
