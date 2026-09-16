import AppKit
import Foundation

// Login items are intentionally silent. Launching the parent with this flag
// lets the app distinguish a background login launch from a user opening it.
let parentBundleIdentifier = "com.gooutside.desktop"

let embeddedParentURL = Bundle.main.bundleURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let parentURL = Bundle(url: embeddedParentURL)?.bundleIdentifier == parentBundleIdentifier
    ? embeddedParentURL
    : NSWorkspace.shared.urlForApplication(withBundleIdentifier: parentBundleIdentifier)

if let parentURL {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.hides = true
    configuration.arguments = ["--login-item"]
    NSWorkspace.shared.openApplication(at: parentURL, configuration: configuration) { _, _ in
        exit(0)
    }
} else {
    exit(0)
}

RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
