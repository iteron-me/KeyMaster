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
    @Published private(set) var actionHistory = KeyActionHistory()
    @Published private(set) var isEngineRunning = false
    @Published private(set) var permissionStatus = PermissionStatus()
    @Published private(set) var rulePersistenceErrorMessage: String?

    private let permissionService = PermissionService()
    private let keyboardEngine = KeyboardEventEngine()
    private let ruleStore: KeyRuleStore
    private let appDiscovery: @Sendable () -> [InstalledApp]
    private var rulesByShortcut: [ShortcutKey: KeyRule] = [:]
    private var installedAppsReloadTask: Task<Void, Never>?
    private var isReloadingInstalledApps = false
    private var hasLoadedInstalledApps = false

    init(
        ruleStore: KeyRuleStore = FileKeyRuleStore(),
        appDiscovery: @escaping @Sendable () -> [InstalledApp] = {
            AppDiscoveryService().installedApps()
        },
        loadsInstalledAppsOnInit: Bool = true
    ) {
        self.ruleStore = ruleStore
        self.appDiscovery = appDiscovery
        loadPersistedRules()
        loadActionHistory()
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
        recordHistory(for: action)

        if let index = rules.firstIndex(where: { $0.trigger == trigger }) {
            rules[index].name = "\(launcherKey.displayName) + \(key.label)"
            rules[index].action = action
            rules[index].updatedAt = Date()
            persistRules()
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
        persistRules()
        syncKeyboardEngine()
    }

    func saveRule(for key: KeyboardKey, webHistoryItem item: WebActionHistoryItem) {
        saveRule(for: key, action: .openURL(name: item.name, url: item.url))
    }

    func saveRule(for key: KeyboardKey, commandHistoryItem item: CommandActionHistoryItem) {
        saveRule(for: key, action: .runCommand(name: item.name, command: item.command))
    }

    func deleteRule(for key: KeyboardKey) {
        let trigger = trigger(for: key)
        rules.removeAll { $0.trigger == trigger }
        persistRules()
        syncKeyboardEngine()
    }

    func setLauncherKey(_ key: LauncherKey) {
        syncKeyboardEngine()
    }

    func reloadInstalledApps(force: Bool = false) {
        guard Self.isInstalledAppDiscoveryEnabled else {
            return
        }

        guard force || !hasLoadedInstalledApps else {
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
                    self.hasLoadedInstalledApps = true
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

    private func loadPersistedRules() {
        do {
            rules = try ruleStore.loadRules()
            rulePersistenceErrorMessage = nil
        } catch {
            rules = []
            rulePersistenceErrorMessage = error.localizedDescription
        }
    }

    private func loadActionHistory() {
        do {
            var loadedHistory = try ruleStore.loadActionHistory()

            for rule in rules {
                _ = loadedHistory.record(rule.action)
            }

            actionHistory = loadedHistory
            rulePersistenceErrorMessage = nil

            do {
                try ruleStore.saveActionHistory(loadedHistory)
            } catch {
                rulePersistenceErrorMessage = error.localizedDescription
            }
        } catch {
            actionHistory = KeyActionHistory()
            rulePersistenceErrorMessage = error.localizedDescription
        }
    }

    private func persistRules() {
        do {
            try ruleStore.saveRules(rules)
            rulePersistenceErrorMessage = nil
        } catch {
            rulePersistenceErrorMessage = error.localizedDescription
        }
    }

    private func recordHistory(for action: KeyAction) {
        var updatedHistory = actionHistory

        guard updatedHistory.record(action) else {
            return
        }

        actionHistory = updatedHistory
        persistActionHistory()
    }

    private func persistActionHistory() {
        do {
            try ruleStore.saveActionHistory(actionHistory)
            rulePersistenceErrorMessage = nil
        } catch {
            rulePersistenceErrorMessage = error.localizedDescription
        }
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
