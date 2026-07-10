import Foundation
import XCTest
@testable import KeyMaster

@MainActor
final class AppStateConfigurationTests: XCTestCase {
    func testReplacementPublishesAndPersistsCompleteConfiguration() throws {
        let originalRule = makeRule(id: "00000000-0000-0000-0000-000000000001", keyCode: 0)
        let importedRule = makeRule(id: "00000000-0000-0000-0000-000000000002", keyCode: 1)
        let importedHistory = KeyActionHistory(
            webItems: [WebActionHistoryItem(name: "Docs", url: "https://example.com")],
            commandItems: [CommandActionHistoryItem(name: "List", command: "ls -la")]
        )
        let store = TestKeyRuleStore(
            rules: [originalRule],
            actionHistory: KeyActionHistory()
        )
        let appState = makeAppState(store: store)
        let importedConfiguration = KeyMasterConfiguration(
            rules: [importedRule],
            actionHistory: importedHistory
        )

        try appState.replaceConfiguration(with: importedConfiguration)

        XCTAssertEqual(appState.configurationSnapshot(), importedConfiguration)
        XCTAssertEqual(
            KeyMasterConfiguration(
                rules: store.rules,
                actionHistory: store.actionHistory
            ),
            importedConfiguration
        )
    }

    func testHistorySaveFailureRestoresPersistenceAndKeepsPublishedState() {
        let originalRule = makeRule(id: "00000000-0000-0000-0000-000000000001", keyCode: 0)
        let importedRule = makeRule(id: "00000000-0000-0000-0000-000000000002", keyCode: 1)
        let originalHistory = KeyActionHistory(
            webItems: [WebActionHistoryItem(name: "Original", url: "https://example.com/original")]
        )
        let importedHistory = KeyActionHistory(
            commandItems: [CommandActionHistoryItem(name: "Imported", command: "echo imported")]
        )
        let store = TestKeyRuleStore(
            rules: [originalRule],
            actionHistory: originalHistory
        )
        let appState = makeAppState(store: store)
        store.failNextHistorySave = true

        XCTAssertThrowsError(
            try appState.replaceConfiguration(
                with: KeyMasterConfiguration(
                    rules: [importedRule],
                    actionHistory: importedHistory
                )
            )
        )

        XCTAssertEqual(appState.rules, [originalRule])
        XCTAssertEqual(appState.actionHistory, originalHistory)
        XCTAssertEqual(store.rules, [originalRule])
        XCTAssertEqual(store.actionHistory, originalHistory)
    }

    private func makeAppState(store: TestKeyRuleStore) -> AppState {
        AppState(
            ruleStore: store,
            appDiscovery: { [] },
            loadsInstalledAppsOnInit: false
        )
    }

    private func makeRule(id: String, keyCode: Int) -> KeyRule {
        let trigger = KeyTrigger(
            modifiers: [.control],
            keyCode: keyCode,
            keyDisplayName: KeyCatalog.displayName(forKeyCode: keyCode)
        )

        return KeyRule(
            id: UUID(uuidString: id)!,
            name: trigger.displayTitle,
            trigger: trigger,
            action: .lockScreen
        )
    }
}

private final class TestKeyRuleStore: KeyRuleStore {
    var rules: [KeyRule]
    var actionHistory: KeyActionHistory
    var failNextHistorySave = false

    init(rules: [KeyRule], actionHistory: KeyActionHistory) {
        self.rules = rules
        self.actionHistory = actionHistory
    }

    func loadRules() throws -> [KeyRule] {
        rules
    }

    func saveRules(_ rules: [KeyRule]) throws {
        self.rules = rules
    }

    func loadActionHistory() throws -> KeyActionHistory {
        actionHistory
    }

    func saveActionHistory(_ history: KeyActionHistory) throws {
        actionHistory = history

        if failNextHistorySave {
            failNextHistorySave = false
            throw TestKeyRuleStoreError.saveFailed
        }
    }
}

private enum TestKeyRuleStoreError: Error {
    case saveFailed
}
