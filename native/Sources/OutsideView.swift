import AppKit
import Foundation

private final class GridButton: NSButton {
    override func draw(_ dirtyRect: NSRect) {
        let fill = isHighlighted
            ? NSColor.selectedControlColor.withAlphaComponent(0.20)
            : NSColor.windowBackgroundColor
        fill.setFill()
        bounds.fill()
        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        (title as NSString).draw(
            in: bounds.insetBy(dx: 8, dy: 9),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        )
    }
}

enum OutsideScreen: Equatable {
    case main
    case setup
    case settings
    case city
}

/// The compact menu-bar popover. Drawing stays in this view so the layout
/// remains stable in light and dark appearances while controls remain native.
final class OutsideView: NSView {
    var onSettings: (() -> Void)?
    var onBack: (() -> Void)?
    var onCurrentLocation: (() -> Void)?
    var onChooseCity: (() -> Void)?
    var onQuit: (() -> Void)?
    var onCitySearch: ((String) -> Void)?
    var onCityConfirm: ((Int) -> Void)?
    var onLoginChanged: ((Bool) -> Void)?

    private(set) var preferredSize = NSSize(width: 360, height: 304)
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
    private var candidatePopup: NSPopUpButton?
    private var loginCheckbox: NSButton?
    private var currentLocationButton: NSButton?
    private var searchButton: NSButton?
    private var confirmButton: NSButton?
    private var selectedCandidate = -1

    private let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private let monoMedium = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    private let accent = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.96, green: 0.76, blue: 0.30, alpha: 1)
            : NSColor(calibratedRed: 0.55, green: 0.34, blue: 0.02, alpha: 1)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("go/outside")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    func render(model: OutsideModel, screen: OutsideScreen, locationMessage: String,
                isRequesting: Bool, candidates: [CityCandidate], loginEnabled: Bool) {
        let signature = candidates.map { "\($0.name)|\($0.latitude)|\($0.longitude)" }.joined(separator: "\n")
        let screenChanged = self.screen != screen
        let resultsChanged = candidateSignature != signature
        self.model = model
        self.screen = screen
        self.locationMessage = locationMessage
        self.isRequesting = isRequesting
        self.loginEnabled = loginEnabled
        self.candidates = candidates
        self.candidateSignature = signature
        switch screen {
        case .main: preferredSize = NSSize(width: 360, height: 304)
        case .setup: preferredSize = NSSize(width: 360, height: 400)
        case .settings: preferredSize = NSSize(width: 360, height: 400)
        case .city: preferredSize = NSSize(width: 360, height: 360)
        }
        setFrameSize(preferredSize)
        setAccessibilityLabel(accessibilitySummary())

        if screenChanged || resultsChanged || !controlsBuilt {
            rebuildControls()
        } else {
            updateControlValues()
        }
        needsDisplay = true
    }

    private func accessibilitySummary() -> String {
        switch screen {
        case .main:
            return "\(model.accessibility) \(model.context). \(model.message)"
        case .setup:
            let purpose = locationMessage.isEmpty
                ? "Your location is used to estimate sunrise and sunset."
                : locationMessage
            return "go/outside setup. Tracking runs only while go/outside is open. It pauses after 60 seconds without input. \(purpose)"
        case .settings:
            let location = model.locationName.isEmpty ? "No location is saved." : "Location: \(model.locationName)."
            let status = locationMessage.isEmpty ? "" : " \(locationMessage)"
            return "go/outside settings. \(location)\(status) Computer time stays on this Mac. Location lookup may use Apple services."
        case .city:
            let status = locationMessage.isEmpty ? "Search by city and country." : locationMessage
            return "go/outside city selection. \(status)"
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        let line = NSColor.separatorColor
        line.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()
        drawHeader()
        switch screen {
        case .main: drawMain()
        case .setup: drawSetup()
        case .settings: drawSettings()
        case .city: drawCity()
        }
    }

    private func drawHeader() {
        drawText("go/outside", at: NSPoint(x: 16, y: bounds.height - 29), font: monoMedium)
        let status = model.isAway ? "AWAY" : (screen == .main ? "TODAY" : "")
        drawText(status, at: NSPoint(x: bounds.width - 16, y: bounds.height - 29), font: monoMedium,
                 alignment: .right, color: model.isAway ? accent : .secondaryLabelColor)
        NSColor.separatorColor.setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 0, y: bounds.height - 44))
        line.line(to: NSPoint(x: bounds.width, y: bounds.height - 44))
        line.lineWidth = 1
        line.stroke()
    }

    private func drawMain() {
        let top = bounds.height - 64
        drawText("ON YOUR COMPUTER", at: NSPoint(x: 16, y: top), font: monoMedium)
        drawText("DAYLIGHT LEFT", at: NSPoint(x: bounds.width - 16, y: top), font: monoMedium,
                 alignment: .right, color: accent)
        drawText(model.computerText, at: NSPoint(x: 16, y: top - 52), font: NSFont.monospacedSystemFont(ofSize: 36, weight: .regular))
        drawText(model.daylightText, at: NSPoint(x: bounds.width - 16, y: top - 52), font: NSFont.monospacedSystemFont(ofSize: 36, weight: .regular),
                 alignment: .right, color: accent)
        drawText("/", at: NSPoint(x: bounds.midX, y: top - 44), font: NSFont.monospacedSystemFont(ofSize: 24, weight: .regular),
                 alignment: .center, color: .secondaryLabelColor)
        drawText(model.context, in: NSRect(x: 16, y: top - 96, width: bounds.width - 32, height: 36), font: mono,
                 color: .secondaryLabelColor)
        drawText(model.message, in: NSRect(x: 16, y: top - 132, width: bounds.width - 32, height: 36), font: monoMedium)
        drawText("Solid: computer · Hollow: daylight left", at: NSPoint(x: 16, y: 65), font: mono,
                 color: .secondaryLabelColor)
        drawFooter()
    }

    private func drawSetup() {
        drawText("SET UP LOCATION", at: NSPoint(x: 16, y: bounds.height - 76), font: monoMedium)
        drawText("Tracking starts while go/outside is running.\nIdle for 60 seconds and the count pauses.",
                 in: NSRect(x: 16, y: bounds.height - 143, width: bounds.width - 32, height: 42), font: mono,
                 color: .secondaryLabelColor)
        drawText(locationMessage.isEmpty ? "Your location is used to estimate sunrise and sunset." : locationMessage,
                 in: NSRect(x: 16, y: bounds.height - 200, width: bounds.width - 32, height: 42), font: mono)
        drawText("A city is saved only as a coarse coordinate. No account or history.",
                 in: NSRect(x: 16, y: 82, width: bounds.width - 32, height: 32), font: mono,
                 color: .secondaryLabelColor)
        drawFooter()
    }

    private func drawSettings() {
        drawText("SETTINGS", at: NSPoint(x: 16, y: bounds.height - 76), font: monoMedium)
        drawText("LOCATION", at: NSPoint(x: 16, y: bounds.height - 112), font: monoMedium, color: accent)
        let name = model.locationName.isEmpty ? "No location saved" : model.locationName
        drawText(model.isLastKnown ? name + " · last known" : name,
                 at: NSPoint(x: 16, y: bounds.height - 140), font: mono)
        drawText(locationMessage.isEmpty
                     ? "Computer time stays on this Mac. Location lookup may use Apple services."
                     : locationMessage,
                 in: NSRect(x: 16, y: bounds.height - 190, width: bounds.width - 32, height: 36), font: mono,
                 color: .secondaryLabelColor)
        drawFooter(back: true)
    }

    private func drawCity() {
        drawText("CHOOSE A CITY", at: NSPoint(x: 16, y: bounds.height - 76), font: monoMedium)
        drawText(locationMessage.isEmpty ? "Search by city and country." : locationMessage,
                 in: NSRect(x: 16, y: bounds.height - 112, width: bounds.width - 32, height: 32), font: mono,
                 color: .secondaryLabelColor)
        if candidates.isEmpty && !isRequesting {
            drawText("Results will appear here.", at: NSPoint(x: 16, y: 126), font: mono, color: .secondaryLabelColor)
        }
        drawFooter(back: true)
    }

    private func drawFooter(back: Bool = false) {
        NSColor.separatorColor.setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 0, y: 48))
        line.line(to: NSPoint(x: bounds.width, y: 48))
        line.lineWidth = 1
        line.stroke()
    }

    private func rebuildControls() {
        let previousSearchText = searchField?.stringValue ?? ""
        controls.forEach { $0.removeFromSuperview() }
        controls.removeAll()
        searchField = nil
        candidatePopup = nil
        loginCheckbox = nil
        currentLocationButton = nil
        searchButton = nil
        confirmButton = nil
        selectedCandidate = candidates.isEmpty ? -1 : 0

        switch screen {
        case .main:
            addButton("Settings", frame: NSRect(x: 0, y: 0, width: bounds.width / 2, height: 48), action: #selector(settingsPressed), label: "Open settings")
            addButton("Quit", frame: NSRect(x: bounds.width / 2, y: 0, width: bounds.width / 2, height: 48), action: #selector(quitPressed), label: "Quit go/outside")
        case .setup:
            currentLocationButton = addButton("Use current location", frame: NSRect(x: 16, y: bounds.height - 230, width: bounds.width - 32, height: 34), action: #selector(currentLocationPressed), label: "Use current location")
            addButton("Choose a city", frame: NSRect(x: 16, y: bounds.height - 276, width: bounds.width - 32, height: 34), action: #selector(chooseCityPressed), label: "Choose a city")
            loginCheckbox = addCheckbox()
            addButton("Settings", frame: NSRect(x: 0, y: 0, width: bounds.width / 2, height: 48), action: #selector(settingsPressed), label: "Open settings")
            addButton("Quit", frame: NSRect(x: bounds.width / 2, y: 0, width: bounds.width / 2, height: 48), action: #selector(quitPressed), label: "Quit go/outside")
        case .settings:
            addButton("Back", frame: NSRect(x: 0, y: 0, width: bounds.width / 2, height: 48), action: #selector(backPressed), label: "Back")
            currentLocationButton = addButton("Refresh location", frame: NSRect(x: 16, y: bounds.height - 240, width: bounds.width - 32, height: 32), action: #selector(currentLocationPressed), label: "Refresh current location")
            addButton("Choose a city", frame: NSRect(x: 16, y: bounds.height - 282, width: bounds.width - 32, height: 32), action: #selector(chooseCityPressed), label: "Choose a city")
            loginCheckbox = addCheckbox()
        case .city:
            addButton("Back", frame: NSRect(x: 0, y: 0, width: bounds.width / 2, height: 48), action: #selector(backPressed), label: "Back")
            let field = NSTextField(frame: NSRect(x: 16, y: bounds.height - 157, width: bounds.width - 112, height: 32))
            field.placeholderString = "City, country"
            field.stringValue = previousSearchText
            field.font = mono
            field.target = self
            field.action = #selector(searchPressed)
            field.setAccessibilityLabel("City and country")
            addControl(field)
            searchField = field
            searchButton = addButton("Search", frame: NSRect(x: bounds.width - 88, y: bounds.height - 157, width: 72, height: 32), action: #selector(searchPressed), label: "Search city")
            let popup = NSPopUpButton(frame: NSRect(x: 16, y: 132, width: bounds.width - 32, height: 32), pullsDown: false)
            popup.font = mono
            popup.addItems(withTitles: candidates.map(\.name))
            popup.target = self
            popup.action = #selector(candidatePopupChanged(_:))
            popup.setAccessibilityLabel("City results")
            popup.isEnabled = !candidates.isEmpty
            if !candidates.isEmpty { popup.selectItem(at: 0) }
            addControl(popup)
            candidatePopup = popup
            confirmButton = addButton("Confirm city", frame: NSRect(x: 16, y: 74, width: bounds.width - 32, height: 32), action: #selector(confirmCityPressed), label: "Confirm selected city")
            if previousSearchText.isEmpty == false {
                DispatchQueue.main.async { [weak field] in field?.window?.makeFirstResponder(field) }
            }
        }
        controlsBuilt = true
        updateControlValues()
    }

    private func updateControlValues() {
        loginCheckbox?.state = loginEnabled ? .on : .off
        currentLocationButton?.title = isRequesting ? "Finding location…" : (screen == .settings ? "Refresh location" : "Use current location")
        currentLocationButton?.isEnabled = !isRequesting
        searchButton?.title = isRequesting ? "Searching…" : "Search"
        searchButton?.isEnabled = !isRequesting
        confirmButton?.isEnabled = selectedCandidate >= 0 && !candidates.isEmpty && !isRequesting
        needsDisplay = true
    }

    @discardableResult
    private func addButton(_ title: String, frame: NSRect, action: Selector, label: String, tag: Int = 0) -> NSButton {
        let button = GridButton(title: title, target: self, action: action)
        button.frame = frame
        button.tag = tag
        button.font = monoMedium
        button.setAccessibilityLabel(label)
        addControl(button)
        return button
    }

    private func addCheckbox() -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(loginChanged(_:)))
        checkbox.frame = NSRect(x: 16, y: 58, width: 220, height: 24)
        checkbox.font = mono
        checkbox.setAccessibilityLabel("Launch go/outside at login")
        addControl(checkbox)
        return checkbox
    }

    private func addControl(_ control: NSControl) {
        addSubview(control)
        controls.append(control)
    }

    private func drawText(_ value: String, at point: NSPoint, font: NSFont, alignment: NSTextAlignment = .left, color: NSColor = .labelColor) {
        let rect: NSRect
        switch alignment {
        case .right:
            rect = NSRect(x: 16, y: point.y, width: max(0, point.x - 16), height: font.pointSize + 8)
        case .center:
            rect = NSRect(x: 16, y: point.y, width: max(0, bounds.width - 32), height: font.pointSize + 8)
        default:
            rect = NSRect(x: point.x, y: point.y, width: max(0, bounds.width - point.x - 16), height: font.pointSize + 8)
        }
        drawText(value, in: rect, font: font, alignment: alignment, color: color)
    }

    private func drawText(_ value: String, in rect: NSRect, font: NSFont, alignment: NSTextAlignment = .left, color: NSColor = .labelColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        (value as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }

    @objc private func settingsPressed() { onSettings?() }
    @objc private func backPressed() { onBack?() }
    @objc private func quitPressed() { onQuit?() }
    @objc private func currentLocationPressed() { onCurrentLocation?() }
    @objc private func chooseCityPressed() { onChooseCity?() }
    @objc private func searchPressed() { onCitySearch?(searchField?.stringValue ?? "") }
    @objc private func candidatePopupChanged(_ sender: NSPopUpButton) {
        selectedCandidate = sender.indexOfSelectedItem
        needsDisplay = true
    }
    @objc private func confirmCityPressed() {
        guard selectedCandidate >= 0 else { return }
        onCityConfirm?(selectedCandidate)
    }
    @objc private func loginChanged(_ sender: NSButton) { onLoginChanged?(sender.state == .on) }
}
