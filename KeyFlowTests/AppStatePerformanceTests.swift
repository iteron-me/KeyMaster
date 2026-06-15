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

        let appState = AppState(
            appDiscovery: {
                discoveryStarted.fulfill()
                _ = discoveryMayFinish.wait(timeout: .now() + 1)
                return [fixtureApp]
            },
            loadsInstalledAppsOnInit: false
        )

        appState.reloadInstalledApps()

        await fulfillment(of: [discoveryStarted], timeout: 1)
        XCTAssertTrue(appState.installedApps.isEmpty)

        discoveryMayFinish.signal()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(appState.installedApps, [fixtureApp])
    }

    func testOpeningKeyEditorDoesNotPublishGlobalAppStateChange() {
        let appState = AppState(loadsInstalledAppsOnInit: false)
        var publishCount = 0

        appState.objectWillChange
            .sink { publishCount += 1 }
            .store(in: &cancellables)

        appState.select(KeyCatalog.defaultKeys[0])

        XCTAssertEqual(publishCount, 0)
    }

    func testRuleLookupUsesLauncherKeyCodeNotDisplayName() {
        let appState = AppState(loadsInstalledAppsOnInit: false)
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
        let appState = AppState(loadsInstalledAppsOnInit: false)
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

    private static let fixtureApp = InstalledApp(
        id: "com.example.fixture",
        name: "Fixture",
        bundleIdentifier: "com.example.fixture",
        url: URL(fileURLWithPath: "/Applications/Fixture.app")
    )
}
