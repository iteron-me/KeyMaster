import SwiftUI

struct KeyFlowPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        KeyboardLayoutView()
            .frame(width: KeyboardLayoutView.panelWidth, alignment: .center)
            .padding(2)
        .containerBackground(.clear, for: .window)
        .onAppear {
            appState.refreshPermissions()
            appState.reloadInstalledApps()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState.refreshPermissions()
            }
        }
    }
}
