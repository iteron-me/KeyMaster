import AppKit
import SwiftUI

struct KeyFlowPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var keyCaptureController = LauncherKeyCaptureController()

    var body: some View {
        LiquidGlassGroup(spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                ToolbarView(
                    isCapturing: keyCaptureController.isCapturing,
                    startCapture: {
                        keyCaptureController.start { launcherKey in
                            appState.setLauncherKey(launcherKey)
                        }
                    }
                )

                KeyboardLayoutView()
            }
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

private struct ToolbarView: View {
    @EnvironmentObject private var appState: AppState
    let isCapturing: Bool
    let startCapture: () -> Void

    var body: some View {
        LiquidGlassGroup(spacing: 8) {
            HStack(spacing: 8) {
                ToolbarButton(
                    title: isCapturing ? "Press key" : appState.launcherKey.displayName,
                    systemImage: isCapturing ? "record.circle" : "keyboard",
                    isProminent: false,
                    action: startCapture
                )

                PermissionControls()

                Spacer(minLength: 0)

                QuitButton()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .liquidGlassPanel(
            cornerRadius: LiquidGlassStyle.controlRadius,
            tint: .white.opacity(0.035),
            isElevated: false
        )
    }
}

private struct PermissionControls: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            if !appState.permissionStatus.isAccessibilityTrusted {
                ToolbarButton(
                    title: "Accessibility",
                    systemImage: "figure.wave",
                    isProminent: true
                ) {
                    appState.requestAccessibilityPermission()
                }
            }

            if !appState.permissionStatus.canListenToEvents {
                ToolbarButton(
                    title: "Input Monitor",
                    systemImage: "keyboard",
                    isProminent: true
                ) {
                    appState.requestInputMonitoringPermission()
                }
            }
        }
    }
}

private struct QuitButton: View {
    var body: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .foregroundStyle(.secondary)
        .help("Quit KeyFlow")
        .accessibilityLabel("Quit KeyFlow")
    }
}

private struct ToolbarButton: View {
    let title: String
    let systemImage: String
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 4)
                .frame(height: 32)
        }
        .controlSize(.regular)
        .buttonBorderShape(.capsule)
        .liquidGlassButtonStyle(isProminent: isProminent)
        .help(title)
        .accessibilityLabel(title)
    }
}

final class LauncherKeyCaptureController: ObservableObject {
    @Published var isCapturing = false
    private let monitor = KeyCaptureMonitor()

    func start(onCapture: @escaping (LauncherKey) -> Void) {
        isCapturing = true

        monitor.start { [weak self] launcherKey in
            onCapture(launcherKey)
            self?.isCapturing = false
            self?.monitor.stop()
        }
    }

    deinit {
        monitor.stop()
    }
}
