import SwiftUI

@main
struct KeyFlowApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("KeyFlow", systemImage: appState.isEngineRunning ? "keyboard.badge.eye" : "keyboard") {
            KeyFlowPanelView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
