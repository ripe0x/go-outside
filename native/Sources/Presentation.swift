import AppKit
import Foundation

enum RatioState: Equatable {
    case unknown, empty, share(Double)

    static func make(computer: Double, daylight: Double?) -> RatioState {
        guard let daylight = daylight, daylight.isFinite, daylight >= 0,
              computer.isFinite, computer >= 0 else { return .unknown }
        let total = computer + daylight
        guard total.isFinite else { return .unknown }
        guard total > 0 else { return .empty }
        return .share(computer / total)
    }
}

enum OutsideFormat {
    static func duration(_ seconds: Double, remaining: Bool = false) -> String {
        guard seconds.isFinite else { return "—" }
        let safeSeconds = min(max(0, seconds), 7 * 86400)
        let minutes = Int(remaining ? ceil(safeSeconds / 60) : floor(safeSeconds / 60))
        return minutes >= 60 ? String(format: "%dh%02d", minutes / 60, minutes % 60) : "\(minutes)m"
    }

    static func accessibleDuration(_ seconds: Double, remaining: Bool = false) -> String {
        guard seconds.isFinite else { return "Unknown time" }
        let safeSeconds = min(max(0, seconds), 7 * 86400)
        let minutes = Int(remaining ? ceil(safeSeconds / 60) : floor(safeSeconds / 60))
        let hours = minutes / 60
        let minuteText = "\(minutes % 60) " + (minutes % 60 == 1 ? "minute" : "minutes")
        return hours > 0 ? "\(hours) " + (hours == 1 ? "hour " : "hours ") + minuteText
            : "\(minutes) " + (minutes == 1 ? "minute" : "minutes")
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct OutsideModel {
    var computer: Double
    var solar: SolarSnapshot?
    var locationName: String
    var isLastKnown: Bool
    var isAway: Bool
    var now: Date = Date()

    var computerText: String { OutsideFormat.duration(computer) }
    var daylightText: String { solar.map { OutsideFormat.duration($0.remainingSeconds, remaining: true) } ?? "—" }
    var ratio: RatioState { RatioState.make(computer: computer, daylight: solar?.remainingSeconds) }
    var menuText: String { "\(computerText) / \(daylightText)" }
    var accessibility: String {
        let computer = OutsideFormat.accessibleDuration(self.computer)
        let daylight = solar.map { OutsideFormat.accessibleDuration($0.remainingSeconds, remaining: true) + " of daylight remaining." }
            ?? "Daylight is unknown. Set your location."
        return "\(computer) on your computer today. \(daylight)" + (isAway ? " Tracking is away." : "")
    }
    var message: String {
        guard let solar = solar else { return "Allow location to find your daylight." }
        switch solar.state {
        case .polarNight: return "No daylight today. Tomorrow is another day."
        case .polarDay: return "Daylight all day. Go catch some."
        case .beforeSunrise: return "The sun's not up yet."
        case .afterSunset: return "The sun clocked out. You can too."
        case .daylight: return solar.remainingSeconds <= 3600 ? "Last light. Go/outside?" : "Still time to go/outside."
        }
    }
    var context: String {
        guard let solar = solar else { return "Sunrise and sunset need your location." }
        let prefix: String
        switch solar.state {
        case .polarDay: prefix = "Daylight until midnight"
        case .polarNight: prefix = "No sunrise today"
        case .beforeSunrise: prefix = solar.nextSunrise.map { "Sunrise ~" + OutsideFormat.time($0) } ?? "Before sunrise"
        case .daylight, .afterSunset: prefix = solar.nextSunset.map { "Sunset ~" + OutsideFormat.time($0) } ?? "Sunset has passed"
        }
        return prefix + " · " + (isLastKnown ? "Last known location" : locationName)
    }
}

enum RatioIcon {
    static func image(for state: RatioState, size: CGFloat = 20, template: Bool = true) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { bounds in
            draw(state, in: bounds, color: .black)
            return true
        }
        image.isTemplate = template
        return image
    }

    static func draw(_ state: RatioState, in bounds: NSRect, color: NSColor) {
        let radius = bounds.width / 2 - 2
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let circle = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                               width: radius * 2, height: radius * 2))
        circle.lineWidth = 1.3
        color.setFill()
        switch state {
        case .share(let share) where share >= 1:
            circle.fill()
        case .share(let share) where share > 0:
            let sector = NSBezierPath()
            sector.move(to: center)
            sector.line(to: NSPoint(x: center.x, y: center.y + radius))
            sector.appendArc(withCenter: center, radius: radius,
                             startAngle: 90, endAngle: 90 - CGFloat(share) * 360, clockwise: true)
            sector.close()
            sector.fill()
        case .unknown:
            let string = "?" as NSString
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: bounds.width * 0.55, weight: .medium), .foregroundColor: color]
            let size = string.size(withAttributes: attributes)
            string.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attributes)
        case .empty:
            NSBezierPath(rect: NSRect(x: center.x - 3, y: center.y - 0.6, width: 6, height: 1.2)).fill()
        default: break
        }
        color.setStroke()
        circle.stroke()
    }
}
