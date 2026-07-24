import XCTest
@testable import KeyMaster

final class ApplicationMenuSearchTests: XCTestCase {
    func testSearchRequiresEveryWhitespaceTokenAcrossTitleAndPath() {
        let command = ApplicationMenuCommand(
            title: "Logcat",
            path: ["View", "Tool Windows"],
            isEnabled: false,
            order: 0
        )

        XCTAssertEqual(ApplicationMenuSearch.results(for: "log", in: [command]), [command])
        XCTAssertEqual(ApplicationMenuSearch.results(for: "tool log", in: [command]), [command])
        XCTAssertEqual(ApplicationMenuSearch.results(for: "VIEW LOGCAT", in: [command]), [command])
        XCTAssertTrue(ApplicationMenuSearch.results(for: "translated", in: [command]).isEmpty)
        XCTAssertTrue(ApplicationMenuSearch.results(for: "logct", in: [command]).isEmpty)
    }

    func testSearchRanksTitleMatchesThenUsesMenuOrder() {
        let commands = [
            ApplicationMenuCommand(title: "Open", path: ["Log Tools"], order: 0),
            ApplicationMenuCommand(title: "Show Logcat", path: ["View"], order: 3),
            ApplicationMenuCommand(title: "Logbook", path: ["Window"], order: 2),
            ApplicationMenuCommand(title: "Log", path: ["Help"], order: 4),
            ApplicationMenuCommand(title: "Log Output", path: ["Window"], order: 1)
        ]

        XCTAssertEqual(
            ApplicationMenuSearch.results(for: "log", in: commands).map(\.title),
            ["Log", "Log Output", "Logbook", "Show Logcat", "Open"]
        )
    }

    func testSearchReturnsNothingForEmptyQueryAndSupportsAnExplicitLimit() {
        let commands = (0..<15).map {
            ApplicationMenuCommand(title: "Command \($0)", path: ["Menu"], order: $0)
        }

        XCTAssertTrue(ApplicationMenuSearch.results(for: "   ", in: commands).isEmpty)
        XCTAssertEqual(ApplicationMenuSearch.results(for: "command", in: commands).count, 15)
        XCTAssertEqual(
            ApplicationMenuSearch.results(for: "command", in: commands, limit: 10).count,
            10
        )
    }

    func testExecutableLeafFiltering() {
        XCTAssertTrue(
            ApplicationMenuSearch.isExecutableLeaf(
                role: "AXMenuItem",
                title: "Recent Project",
                hasSubmenu: false,
                supportsExecution: true
            )
        )
        XCTAssertFalse(
            ApplicationMenuSearch.isExecutableLeaf(
                role: "AXMenuItem",
                title: "Services",
                hasSubmenu: true,
                supportsExecution: true
            )
        )
        XCTAssertFalse(
            ApplicationMenuSearch.isExecutableLeaf(
                role: "AXMenuItem",
                title: "",
                hasSubmenu: false,
                supportsExecution: true
            )
        )
        XCTAssertFalse(
            ApplicationMenuSearch.isExecutableLeaf(
                role: "AXMenuItem",
                title: "Heading",
                hasSubmenu: false,
                supportsExecution: false
            )
        )
        XCTAssertFalse(
            ApplicationMenuSearch.isExecutableLeaf(
                role: "AXSeparator",
                title: "Separator",
                hasSubmenu: false,
                supportsExecution: true
            )
        )
    }

    func testMenuExecutionPrefersPickAndFallsBackToPress() {
        XCTAssertEqual(
            ApplicationMenuSearch.preferredExecutionAction(in: ["AXPress", "AXPick"]),
            "AXPick"
        )
        XCTAssertEqual(
            ApplicationMenuSearch.preferredExecutionAction(in: ["AXPress"]),
            "AXPress"
        )
        XCTAssertNil(ApplicationMenuSearch.preferredExecutionAction(in: ["AXCancel"]))
    }

    func testShortcutCharacterNormalizesAppKitPrivateArrowGlyphs() {
        XCTAssertEqual(ApplicationMenuSearch.shortcutCharacterLabel("\u{F700}"), "↑")
        XCTAssertEqual(ApplicationMenuSearch.shortcutCharacterLabel("\u{F704}"), "F1")
        XCTAssertEqual(ApplicationMenuSearch.shortcutCharacterLabel("a"), "A")
        XCTAssertNil(ApplicationMenuSearch.shortcutCharacterLabel("\u{E000}"))
    }

    func testSystemAppleMenuFilteringDoesNotExcludeApplicationMenu() {
        XCTAssertTrue(
            ApplicationMenuSearch.isSystemAppleMenu(
                role: "AXMenuBarItem",
                title: "Apple",
                identifier: nil
            )
        )
        XCTAssertFalse(
            ApplicationMenuSearch.isSystemAppleMenu(
                role: "AXMenuBarItem",
                title: "Android Studio",
                identifier: "handleAction:"
            )
        )
        XCTAssertFalse(
            ApplicationMenuSearch.isSystemAppleMenu(
                role: "AXMenuItem",
                title: "Apple",
                identifier: nil
            )
        )
    }

    func testCommandMenuGrowsToShowEveryBuiltInTool() {
        XCTAssertEqual(ActionMenuMetrics.commandSubmenuHeight(toolCount: 3), 286)
        XCTAssertEqual(ActionMenuMetrics.commandSubmenuHeight(toolCount: 4), 328)
        XCTAssertEqual(ActionMenuMetrics.commandSubmenuHeight(toolCount: 7), 454)
    }

    func testCommandPaletteOnlyExpandsAfterTyping() {
        XCTAssertEqual(
            ApplicationCommandPaletteMetrics.contentHeight(hasQuery: false, resultCount: 10),
            66
        )
        XCTAssertEqual(
            ApplicationCommandPaletteMetrics.contentHeight(hasQuery: true, resultCount: 0),
            125
        )
        XCTAssertEqual(
            ApplicationCommandPaletteMetrics.contentHeight(hasQuery: true, resultCount: 3),
            267
        )
        XCTAssertEqual(
            ApplicationCommandPaletteMetrics.contentHeight(hasQuery: true, resultCount: 20),
            587
        )
        XCTAssertEqual(ApplicationCommandPaletteMetrics.maxContentHeight, 587)

        let topEdge: CGFloat = 700
        let collapsedY = ApplicationCommandPaletteMetrics.originY(topEdge: topEdge, height: 66)
        let expandedY = ApplicationCommandPaletteMetrics.originY(topEdge: topEdge, height: 587)
        XCTAssertEqual(collapsedY + 66, topEdge)
        XCTAssertEqual(expandedY + 587, topEdge)
    }

    func testCommandPaletteKeyCommands() {
        XCTAssertEqual(ApplicationCommandPaletteKeyCommand(keyCode: 36), .execute)
        XCTAssertEqual(ApplicationCommandPaletteKeyCommand(keyCode: 76), .execute)
        XCTAssertEqual(ApplicationCommandPaletteKeyCommand(keyCode: 125), .moveSelection(1))
        XCTAssertEqual(ApplicationCommandPaletteKeyCommand(keyCode: 126), .moveSelection(-1))
        XCTAssertEqual(ApplicationCommandPaletteKeyCommand(keyCode: 53), .close)
        XCTAssertNil(ApplicationCommandPaletteKeyCommand(keyCode: 0))
    }
}
