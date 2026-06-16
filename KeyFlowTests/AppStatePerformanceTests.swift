import Combine
import XCTest
@testable import KeyFlow

@MainActor
final class AppStatePerformanceTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    func testReloadInstalledAppsReturnsBeforeSlowDiscoveryCompletes() async throws {
        let discoveryStarted = expectation(description: "discovery started")
        let discoveryMayFinish = DispatchSemaphore(value: 0)
        let fixtureApp = Self.fixtureApp

        let appState = makeAppState(
            appDiscovery: {
                discoveryStarted.fulfill()
                _ = discoveryMayFinish.wait(timeout: .now() + 1)
                return [fixtureApp]
            }
        )

        appState.reloadInstalledApps()

        await fulfillment(of: [discoveryStarted], timeout: 1)
        XCTAssertTrue(appState.installedApps.isEmpty)

        discoveryMayFinish.signal()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(appState.installedApps, [fixtureApp])
    }

    func testOpeningKeyEditorDoesNotPublishGlobalAppStateChange() {
        let appState = makeAppState()
        var publishCount = 0

        appState.objectWillChange
            .sink { publishCount += 1 }
            .store(in: &cancellables)

        appState.select(KeyCatalog.defaultKeys[0])

        XCTAssertEqual(publishCount, 0)
    }

    func testRuleLookupUsesLauncherKeyCodeNotDisplayName() {
        let appState = makeAppState()
        let key = KeyCatalog.defaultKeys[1]

        appState.saveRule(
            for: key,
            action: .openURL(name: "Docs", url: "https://example.com")
        )
        appState.setLauncherKey(
            LauncherKey(keyCode: LauncherKey.defaultKey.keyCode, displayName: "Left Control")
        )

        XCTAssertNotNil(appState.rule(for: key))
    }

    func testLauncherKeyRemainsFixedToControl() {
        let appState = makeAppState()
        let key = KeyCatalog.defaultKeys[1]

        appState.setLauncherKey(
            LauncherKey(keyCode: 55, displayName: "Command")
        )
        appState.saveRule(
            for: key,
            action: .openURL(name: "Docs", url: "https://example.com")
        )

        XCTAssertEqual(appState.launcherKey, .defaultKey)
        XCTAssertEqual(appState.rules.first?.trigger.launcherKeyCode, LauncherKey.defaultKey.keyCode)
        XCTAssertEqual(appState.rules.first?.trigger.launcherDisplayName, LauncherKey.defaultKey.displayName)
    }

    func testInitializesWithPersistedRules() {
        let key = KeyCatalog.defaultKeys[1]
        let rule = Self.rule(for: key)
        let store = InMemoryKeyRuleStore(initialRules: [rule])

        let appState = AppState(ruleStore: store, loadsInstalledAppsOnInit: false)

        XCTAssertEqual(appState.rules, [rule])
        XCTAssertEqual(appState.rule(for: key), rule)
    }

    func testSaveRulePersistsRules() {
        let store = InMemoryKeyRuleStore()
        let appState = AppState(ruleStore: store, loadsInstalledAppsOnInit: false)
        let key = KeyCatalog.defaultKeys[1]

        appState.saveRule(
            for: key,
            action: .openURL(name: "Docs", url: "https://example.com")
        )

        XCTAssertEqual(store.saveCallCount, 1)
        XCTAssertEqual(store.savedRules, appState.rules)
    }

    func testSaveRuleRecordsURLAndCommandHistory() {
        let store = InMemoryKeyRuleStore()
        let appState = AppState(ruleStore: store, loadsInstalledAppsOnInit: false)
        let webKey = KeyCatalog.defaultKeys[1]
        let commandKey = KeyCatalog.defaultKeys[2]

        appState.saveRule(
            for: webKey,
            action: .openURL(name: "Docs", url: "https://example.com")
        )
        appState.saveRule(
            for: commandKey,
            action: .runCommand(name: "List", command: "ls")
        )

        XCTAssertEqual(
            appState.actionHistory.webItems,
            [WebActionHistoryItem(name: "Docs", url: "https://example.com")]
        )
        XCTAssertEqual(
            appState.actionHistory.commandItems,
            [CommandActionHistoryItem(name: "List", command: "ls")]
        )
        XCTAssertEqual(store.savedHistory, appState.actionHistory)
    }

    func testInitializesActionHistoryFromPersistedRules() {
        let key = KeyCatalog.defaultKeys[1]
        let rule = Self.rule(for: key)
        let store = InMemoryKeyRuleStore(initialRules: [rule])

        let appState = AppState(ruleStore: store, loadsInstalledAppsOnInit: false)

        XCTAssertEqual(
            appState.actionHistory.webItems,
            [WebActionHistoryItem(name: "Docs", url: "https://example.com")]
        )
        XCTAssertEqual(store.savedHistory, appState.actionHistory)
    }

    func testDeleteRulePersistsRules() {
        let key = KeyCatalog.defaultKeys[1]
        let store = InMemoryKeyRuleStore(initialRules: [Self.rule(for: key)])
        let appState = AppState(ruleStore: store, loadsInstalledAppsOnInit: false)

        appState.deleteRule(for: key)

        XCTAssertEqual(store.saveCallCount, 1)
        XCTAssertEqual(store.savedRules, [])
    }

    private static let fixtureApp = InstalledApp(
        id: "com.example.fixture",
        name: "Fixture",
        bundleIdentifier: "com.example.fixture",
        url: URL(fileURLWithPath: "/Applications/Fixture.app")
    )

    private static func rule(for key: KeyboardKey) -> KeyRule {
        KeyRule(
            name: "\(LauncherKey.defaultKey.displayName) + \(key.label)",
            trigger: KeyTrigger(
                launcherKeyCode: LauncherKey.defaultKey.keyCode,
                launcherDisplayName: LauncherKey.defaultKey.displayName,
                keyCode: key.keyCode
            ),
            action: .openURL(name: "Docs", url: "https://example.com")
        )
    }

    private func makeAppState(
        ruleStore: KeyRuleStore = InMemoryKeyRuleStore(),
        appDiscovery: @escaping @Sendable () -> [InstalledApp] = { [] }
    ) -> AppState {
        AppState(
            ruleStore: ruleStore,
            appDiscovery: appDiscovery,
            loadsInstalledAppsOnInit: false
        )
    }
}

private final class InMemoryKeyRuleStore: KeyRuleStore {
    private let initialRules: [KeyRule]
    private let initialHistory: KeyActionHistory
    private(set) var savedRules: [KeyRule] = []
    private(set) var savedHistory = KeyActionHistory()
    private(set) var saveCallCount = 0
    private(set) var saveHistoryCallCount = 0

    init(
        initialRules: [KeyRule] = [],
        initialHistory: KeyActionHistory = KeyActionHistory()
    ) {
        self.initialRules = initialRules
        self.initialHistory = initialHistory
    }

    func loadRules() throws -> [KeyRule] {
        initialRules
    }

    func saveRules(_ rules: [KeyRule]) throws {
        saveCallCount += 1
        savedRules = rules
    }

    func loadActionHistory() throws -> KeyActionHistory {
        initialHistory
    }

    func saveActionHistory(_ history: KeyActionHistory) throws {
        saveHistoryCallCount += 1
        savedHistory = history
    }
}
