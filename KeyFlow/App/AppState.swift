import Foundation

@MainActor
final class AppState: ObservableObject {
    private static let isInstalledAppDiscoveryEnabled = true

    let launcherKey = LauncherKey.defaultKey
    private(set) var selectedKey: KeyboardKey?
    @Published private(set) var rules: [KeyRule] = [] {
        didSet {
            rebuildRuleIndex()
        }
    }
    @Published private(set) var installedApps: [InstalledApp] = []
    @Published private(set) var isEngineRunning = false
    @Published private(set) var permissionStatus = PermissionStatus()

    private let permissionService = PermissionService()
    private let keyboardEngine = KeyboardEventEngine()
    private let appDiscovery: @Sendable () -> [InstalledApp]
    private var rulesByShortcut: [ShortcutKey: KeyRule] = [:]
    private var installedAppsReloadTask: Task<Void, Never>?
    private var isReloadingInstalledApps = false

    init(
        appDiscovery: @escaping @Sendable () -> [InstalledApp] = {
            AppDiscoveryService().installedApps()
        },
        loadsInstalledAppsOnInit: Bool = true
    ) {
        self.appDiscovery = appDiscovery
        refreshPermissions()

        if loadsInstalledAppsOnInit, Self.isInstalledAppDiscoveryEnabled {
            reloadInstalledApps()
        }
    }

    func select(_ key: KeyboardKey) {
        selectedKey = key
    }

    func rule(for key: KeyboardKey) -> KeyRule? {
        rulesByShortcut[shortcutKey(for: key)]
    }

    func saveRule(for key: KeyboardKey, action: KeyAction) {
        let trigger = trigger(for: key)

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
        let trigger = trigger(for: key)
        rules.removeAll { $0.trigger == trigger }
        syncKeyboardEngine()
    }

    func setLauncherKey(_ key: LauncherKey) {
        syncKeyboardEngine()
    }

    func reloadInstalledApps() {
        guard Self.isInstalledAppDiscoveryEnabled else {
            return
        }

        guard !isReloadingInstalledApps else {
            return
        }

        isReloadingInstalledApps = true
        let appDiscovery = appDiscovery

        installedAppsReloadTask = Task.detached(priority: .utility) { [weak self] in
            let apps = appDiscovery()
            let wasCancelled = Task.isCancelled

            await MainActor.run {
                guard let self else {
                    return
                }

                self.installedAppsReloadTask = nil
                self.isReloadingInstalledApps = false

                if !wasCancelled {
                    self.installedApps = apps
                }
            }
        }
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

    func requestMissingPermissions() {
        let needsAccessibility = !permissionStatus.isAccessibilityTrusted
        let needsInputMonitoring = !permissionStatus.canListenToEvents

        if needsAccessibility {
            permissionService.requestAccessibilityPermission()
        }

        if needsInputMonitoring {
            permissionService.requestListenEventPermission()
        }

        if needsAccessibility {
            PermissionService.openAccessibilitySettings()
        } else if needsInputMonitoring {
            PermissionService.openInputMonitoringSettings()
        }
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

    private func trigger(for key: KeyboardKey) -> KeyTrigger {
        KeyTrigger(
            launcherKeyCode: launcherKey.keyCode,
            launcherDisplayName: launcherKey.displayName,
            keyCode: key.keyCode
        )
    }

    private func shortcutKey(for key: KeyboardKey) -> ShortcutKey {
        ShortcutKey(
            launcherKeyCode: launcherKey.keyCode,
            keyCode: key.keyCode
        )
    }

    private func rebuildRuleIndex() {
        rulesByShortcut = Dictionary(
            uniqueKeysWithValues: rules.map {
                (
                    ShortcutKey(
                        launcherKeyCode: $0.trigger.launcherKeyCode,
                        keyCode: $0.trigger.keyCode
                    ),
                    $0
                )
            }
        )
    }

    deinit {
        installedAppsReloadTask?.cancel()
    }
}

private struct ShortcutKey: Hashable {
    let launcherKeyCode: Int
    let keyCode: Int
}
