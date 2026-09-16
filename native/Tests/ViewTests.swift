import AppKit
import Foundation

func runViewTests() {
    _ = NSApplication.shared
    let view = OutsideView(frame: NSRect(x: 0, y: 0, width: 360, height: 280))
    let model = OutsideModel(computer: 4 * 3600, solar: nil, locationName: "", isLastKnown: false, isAway: false)
    var settingsOpened = false
    var backPressed = false
    var query = ""
    var confirmed: Int?
    view.onSettings = { settingsOpened = true }
    view.onBack = { backPressed = true }
    view.onCitySearch = { query = $0 }
    view.onCityConfirm = { confirmed = $0 }

    func render(_ screen: OutsideScreen, candidates: [CityCandidate] = []) {
        view.render(model: model, screen: screen, locationMessage: "", isRequesting: false,
                    candidates: candidates, loginEnabled: false)
    }
    func button(_ title: String) -> NSButton {
        guard let button = view.subviews.compactMap({ $0 as? NSButton }).first(where: { $0.title == title }) else {
            preconditionFailure("Missing native button: \(title)")
        }
        return button
    }
    render(.main)
    button("Settings").performClick(nil)
    precondition(settingsOpened, "Initial main render must create usable controls")
    render(.settings)
    button("Back").performClick(nil)
    precondition(backPressed, "Settings must have a working Back control")
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
    let fields = view.subviews.compactMap({ $0 as? NSTextField }).filter { $0.isEditable }
    precondition(fields.first?.stringValue == "Brooklyn, USA", "City results must preserve the typed query")
    if let picker = view.subviews.compactMap({ $0 as? NSPopUpButton }).first {
        precondition(picker.numberOfItems >= 2)
        picker.selectItem(at: picker.numberOfItems - 1)
        if let action = picker.action { NSApp.sendAction(action, to: picker.target, from: picker) }
    } else {
        button("Brooklyn, WI, US").performClick(nil)
    }
    button("Confirm city").performClick(nil)
    precondition(confirmed == 1, "Confirmation must use the selected disambiguated city")
    render(.setup)
    let setupAccessibility = view.accessibilityLabel() ?? ""
    precondition(setupAccessibility.contains("60") && setupAccessibility.contains("location"),
                 "Setup accessibility must explain idle tracking and location purpose")
    precondition(view.frame.size == view.preferredSize, "Controls must lay out at the current screen size")
    for control in view.subviews.compactMap({ $0 as? NSControl }) {
        precondition(view.bounds.contains(control.frame), "Controls must fit the screen")
    }
    print("PASS: initial controls, Back, city search/selection and stable screen layout")
}
