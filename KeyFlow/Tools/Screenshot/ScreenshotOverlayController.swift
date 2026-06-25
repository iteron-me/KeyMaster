import AppKit
import SwiftUI

@MainActor
final class ScreenshotOverlayController {
    static let shared = ScreenshotOverlayController()

    private var windows: [ScreenshotOverlayWindow] = []

    func beginCapture() {
        guard ScreenshotService.requestScreenCaptureAccessIfNeeded() else {
            return
        }

        closeSelection()

        windows = NSScreen.screens.map { screen in
            let view = ScreenshotSelectionView(
                screenFrame: screen.frame,
                copy: { [weak self] rect in
                    self?.copySelection(rect)
                },
                cancel: { [weak self] in
                    self?.closeSelection()
                }
            )

            let controller = NSHostingController(rootView: view)
            controller.view.frame = NSRect(origin: .zero, size: screen.frame.size)

            let window = ScreenshotOverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.contentViewController = controller
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = false
            window.orderFrontRegardless()
            return window
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
    }

    private func copySelection(_ rect: CGRect) {
        closeSelection()

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(80))
                let image = try await ScreenshotService.capture(rect: rect)
                ScreenshotService.copyToPasteboard(image)
            } catch {
                assertionFailure("Failed to capture screenshot: \(error)")
            }
        }
    }

    private func closeSelection() {
        windows.forEach { $0.close() }
        windows = []
    }
}

final class ScreenshotOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
