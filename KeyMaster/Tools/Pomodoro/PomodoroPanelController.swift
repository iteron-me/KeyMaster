import AppKit
import SwiftUI

@MainActor
final class PomodoroPanelController: NSObject, NSWindowDelegate {
    static let shared = PomodoroPanelController()

    private var window: PomodoroPanelWindow?
    private var hostingController: NSHostingController<AnyView>?

    var isVisible: Bool {
        window?.isVisible == true
    }

    func toggle() {
        if window?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        let window = window ?? makeWindow()
        position(window)
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeMain()
        window.makeKey()
    }

    func close() {
        let window = window
        self.window = nil
        hostingController = nil
        window?.delegate = nil
        window?.orderOut(nil)
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else {
            return
        }

        close()
    }

    private func makeWindow() -> PomodoroPanelWindow {
        let content = PomodoroControlPanelView(
            timer: .shared,
            close: { [weak self] in
                self?.close()
            }
        )

        let controller = NSHostingController(rootView: AnyView(content))
        controller.view.frame = NSRect(origin: .zero, size: Self.contentSize)
        controller.view.autoresizingMask = [.width, .height]
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor

        let window = PomodoroPanelWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = controller
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.transient, .canJoinAllSpaces, .ignoresCycle]

        hostingController = controller
        self.window = window
        return window
    }

    private func position(_ window: NSWindow) {
        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(NSEvent.mouseLocation)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(origin: .zero, size: Self.contentSize)
        let origin = NSPoint(
            x: visibleFrame.maxX - Self.contentSize.width - Self.screenPadding,
            y: visibleFrame.maxY - Self.contentSize.height - Self.screenPadding
        )

        window.setFrame(NSRect(origin: origin, size: Self.contentSize), display: true)
    }

    private static let contentSize = NSSize(width: 236, height: 156)
    private static let screenPadding: CGFloat = 14
}

private final class PomodoroPanelWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
