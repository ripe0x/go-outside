import AppKit
import Foundation

func runViewTests() {
    _ = NSApplication.shared
    let view = OutsideView(frame: NSRect(x: 0, y: 0, width: 360, height: 360))
    let normal = OutsideModel(computer: 4 * 3_600, solar: nil, locationName: "", isLastKnown: false, isAway: false)
    let long = OutsideModel(computer: 23 * 3_600 + 59 * 60, solar: nil, locationName: "", isLastKnown: false, isAway: false)
    let longLocation = OutsideModel(computer: 4 * 3_600, solar: nil, locationName: "San Francisco, California, United States", isLastKnown: true, isAway: false)
    var backPressed = false
    var query = ""
    var confirmed: Int?
    view.onBack = { backPressed = true }
    view.onCitySearch = { query = $0 }
    view.onCityConfirm = { confirmed = $0 }

    func render(_ screen: OutsideScreen, model: OutsideModel = normal, candidates: [CityCandidate] = []) {
        view.render(model: model, screen: screen, locationMessage: "", isRequesting: false, candidates: candidates, loginEnabled: false)
    }
    func button(_ title: String) -> NSButton {
        guard let button = view.subviews.compactMap({ $0 as? NSButton }).first(where: { $0.title == title }) else {
            preconditionFailure("Missing native button: \(title)")
        }
        return button
    }
    func checkGeometry() {
        precondition(view.atmosphereBounds.minY == view.contentBounds.maxY)
        precondition(view.atmosphereBounds.height == view.bounds.height / 3)
        precondition(view.contentBounds.height == view.bounds.height * 2 / 3)
        for control in view.subviews.compactMap({ $0 as? NSControl }) {
            precondition(view.contentBounds.contains(control.frame), "Controls must stay below the atmosphere")
            precondition(!view.contentTextBounds.contains(where: { $0.intersects(control.frame) }), "Text and controls must not overlap")
        }
    }

    render(.main, model: long)
    precondition(view.frame.size == NSSize(width: 360, height: 360))
    precondition(view.subviews.compactMap({ $0 as? NSButton }).isEmpty, "Main must not expose settings or quit buttons")
    checkGeometry()

    render(.setup)
    precondition(view.frame.size == NSSize(width: 360, height: 540))
    _ = button("Use current location")
    _ = button("Choose a city")
    precondition(!view.subviews.compactMap({ $0 as? NSButton }).contains(where: { $0.title == "Back" }), "Setup has no parent screen")
    let setupAccessibility = view.accessibilityLabel() ?? ""
    precondition(setupAccessibility.contains("60") && setupAccessibility.contains("location"), "Setup accessibility must explain tracking and location")
    checkGeometry()

    render(.settings, model: longLocation)
    _ = button("Refresh location")
    _ = button("Choose a city")
    button("Back").performClick(nil)
    precondition(backPressed, "Settings must retain Back")
    checkGeometry()

    render(.city)
    guard let field = view.subviews.compactMap({ $0 as? NSTextField }).first(where: { $0.isEditable }) else {
        preconditionFailure("Missing city search field")
    }
    field.stringValue = "Brooklyn, USA"
    button("Search").performClick(nil)
    precondition(query == "Brooklyn, USA")
    let candidates = [CityCandidate(name: "Brooklyn, NY, US", latitude: 40.68, longitude: -73.94),
                      CityCandidate(name: "Brooklyn, WI, US", latitude: 42.85, longitude: -89.37)]
    render(.city, candidates: candidates)
    precondition(view.frame.size == NSSize(width: 360, height: 480))
    let fields = view.subviews.compactMap({ $0 as? NSTextField }).filter { $0.isEditable }
    precondition(fields.first?.stringValue == "Brooklyn, USA", "City results must preserve the typed query")
    guard let picker = view.subviews.compactMap({ $0 as? NSPopUpButton }).first else {
        preconditionFailure("Missing city result picker")
    }
    picker.selectItem(at: 1)
    if let action = picker.action { NSApp.sendAction(action, to: picker.target, from: picker) }
    button("Confirm city").performClick(nil)
    precondition(confirmed == 1, "Confirmation must use the selected city")
    backPressed = false
    button("Back").performClick(nil)
    precondition(backPressed, "City must retain Back")
    checkGeometry()
    print("PASS: top-third atmosphere, monochrome content layout, controls and city selection")
}
