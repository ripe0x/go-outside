import Foundation
import ServiceManagement

/// Registers the bundled login item while keeping macOS 12 support.
final class LoginLaunch {
    static let helperBundleIdentifier = "com.gooutside.desktop.login-helper"
    private static let legacyEnabledKey = "go.outside.login-item.enabled"

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.loginItem(identifier: helperBundleIdentifier).status == .enabled
        }

        // SMLoginItemSetEnabled has no status query on macOS 12. Remember the
        // last successful request while documenting that limitation.
        return UserDefaults.standard.bool(forKey: legacyEnabledKey)
    }

    static func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            let service = SMAppService.loginItem(identifier: helperBundleIdentifier)
            if enabled {
                try service.register()
                if service.status == .requiresApproval {
                    throw LoginLaunchError.approvalRequired
                }
            } else {
                try service.unregister()
            }
            return
        }

        guard SMLoginItemSetEnabled(helperBundleIdentifier as CFString, enabled) else {
            throw LoginLaunchError.registrationFailed
        }
        UserDefaults.standard.set(enabled, forKey: legacyEnabledKey)
    }
}

enum LoginLaunchError: LocalizedError {
    case registrationFailed
    case approvalRequired

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "macOS could not update the go/outside launch-at-login setting."
        case .approvalRequired:
            return "Open System Settings to approve go/outside under Login Items."
        }
    }
}
