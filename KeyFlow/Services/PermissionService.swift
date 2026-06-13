import AppKit
import ApplicationServices

struct PermissionStatus: Equatable {
    var isAccessibilityTrusted = false
    var canListenToEvents = false

    var canRunShortcutEngine: Bool {
        isAccessibilityTrusted && canListenToEvents
    }

    var missingRequiredPermissionNames: [String] {
        var names: [String] = []

        if !isAccessibilityTrusted {
            names.append("Accessibility")
        }

        if !canListenToEvents {
            names.append("Input Monitoring")
        }

        return names
    }
}

struct PermissionService {
    func currentStatus() -> PermissionStatus {
        PermissionStatus(
            isAccessibilityTrusted: AXIsProcessTrusted(),
            canListenToEvents: CGPreflightListenEventAccess()
        )
    }

    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func requestListenEventPermission() {
        _ = CGRequestListenEventAccess()
    }
    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    static func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
