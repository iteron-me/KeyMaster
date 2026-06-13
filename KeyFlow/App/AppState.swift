import Foundation

final class AppState: ObservableObject {
    @Published var launcherKey = LauncherKey.defaultKey
    @Published var selectedKey: KeyboardKey?
    @Published var rules: [KeyRule] = []
    @Published var installedApps: [InstalledApp] = []
    @Published var isEngineRunning = false
    @Published var permissionStatus = PermissionStatus()
    @Published var isCapturingLauncherKey = false

    private let permissionService = PermissionService()
    private let keyboardEngine = KeyboardEventEngine()
    private let appDiscoveryService = AppDiscoveryService()

    init() {
        refreshPermissions()
        reloadInstalledApps()
    }

    func select(_ key: KeyboardKey) {
        selectedKey = key
    }

    func rule(for key: KeyboardKey) -> KeyRule? {
        return rules.first { rule in
            rule.trigger.launcherKeyCode == launcherKey.keyCode && rule.trigger.keyCode == key.keyCode
        }
    }

    func saveRule(for key: KeyboardKey, action: KeyAction) {
        let trigger = KeyTrigger(
            launcherKeyCode: launcherKey.keyCode,
            launcherDisplayName: launcherKey.displayName,
            keyCode: key.keyCode
        )

        if let index = rules.firstIndex(where: { $0.trigger == trigger }) {
            rules[index].name = "\(launcherKey.displayName) + \(key.label)"
            rules[index].action = action
            rules[index].updatedAt = Date()
            syncKeyboardEngine()
            return
        }

        rules.append(
            KeyRule(
                name: "\(launcherKey.displayName) + \(key.label)",
                trigger: trigger,
                action: action
            )
        )
        syncKeyboardEngine()
    }

    func deleteRule(for key: KeyboardKey) {
        let trigger = KeyTrigger(
            launcherKeyCode: launcherKey.keyCode,
            launcherDisplayName: launcherKey.displayName,
            keyCode: key.keyCode
        )
        rules.removeAll { $0.trigger == trigger }
        syncKeyboardEngine()
    }

    func setLauncherKey(_ key: LauncherKey) {
        launcherKey = key
        isCapturingLauncherKey = false
        syncKeyboardEngine()
    }

    func reloadInstalledApps() {
        installedApps = appDiscoveryService.installedApps()
    }

    func refreshPermissions() {
        permissionStatus = permissionService.currentStatus()

        syncKeyboardEngine()
    }

    func requestAccessibilityPermission() {
        permissionService.requestAccessibilityPermission()
        PermissionService.openAccessibilitySettings()
    }

    func requestInputMonitoringPermission() {
        permissionService.requestListenEventPermission()
        PermissionService.openInputMonitoringSettings()
    }

    private func syncKeyboardEngine() {
        guard permissionStatus.canRunShortcutEngine else {
            keyboardEngine.stop()
            isEngineRunning = false
            return
        }

        guard rules.contains(where: \.isEnabled) else {
            keyboardEngine.stop()
            isEngineRunning = false
            return
        }

        keyboardEngine.stop()
        keyboardEngine.start(rules: rules)
        isEngineRunning = keyboardEngine.isRunning
    }
}
