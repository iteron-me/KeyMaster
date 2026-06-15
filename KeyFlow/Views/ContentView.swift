import SwiftUI

struct KeyFlowPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        LiquidGlassGroup(spacing: 14) {
            KeyboardLayoutView()
            .frame(width: KeyboardLayoutView.panelWidth, alignment: .center)
            .padding(12)
            .liquidGlassPanel(
                cornerRadius: LiquidGlassStyle.windowRadius,
                tint: .white.opacity(0.045),
                isElevated: true
            )
        }
        .frame(width: KeyboardLayoutView.panelWidth + 24, alignment: .center)
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
