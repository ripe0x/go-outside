import AppKit
import Foundation

private final class CleanButton: NSButton {
    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let enabledAlpha: CGFloat = isEnabled ? 1 : 0.42
        let fill = isHighlighted && isEnabled
            ? (dark ? NSColor(calibratedWhite: 0.34, alpha: 0.96) : NSColor(calibratedWhite: 0.79, alpha: 0.96))
            : (dark ? NSColor(calibratedWhite: 0.18, alpha: 0.82) : NSColor(calibratedWhite: 0.90, alpha: 0.86))
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7)
        fill.setFill(); shape.fill()
        (dark ? NSColor.white.withAlphaComponent(0.18) : NSColor.black.withAlphaComponent(0.16)).setStroke()
        shape.lineWidth = 0.8; shape.stroke()
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingTail
        (title as NSString).draw(in: bounds.insetBy(dx: 8, dy: 7), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: (dark ? NSColor.white : NSColor.black).withAlphaComponent(enabledAlpha),
            .paragraphStyle: paragraph
        ])
        if window?.isKeyWindow == true && window?.firstResponder === self {
            (dark ? NSColor.white : NSColor.black).withAlphaComponent(0.72).setStroke()
            let focus = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 5, yRadius: 5)
            focus.lineWidth = 1.5; focus.stroke()
        }
    }
}

private final class MonochromeCheckbox: NSButton {
    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let foreground = dark ? NSColor.white : NSColor.black
        let box = NSRect(x: 0.5, y: (bounds.height - 16) / 2, width: 16, height: 16)
        let path = NSBezierPath(roundedRect: box, xRadius: 3, yRadius: 3)
        (dark ? NSColor(calibratedWhite: 0.16, alpha: 1) : NSColor(calibratedWhite: 0.92, alpha: 1)).setFill()
        path.fill()
        foreground.withAlphaComponent(0.58).setStroke()
        path.lineWidth = 1; path.stroke()
        if state == .on {
            foreground.setStroke()
            let check = NSBezierPath()
            check.move(to: NSPoint(x: 4, y: box.midY))
            check.line(to: NSPoint(x: 7, y: box.minY + 4))
            check.line(to: NSPoint(x: 13, y: box.maxY - 4))
            check.lineWidth = 1.7; check.lineCapStyle = .round; check.lineJoinStyle = .round; check.stroke()
        }
        (title as NSString).draw(at: NSPoint(x: 24, y: (bounds.height - 16) / 2), withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: foreground])
        if window?.isKeyWindow == true && window?.firstResponder === self {
            foreground.withAlphaComponent(0.72).setStroke()
            let focus = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
            focus.lineWidth = 1.5; focus.stroke()
        }
    }
}

private final class MonochromeTextField: NSTextField {
    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        (dark ? NSColor(calibratedWhite: 0.16, alpha: 1) : NSColor.white).setFill()
        path.fill()
        (dark ? NSColor.white : NSColor.black).withAlphaComponent(0.34).setStroke()
        path.lineWidth = 0.8; path.stroke()
        super.draw(dirtyRect)
        if let editor = currentEditor(), window?.isKeyWindow == true && window?.firstResponder === editor {
            (dark ? NSColor.white : NSColor.black).withAlphaComponent(0.72).setStroke()
            let focus = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 5, yRadius: 5)
            focus.lineWidth = 1.5; focus.stroke()
        }
    }
}

private final class MonochromePopup: NSPopUpButton {
    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let foreground = dark ? NSColor.white : NSColor.black
        let alpha: CGFloat = isEnabled ? 1 : 0.42
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7)
        (dark ? NSColor(calibratedWhite: 0.18, alpha: 1) : NSColor(calibratedWhite: 0.90, alpha: 1)).setFill()
        path.fill()
        foreground.withAlphaComponent(0.26).setStroke()
        path.lineWidth = 0.8; path.stroke()
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        ((titleOfSelectedItem ?? "No city results") as NSString).draw(
            in: NSRect(x: 12, y: 7, width: max(0, bounds.width - 44), height: 18),
            withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: foreground.withAlphaComponent(alpha), .paragraphStyle: paragraph]
        )
        let chevrons = NSBezierPath()
        let x = bounds.maxX - 20
        chevrons.move(to: NSPoint(x: x - 4, y: bounds.midY + 3)); chevrons.line(to: NSPoint(x: x, y: bounds.midY + 7)); chevrons.line(to: NSPoint(x: x + 4, y: bounds.midY + 3))
        chevrons.move(to: NSPoint(x: x - 4, y: bounds.midY - 3)); chevrons.line(to: NSPoint(x: x, y: bounds.midY - 7)); chevrons.line(to: NSPoint(x: x + 4, y: bounds.midY - 3))
        foreground.withAlphaComponent(alpha).setStroke(); chevrons.lineWidth = 1.2; chevrons.lineCapStyle = .round; chevrons.lineJoinStyle = .round; chevrons.stroke()
        if window?.isKeyWindow == true && window?.firstResponder === self {
            foreground.withAlphaComponent(0.72).setStroke()
            let focus = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 5, yRadius: 5)
            focus.lineWidth = 1.5; focus.stroke()
        }
    }
}

enum OutsideScreen: Equatable { case main, setup, settings, city }

/// The top third is reserved for atmosphere; all information and controls stay below it.
final class OutsideView: NSView {
    var onBack: (() -> Void)?
    var onCurrentLocation: (() -> Void)?
    var onChooseCity: (() -> Void)?
    var onCitySearch: ((String) -> Void)?
    var onCityConfirm: ((Int) -> Void)?
    var onLoginChanged: ((Bool) -> Void)?
    var previewReducedTransparency: Bool?

    private(set) var preferredSize = NSSize(width: 360, height: 360)
    var atmosphereBounds: NSRect { NSRect(x: bounds.minX, y: bounds.minY + bounds.height * 2 / 3, width: bounds.width, height: bounds.height / 3) }
    var contentBounds: NSRect { NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height * 2 / 3) }
    var contentTextBounds: [NSRect] {
        let body = contentBounds
        switch screen {
        case .main:
            return [NSRect(x: 24, y: body.maxY - 40, width: 312, height: 20), NSRect(x: 24, y: 121, width: 312, height: 70), NSRect(x: 24, y: 78, width: 312, height: 36), NSRect(x: 24, y: 38, width: 312, height: 28)]
        case .setup:
            return [NSRect(x: 24, y: body.maxY - 42, width: 312, height: 22), NSRect(x: 24, y: body.maxY - 90, width: 312, height: 38), NSRect(x: 24, y: body.maxY - 140, width: 312, height: 38), NSRect(x: 24, y: 96, width: 312, height: 30)]
        case .settings:
            return [NSRect(x: 24, y: body.maxY - 42, width: 312, height: 22), NSRect(x: 24, y: body.maxY - 72, width: 312, height: 18), NSRect(x: 24, y: body.maxY - 108, width: 312, height: 30), NSRect(x: 24, y: body.maxY - 158, width: 312, height: 38)]
        case .city:
            return [NSRect(x: 24, y: body.maxY - 42, width: 312, height: 22), NSRect(x: 24, y: body.maxY - 82, width: 312, height: 30)]
        }
    }

    private var screen: OutsideScreen = .main
    private var model = OutsideModel(computer: 0, solar: nil, locationName: "", isLastKnown: false, isAway: false)
    private var locationMessage = ""
    private var isRequesting = false
    private var loginEnabled = false
    private var candidates: [CityCandidate] = []
    private var candidateSignature = ""
    private var controlsBuilt = false
    private var controls: [NSControl] = []
    private var searchField: NSTextField?
    private var currentLocationButton: NSButton?
    private var searchButton: NSButton?
    private var confirmButton: NSButton?
    private var loginCheckbox: NSButton?
    private var selectedCandidate = -1

    private let labelFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    private let bodyFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    private let bodyMedium = NSFont.systemFont(ofSize: 13, weight: .semibold)
    private let brandFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    private let clockLabelFont = NSFont.systemFont(ofSize: 11, weight: .medium)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true; setAccessibilityElement(true); setAccessibilityRole(.group); setAccessibilityLabel("go/outside")
    }
    required init?(coder: NSCoder) { super.init(coder: coder); wantsLayer = true }
    override var isOpaque: Bool { false }

    func render(model: OutsideModel, screen: OutsideScreen, locationMessage: String,
                isRequesting: Bool, candidates: [CityCandidate], loginEnabled: Bool) {
        let signature = candidates.map { "\($0.name)|\($0.latitude)|\($0.longitude)" }.joined(separator: "\n")
        let screenChanged = self.screen != screen
        let resultsChanged = candidateSignature != signature
        self.model = model; self.screen = screen; self.locationMessage = locationMessage
        self.isRequesting = isRequesting; self.loginEnabled = loginEnabled; self.candidates = candidates; candidateSignature = signature
        switch screen {
        case .main: preferredSize = NSSize(width: 360, height: 360)
        case .setup, .settings: preferredSize = NSSize(width: 360, height: 540)
        case .city: preferredSize = NSSize(width: 360, height: 480)
        }
        setFrameSize(preferredSize); setAccessibilityLabel(accessibilitySummary())
        if screenChanged || resultsChanged || !controlsBuilt { rebuildControls() } else { updateControlValues() }
        needsDisplay = true
    }

    private func accessibilitySummary() -> String {
        switch screen {
        case .main: return "\(model.accessibility) \(model.context). \(model.message)"
        case .setup:
            let purpose = locationMessage.isEmpty ? "Your location is used to estimate sunrise and sunset." : locationMessage
            return "go/outside setup. Tracking runs only while go/outside is open. It pauses after 60 seconds without input. \(purpose)"
        case .settings:
            let location = model.locationName.isEmpty ? "No location is saved." : "Location: \(model.locationName)."
            return "go/outside settings. \(location) \(locationMessage) Computer time stays on this Mac. Location lookup may use Apple services."
        case .city: return "go/outside city selection. \(locationMessage.isEmpty ? "Search by city and country." : locationMessage)"
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let reduced = previewReducedTransparency ?? NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let atmosphere = DaylightAtmosphere.configuration(at: model.now, solar: model.solar, calendar: .current)
        DaylightAtmosphere.draw(atmosphere, in: atmosphereBounds, dark: dark, reducedTransparency: reduced)
        (dark ? NSColor(calibratedWhite: 0.075, alpha: reduced ? 1 : 0.94) : NSColor(calibratedWhite: 0.975, alpha: reduced ? 1 : 0.94)).setFill()
        contentBounds.fill()
        switch screen {
        case .main: drawMain(dark: dark)
        case .setup: drawSetup(dark: dark)
        case .settings: drawSettings(dark: dark)
        case .city: drawCity(dark: dark)
        }
    }

    private func drawMain(dark: Bool) {
        let layout = contentTextBounds; let primary = textColor(dark: dark); let muted = mutedColor(dark: dark)
        let computerClock = model.computerClock
        let daylightClock = model.daylightClock
        let clockFont = fittedClockFont(computer: computerClock, daylight: daylightClock, maximumWidth: 140)
        drawText("go/outside", in: NSRect(x: layout[0].minX, y: layout[0].minY, width: 160, height: layout[0].height), font: brandFont, color: primary)
        drawText(model.isAway ? "AWAY" : "TODAY", in: NSRect(x: layout[0].maxX - 108, y: layout[0].minY, width: 108, height: layout[0].height), font: labelFont, alignment: .right, color: muted)
        let left = NSRect(x: layout[1].minX, y: layout[1].minY + 24, width: 140, height: 46)
        let right = NSRect(x: layout[1].maxX - 140, y: left.minY, width: 140, height: 46)
        drawText(computerClock, in: left, font: clockFont, color: primary)
        drawText(daylightClock, in: right, font: clockFont, color: primary)
        drawText("/", in: NSRect(x: left.maxX, y: left.minY + 8, width: right.minX - left.maxX, height: 32), font: NSFont.systemFont(ofSize: 24, weight: .light), alignment: .center, color: muted)
        drawText("On your computer", in: NSRect(x: left.minX, y: layout[1].minY, width: left.width, height: 18), font: clockLabelFont, color: muted)
        drawText("Daylight left", in: NSRect(x: right.minX, y: layout[1].minY, width: right.width, height: 18), font: clockLabelFont, color: muted)
        drawText(model.context, in: layout[2], font: bodyFont, color: muted)
        drawText(model.message, in: layout[3], font: bodyMedium, color: primary)
    }

    private func fittedClockFont(computer: String, daylight: String, maximumWidth: CGFloat) -> NSFont {
        for size in stride(from: CGFloat(36), through: CGFloat(24), by: -1) {
            let font = condensedClockFont(size: size)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            if (computer as NSString).size(withAttributes: attributes).width <= maximumWidth,
               (daylight as NSString).size(withAttributes: attributes).width <= maximumWidth {
                return font
            }
        }
        return condensedClockFont(size: 24)
    }

    private func condensedClockFont(size: CGFloat) -> NSFont {
        guard let base = NSFont(name: "AvenirNextCondensed-DemiBold", size: size) else {
            let fallback = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold)
            return NSFontManager.shared.convert(fallback, toHaveTrait: .condensedFontMask)
        }
        let tabularDescriptor = base.fontDescriptor.addingAttributes([
            .featureSettings: [[
                NSFontDescriptor.FeatureKey.typeIdentifier: 6,
                NSFontDescriptor.FeatureKey.selectorIdentifier: 0
            ]]
        ])
        return NSFont(descriptor: tabularDescriptor, size: size) ?? base
    }

    private func drawSetup(dark: Bool) {
        let layout = contentTextBounds; let primary = textColor(dark: dark); let muted = mutedColor(dark: dark)
        drawText("Set up location", in: layout[0], font: bodyMedium, color: primary)
        drawText("Tracking runs while go/outside is open. It pauses after 60 seconds without input.", in: layout[1], font: bodyFont, color: muted)
        drawText(locationMessage.isEmpty ? "Your location is used to estimate sunrise and sunset." : locationMessage, in: layout[2], font: bodyFont, color: primary)
        drawText("A city is stored as a coarse coordinate. No account or history.", in: layout[3], font: bodyFont, color: muted)
    }

    private func drawSettings(dark: Bool) {
        let layout = contentTextBounds; let primary = textColor(dark: dark); let muted = mutedColor(dark: dark)
        drawText("Settings", in: layout[0], font: bodyMedium, color: primary)
        drawText("LOCATION", in: layout[1], font: labelFont, color: muted)
        let name = model.locationName.isEmpty ? "No location saved" : model.locationName
        drawText(model.isLastKnown ? name + " · last known" : name, in: layout[2], font: bodyFont, color: primary)
        drawText(locationMessage.isEmpty ? "Computer time stays on this Mac. Location lookup may use Apple services." : locationMessage, in: layout[3], font: bodyFont, color: muted)
    }

    private func drawCity(dark: Bool) {
        let layout = contentTextBounds; let primary = textColor(dark: dark); let muted = mutedColor(dark: dark)
        drawText("Choose a city", in: layout[0], font: bodyMedium, color: primary)
        drawText(locationMessage.isEmpty ? "Search by city and country." : locationMessage, in: layout[1], font: bodyFont, color: muted)
    }

    private func rebuildControls() {
        let previousSearchText = searchField?.stringValue ?? ""
        controls.forEach { $0.removeFromSuperview() }; controls.removeAll()
        searchField = nil; currentLocationButton = nil; searchButton = nil; confirmButton = nil; loginCheckbox = nil
        selectedCandidate = candidates.isEmpty ? -1 : 0
        switch screen {
        case .main: break
        case .setup:
            currentLocationButton = addButton("Use current location", frame: NSRect(x: 24, y: 180, width: 312, height: 32), action: #selector(currentLocationPressed), label: "Use current location")
            addButton("Choose a city", frame: NSRect(x: 24, y: 136, width: 312, height: 32), action: #selector(chooseCityPressed), label: "Choose a city")
            loginCheckbox = addCheckbox(frame: NSRect(x: 24, y: 56, width: 220, height: 24))
        case .settings:
            currentLocationButton = addButton("Refresh location", frame: NSRect(x: 24, y: 156, width: 312, height: 32), action: #selector(currentLocationPressed), label: "Refresh current location")
            addButton("Choose a city", frame: NSRect(x: 24, y: 112, width: 312, height: 32), action: #selector(chooseCityPressed), label: "Choose a city")
            loginCheckbox = addCheckbox(frame: NSRect(x: 24, y: 68, width: 220, height: 24))
            addButton("Back", frame: NSRect(x: 24, y: 30, width: 92, height: 30), action: #selector(backPressed), label: "Back")
        case .city:
            let field = MonochromeTextField(frame: NSRect(x: 24, y: 190, width: 218, height: 32))
            field.placeholderString = "City, country"; field.stringValue = previousSearchText; field.font = bodyFont; field.target = self; field.action = #selector(searchPressed); field.setAccessibilityLabel("City and country"); styleTextField(field)
            addControl(field); searchField = field
            searchButton = addButton("Search", frame: NSRect(x: 252, y: 190, width: 84, height: 32), action: #selector(searchPressed), label: "Search city")
            let popup = MonochromePopup(frame: NSRect(x: 24, y: 142, width: 312, height: 32), pullsDown: false)
            popup.font = bodyFont; popup.addItems(withTitles: candidates.map(\.name)); popup.target = self; popup.action = #selector(candidatePopupChanged(_:)); popup.setAccessibilityLabel("City results"); popup.isEnabled = !candidates.isEmpty
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            popup.contentTintColor = dark ? .lightGray : .darkGray
            popup.focusRingType = .none
            if !candidates.isEmpty { popup.selectItem(at: 0) }
            addControl(popup)
            confirmButton = addButton("Confirm city", frame: NSRect(x: 24, y: 94, width: 312, height: 32), action: #selector(confirmCityPressed), label: "Confirm selected city")
            addButton("Back", frame: NSRect(x: 24, y: 30, width: 92, height: 30), action: #selector(backPressed), label: "Back")
            if !previousSearchText.isEmpty { DispatchQueue.main.async { [weak field] in field?.window?.makeFirstResponder(field) } }
        }
        controlsBuilt = true; updateControlValues()
    }

    private func updateControlValues() {
        loginCheckbox?.state = loginEnabled ? .on : .off
        currentLocationButton?.title = isRequesting ? "Finding location…" : (screen == .settings ? "Refresh location" : "Use current location")
        currentLocationButton?.isEnabled = !isRequesting
        searchButton?.title = isRequesting ? "Searching…" : "Search"; searchButton?.isEnabled = !isRequesting
        confirmButton?.isEnabled = selectedCandidate >= 0 && !candidates.isEmpty && !isRequesting
    }

    @discardableResult
    private func addButton(_ title: String, frame: NSRect, action: Selector, label: String) -> NSButton {
        let button = CleanButton(title: title, target: self, action: action); button.frame = frame; button.focusRingType = .none; button.setAccessibilityLabel(label); addControl(button); return button
    }
    private func addCheckbox(frame: NSRect) -> NSButton {
        let checkbox = MonochromeCheckbox(checkboxWithTitle: "Launch at login", target: self, action: #selector(loginChanged(_:))); checkbox.frame = frame; checkbox.font = bodyFont; checkbox.focusRingType = .none; checkbox.setAccessibilityLabel("Launch go/outside at login"); addControl(checkbox); return checkbox
    }
    private func styleTextField(_ field: NSTextField) {
        field.drawsBackground = false
        field.textColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.95, alpha: 1)
                : NSColor(calibratedWhite: 0.08, alpha: 1)
        }
        field.isBordered = false; field.focusRingType = .none
    }
    private func addControl(_ control: NSControl) { addSubview(control); controls.append(control) }
    private func textColor(dark: Bool) -> NSColor { dark ? NSColor(calibratedWhite: 0.95, alpha: 1) : NSColor(calibratedWhite: 0.08, alpha: 1) }
    private func mutedColor(dark: Bool) -> NSColor { dark ? NSColor(calibratedWhite: 0.76, alpha: 1) : NSColor(calibratedWhite: 0.32, alpha: 1) }
    private func drawText(_ value: String, in rect: NSRect, font: NSFont, alignment: NSTextAlignment = .left, color: NSColor) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = alignment; paragraph.lineBreakMode = .byWordWrapping
        (value as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }
    @objc private func backPressed() { onBack?() }
    @objc private func currentLocationPressed() { onCurrentLocation?() }
    @objc private func chooseCityPressed() { onChooseCity?() }
    @objc private func searchPressed() { onCitySearch?(searchField?.stringValue ?? "") }
    @objc private func candidatePopupChanged(_ sender: NSPopUpButton) { selectedCandidate = sender.indexOfSelectedItem; updateControlValues() }
    @objc private func confirmCityPressed() { guard selectedCandidate >= 0 else { return }; onCityConfirm?(selectedCandidate) }
    @objc private func loginChanged(_ sender: NSButton) { onLoginChanged?(sender.state == .on) }
}
