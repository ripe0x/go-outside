import AppKit

enum OutsideStatusMenu {
    static func shouldOpen(for event: NSEvent?) -> Bool {
        guard let event else { return false }
        return event.type == .rightMouseUp || event.type == .rightMouseDown
            || event.modifierFlags.contains(.control)
    }

    static func make(target: AnyObject, settings: Selector, quit: Selector) -> NSMenu {
        let menu = NSMenu(title: "go/outside")
        let settingsItem = NSMenuItem(title: "Settings…", action: settings, keyEquivalent: ",")
        settingsItem.target = target
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit go/outside", action: quit, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)
        return menu
    }
}
