import AppKit
import SwiftUI

@MainActor
final class ScreenNavigationOverlayController {
    private let state = ScreenNavigationOverlayState()
    private var windows: [ScreenNavigationOverlayWindow] = []

    func show(targets: [ScreenNavigationHintTarget]) {
        close()
        state.targets = targets
        state.message = nil
        state.inputPrefix = ""
        showWindows()
    }

    func showMessage(_ message: String) {
        close()
        state.targets = []
        state.message = message
        state.inputPrefix = ""
        showWindows()
    }

    func updatePrefix(_ prefix: String) {
        state.inputPrefix = prefix
    }

    func close() {
        windows.forEach { $0.close() }
        windows = []
        state.targets = []
        state.message = nil
        state.inputPrefix = ""
    }

    private func showWindows() {
        let preparedWindows = NSScreen.screens.map { screen in
            let view = ScreenNavigationOverlayView(
                state: state,
                screenFrame: screen.frame
            )

            let controller = NSHostingController(rootView: view)
            controller.view.frame = NSRect(origin: .zero, size: screen.frame.size)
            controller.view.wantsLayer = true

            let window = ScreenNavigationOverlayWindow(
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
            window.alphaValue = 0
            window.animationBehavior = .none
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = true
            return window
        }

        guard !preparedWindows.isEmpty else {
            return
        }

        windows = preparedWindows
        windows.forEach { window in
            window.contentView?.layoutSubtreeIfNeeded()
            window.contentView?.displayIfNeeded()
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            windows.forEach { window in
                window.alphaValue = 1
                window.orderFrontRegardless()
            }
        }
    }
}

@MainActor
final class ScreenNavigationOverlayState: ObservableObject {
    @Published var targets: [ScreenNavigationHintTarget] = []
    @Published var inputPrefix = ""
    @Published var message: String?
}

final class ScreenNavigationOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
}
