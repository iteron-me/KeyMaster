import Foundation
import XCTest
@testable import KeyMaster

final class ConfigurationArchiveServiceTests: XCTestCase {
    private let service = ConfigurationArchiveService()

    func testDefaultFileNameIsShortTimestampWithoutExtension() {
        let name = ConfigurationArchiveService.defaultBaseFileName(
            at: Date(timeIntervalSince1970: 1_700_000_000),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(name, "KM-20231114")
        XCTAssertFalse(name.contains(ConfigurationArchiveService.fileExtension))
    }

    func testRoundTripPreservesCompleteConfiguration() throws {
        let configuration = KeyMasterConfiguration(
            rules: [
                makeRule(
                    id: "00000000-0000-0000-0000-000000000001",
                    keyCode: 0,
                    action: .openApp(
                        bundleIdentifier: "com.apple.Safari",
                        displayName: "Safari"
                    )
                ),
                makeRule(
                    id: "00000000-0000-0000-0000-000000000002",
                    keyCode: 1,
                    action: .openURL(name: "Docs", url: "https://example.com/docs")
                ),
                makeRule(
                    id: "00000000-0000-0000-0000-000000000003",
                    keyCode: 2,
                    action: .runCommand(name: "List", command: "ls -la")
                ),
                makeRule(
                    id: "00000000-0000-0000-0000-000000000004",
                    keyCode: 3,
                    action: .runTool(
                        ToolInvocation(
                            toolID: "test.tool",
                            displayName: "Test Tool",
                            configuration: ToolConfigurationPayload(
                                values: ["enabled": .bool(true)]
                            )
                        )
                    )
                ),
                makeRule(
                    id: "00000000-0000-0000-0000-000000000005",
                    keyCode: 4,
                    action: .sendKeyStroke(
                        KeyStroke(
                            modifiers: [.command, .shift],
                            keyCode: 8,
                            keyDisplayName: "C"
                        )
                    )
                ),
                makeRule(
                    id: "00000000-0000-0000-0000-000000000006",
                    keyCode: 5,
                    action: .lockScreen,
                    isEnabled: false
                )
            ],
            actionHistory: KeyActionHistory(
                webItems: [
                    WebActionHistoryItem(name: "Docs", url: "https://example.com/docs")
                ],
                commandItems: [
                    CommandActionHistoryItem(name: "List", command: "ls -la")
                ]
            )
        )

        let data = try service.data(for: configuration)
        let decoded = try service.configuration(from: data)

        XCTAssertEqual(decoded, configuration)
    }

    func testArchiveContainsOnlyPortableRuleFields() throws {
        let configuration = KeyMasterConfiguration(
            rules: [
                makeRule(
                    id: "00000000-0000-0000-0000-000000000001",
                    keyCode: 0,
                    action: .openApp(
                        bundleIdentifier: "com.apple.Safari",
                        displayName: "Safari"
                    )
                )
            ],
            actionHistory: KeyActionHistory()
        )

        let data = try service.data(for: configuration)
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let rules = try XCTUnwrap(root["rules"] as? [[String: Any]])
        let rule = try XCTUnwrap(rules.first)
        let history = try XCTUnwrap(root["history"] as? [String: Any])

        XCTAssertEqual(Set(root.keys), ["version", "rules", "history"])
        XCTAssertEqual(Set(rule.keys), ["modifiers", "keyCode", "action"])
        XCTAssertEqual(Set(history.keys), ["web", "commands"])
        XCTAssertNil(rule["enabled"])

        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("createdAt"))
        XCTAssertFalse(json.contains("updatedAt"))
        XCTAssertFalse(json.contains("exportedAt"))
        XCTAssertFalse(json.contains("keyDisplayName"))
        XCTAssertFalse(json.contains("\"id\""))
    }

    func testMalformedJSONIsRejected() {
        let data = Data("{not-json".utf8)

        XCTAssertThrowsError(try service.configuration(from: data)) { error in
            XCTAssertEqual(error as? ConfigurationArchiveError, .invalidFile)
        }
    }

    func testUnsupportedVersionIsRejected() throws {
        let data = Data(
            #"{"version":2,"rules":[],"history":{"web":[],"commands":[]}}"#.utf8
        )

        XCTAssertThrowsError(try service.configuration(from: data)) { error in
            XCTAssertEqual(error as? ConfigurationArchiveError, .unsupportedVersion(2))
        }
    }

    func testDuplicateShortcutTriggersAreRejected() throws {
        let firstRule = makeRule(
            id: "00000000-0000-0000-0000-000000000001",
            keyCode: 0,
            action: .lockScreen
        )
        let secondRule = makeRule(
            id: "00000000-0000-0000-0000-000000000002",
            keyCode: 0,
            action: .openURL(name: "Example", url: "https://example.com")
        )
        let data = try service.data(
            for: KeyMasterConfiguration(
                rules: [firstRule, secondRule],
                actionHistory: KeyActionHistory()
            )
        )

        XCTAssertThrowsError(try service.configuration(from: data)) { error in
            guard case .duplicateShortcut = error as? ConfigurationArchiveError else {
                return XCTFail("Expected duplicate shortcut error, got \(error)")
            }
        }
    }

    private func makeRule(
        id: String,
        keyCode: Int,
        action: KeyAction,
        isEnabled: Bool = true
    ) -> KeyRule {
        KeyRule(
            id: UUID(uuidString: id)!,
            name: "Control + \(KeyCatalog.displayName(forKeyCode: keyCode))",
            trigger: KeyTrigger(
                modifiers: [.control],
                keyCode: keyCode,
                keyDisplayName: KeyCatalog.displayName(forKeyCode: keyCode)
            ),
            action: action,
            isEnabled: isEnabled,
            createdAt: Date(timeIntervalSince1970: 1_600_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_650_000_000)
        )
    }
}
