import SwiftUI

struct KeyMasterPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        KeyboardLayoutView()
            .padding(2)
            .frame(
                width: KeyboardLayoutView.panelWidth + 4,
                height: KeyboardLayoutView.panelHeight + 4
            )
            .contentShape(Rectangle())
            .liquidGlassPanel(
                cornerRadius: LiquidGlassStyle.windowRadius,
                tint: .black.opacity(0.06),
                usesMaterial: true,
                showsShadow: false
            )
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
