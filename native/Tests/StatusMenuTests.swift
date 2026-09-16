import AppKit

private final class StatusMenuTarget: NSObject {
    var settingsOpened = false
    var quitRequested = false

    @objc func settings(_ sender: Any?) { settingsOpened = true }
    @objc func quit(_ sender: Any?) { quitRequested = true }
}

func runStatusMenuTests() {
    _ = NSApplication.shared
    func event(_ type: NSEvent.EventType, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: modifiers,
                          timestamp: 0, windowNumber: 0, context: nil,
                          eventNumber: 0, clickCount: 1, pressure: 0)!
    }
    precondition(!OutsideStatusMenu.shouldOpen(for: event(.leftMouseUp)))
    precondition(OutsideStatusMenu.shouldOpen(for: event(.rightMouseUp)))
    precondition(OutsideStatusMenu.shouldOpen(for: event(.leftMouseUp, modifiers: .control)))
    precondition(!OutsideStatusMenu.shouldOpen(for: nil))

    let target = StatusMenuTarget()
    let menu = OutsideStatusMenu.make(target: target,
                                     settings: #selector(StatusMenuTarget.settings(_:)),
                                     quit: #selector(StatusMenuTarget.quit(_:)))
    menu.performActionForItem(at: 0)
    precondition(target.settingsOpened, "The context menu must open Settings")
    menu.performActionForItem(at: 2)
    precondition(target.quitRequested, "The context menu must offer a working Quit action")
    precondition(menu.items[0].keyEquivalent == "," && menu.items[2].keyEquivalent == "q",
                 "Settings and Quit must remain available by keyboard")
    func shortcut(_ characters: String, keyCode: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                        timestamp: 0, windowNumber: 0, context: nil,
                        characters: characters, charactersIgnoringModifiers: characters,
                        isARepeat: false, keyCode: keyCode)!
    }
    target.settingsOpened = false
    target.quitRequested = false
    precondition(menu.performKeyEquivalent(with: shortcut(",", keyCode: 43)) && target.settingsOpened,
                 "Command-comma must invoke Settings through AppKit")
    precondition(menu.performKeyEquivalent(with: shortcut("q", keyCode: 12)) && target.quitRequested,
                 "Command-Q must invoke Quit through AppKit")
    print("PASS: left/right/control-click routing and native Settings/Quit menu actions")
}
