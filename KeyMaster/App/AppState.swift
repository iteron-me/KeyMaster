import Foundation

@MainActor
final class AppState: ObservableObject {
    private static let isInstalledAppDiscoveryEnabled = true

    private(set) var selectedKey: KeyboardKey?
    @Published private(set) var activeModifiers: Set<ModifierKey> = []
    @Published private(set) var activeModifierKeyCodes: Set<Int> = []
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
    private let modifierLayerMonitor = ModifierLayerMonitor()
    private let ruleStore: KeyRuleStore
    private let appDiscovery: @Sendable () -> [InstalledApp]
    private var rulesByShortcut: [ShortcutKey: KeyRule] = [:]
    private var rulesByKeyCode: [Int: [KeyRule]] = [:]
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
        modifierLayerMonitor.start { [weak self] snapshot in
            self?.setActiveModifierSnapshot(snapshot)
        }

        if loadsInstalledAppsOnInit, Self.isInstalledAppDiscoveryEnabled {
            reloadInstalledApps()
        }
    }

    func select(_ key: KeyboardKey) {
        selectedKey = key
    }

    func rule(for key: KeyboardKey) -> KeyRule? {
        rule(for: key, modifiers: activeModifiers)
    }

    func rule(for key: KeyboardKey, modifiers: Set<ModifierKey>) -> KeyRule? {
        rulesByShortcut[ShortcutKey(modifiers: modifiers, keyCode: key.keyCode)]
    }

    func rules(for key: KeyboardKey) -> [KeyRule] {
        rulesByKeyCode[key.keyCode] ?? []
    }

    func hasRules(for key: KeyboardKey) -> Bool {
        !(rulesByKeyCode[key.keyCode] ?? []).isEmpty
    }

    func visibleRules(for key: KeyboardKey) -> [KeyRule] {
        if activeModifiers.isEmpty {
            return rules(for: key)
        }

        return rule(for: key, modifiers: activeModifiers).map { [$0] } ?? []
    }

    func saveRule(for key: KeyboardKey, action: KeyAction) {
        saveRule(for: key, modifiers: activeModifiers, action: action)
    }

    func saveRule(for key: KeyboardKey, modifiers: Set<ModifierKey>, action: KeyAction) {
        let trigger = trigger(for: key, modifiers: modifiers)
        recordHistory(for: action)

        if let index = rules.firstIndex(where: { $0.trigger == trigger }) {
            rules[index].name = trigger.displayTitle
            rules[index].action = action
            rules[index].updatedAt = Date()
            persistRules()
            syncKeyboardEngine()
            return
        }

        rules.append(
            KeyRule(
                name: trigger.displayTitle,
                trigger: trigger,
                action: action
            )
        )
        persistRules()
        syncKeyboardEngine()
    }

    func saveRule(for key: KeyboardKey, webHistoryItem item: WebActionHistoryItem) {
        saveRule(for: key, modifiers: activeModifiers, action: .openURL(name: item.name, url: item.url))
    }

    func saveRule(for key: KeyboardKey, commandHistoryItem item: CommandActionHistoryItem) {
        saveRule(for: key, modifiers: activeModifiers, action: .runCommand(name: item.name, command: item.command))
    }

    func saveRule(for key: KeyboardKey, keyStroke: KeyStroke) {
        saveRule(for: key, modifiers: activeModifiers, action: .sendKeyStroke(keyStroke))
    }

    func deleteRule(for key: KeyboardKey) {
        deleteRule(for: key, modifiers: activeModifiers)
    }

    func deleteRule(for key: KeyboardKey, modifiers: Set<ModifierKey>) {
        let trigger = trigger(for: key, modifiers: modifiers)
        rules.removeAll { $0.trigger == trigger }
        persistRules()
        syncKeyboardEngine()
    }

    func deleteRule(_ rule: KeyRule) {
        rules.removeAll { $0.id == rule.id }
        persistRules()
        syncKeyboardEngine()
    }

    func deleteWebHistoryItem(_ item: WebActionHistoryItem) {
        var updatedHistory = actionHistory

        guard updatedHistory.delete(item) else {
            return
        }

        actionHistory = updatedHistory
        persistActionHistory()
    }

    func deleteCommandHistoryItem(_ item: CommandActionHistoryItem) {
        var updatedHistory = actionHistory

        guard updatedHistory.delete(item) else {
            return
        }

        actionHistory = updatedHistory
        persistActionHistory()
    }

    func setLauncherKey(_ key: LauncherKey) {
        syncKeyboardEngine()
    }

    func setActiveModifiers(_ modifiers: Set<ModifierKey>) {
        activeModifiers = modifiers
        activeModifierKeyCodes = []
    }

    func setActiveModifierSnapshot(_ snapshot: ModifierSnapshot) {
        activeModifiers = snapshot.modifiers
        activeModifierKeyCodes = snapshot.keyCodes
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
            var didMigrateRules = false
            rules = try ruleStore.loadRules().map { rule in
                var rule = rule
                rule.name = rule.trigger.displayTitle
                if rule.action.isLegacyLockScreenCommand {
                    rule.action = .lockScreen
                    rule.updatedAt = Date()
                    didMigrateRules = true
                }
                return rule
            }
            rulePersistenceErrorMessage = nil
            if didMigrateRules {
                persistRules()
            }
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

            _ = loadedHistory.removeLegacyCommandPresets()
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

    private func trigger(for key: KeyboardKey, modifiers: Set<ModifierKey>) -> KeyTrigger {
        KeyTrigger(
            modifiers: modifiers,
            keyCode: key.keyCode,
            keyDisplayName: key.label
        )
    }

    private func rebuildRuleIndex() {
        rulesByShortcut = Dictionary(
            uniqueKeysWithValues: rules.map {
                (
                    ShortcutKey(
                        modifiers: $0.trigger.modifiers,
                        keyCode: $0.trigger.keyCode
                    ),
                    $0
                )
            }
        )
        rulesByKeyCode = Dictionary(grouping: rules.sorted { lhs, rhs in
            if lhs.trigger.modifiers.count != rhs.trigger.modifiers.count {
                return lhs.trigger.modifiers.count < rhs.trigger.modifiers.count
            }

            return lhs.updatedAt > rhs.updatedAt
        }) { rule in
            rule.trigger.keyCode
        }
    }

    deinit {
        installedAppsReloadTask?.cancel()
        Task { @MainActor [modifierLayerMonitor] in
            modifierLayerMonitor.stop()
        }
    }
}

private struct ShortcutKey: Hashable {
    let modifiers: Set<ModifierKey>
    let keyCode: Int
}

private extension KeyAction {
    var isLegacyLockScreenCommand: Bool {
        guard case .runCommand(let name, let command) = self else {
            return false
        }

        return name == CommandActionHistoryItem.lockScreenName
            && command == CommandActionHistoryItem.legacyLockScreenCommand
    }
}
