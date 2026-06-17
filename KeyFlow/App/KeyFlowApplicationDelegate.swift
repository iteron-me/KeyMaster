import AppKit
import Combine
import SwiftUI

@MainActor
final class KeyFlowApplicationDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let appState = AppState()
    private var statusItem: NSStatusItem?
    private var panelWindow: KeyFlowPanelWindow?
    private var hostingController: NSHostingController<AnyView>?
    private var outsideClickLocalMonitor: Any?
    private var outsideClickGlobalMonitor: Any?
    private var statusItemCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        observeStatusItemState()
        appState.refreshPermissions()
        appState.reloadInstalledApps()
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeOutsideClickMonitor()
    }

    func applicationDidResignActive(_ notification: Notification) {
        closePanel()
    }

    func windowWillClose(_ notification: Notification) {
        closePanel()
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem
        updateStatusItemImage()

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)
    }

    private func updateStatusItemImage() {
        let imageName = appState.isEngineRunning ? "keyboard.badge.eye" : "keyboard"
        statusItem?.button?.image = NSImage(
            systemSymbolName: imageName,
            accessibilityDescription: "KeyFlow"
        )
    }

    private func observeStatusItemState() {
        statusItemCancellable = appState.$isEngineRunning
            .sink { [weak self] _ in
                self?.updateStatusItemImage()
            }
    }

    @objc
    private func togglePanel() {
        if panelWindow?.isVisible == true {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        appState.refreshPermissions()
        appState.reloadInstalledApps()

        let window = panelWindow ?? makePanelWindow()
        position(window)

        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeMain()
        window.makeKey()

        installOutsideClickMonitor()
    }

    private func makePanelWindow() -> KeyFlowPanelWindow {
        let content = KeyFlowPanelView()
            .environmentObject(appState)

        let controller = NSHostingController(rootView: AnyView(content))
        controller.view.frame = NSRect(origin: .zero, size: Self.panelSize)
        controller.view.autoresizingMask = [.width, .height]
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor

        let window = KeyFlowPanelWindow(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = controller
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.collectionBehavior = [.transient, .ignoresCycle]

        hostingController = controller
        panelWindow = window
        return window
    }

    private func position(_ window: NSWindow) {
        guard let button = statusItem?.button,
              let buttonWindow = button.window
        else {
            window.center()
            return
        }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let visibleFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let size = window.frame.size
        var origin = NSPoint(
            x: screenRect.midX - size.width / 2,
            y: screenRect.minY - size.height - Self.panelSpacing
        )

        origin.x = min(max(origin.x, visibleFrame.minX + Self.screenPadding), visibleFrame.maxX - size.width - Self.screenPadding)

        if origin.y < visibleFrame.minY + Self.screenPadding {
            origin.y = screenRect.maxY + Self.panelSpacing
        }

        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()

        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.closePanelIfNeeded(for: event)
            }

            return event
        }

        outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.closePanelIfNeeded(for: event)
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickLocalMonitor {
            NSEvent.removeMonitor(outsideClickLocalMonitor)
            self.outsideClickLocalMonitor = nil
        }

        if let outsideClickGlobalMonitor {
            NSEvent.removeMonitor(outsideClickGlobalMonitor)
            self.outsideClickGlobalMonitor = nil
        }
    }

    private func closePanel() {
        guard panelWindow?.isVisible == true else {
            removeOutsideClickMonitor()
            return
        }

        removeOutsideClickMonitor()
        panelWindow?.childWindows?.forEach { childWindow in
            panelWindow?.removeChildWindow(childWindow)
            childWindow.close()
        }
        panelWindow?.orderOut(nil)
    }

    private func closePanelIfNeeded(for event: NSEvent) {
        guard panelWindow?.isVisible == true, !contains(event) else {
            return
        }

        closePanel()
    }

    private func contains(_ event: NSEvent) -> Bool {
        guard let panelWindow else {
            return false
        }

        if let eventWindow = event.window, eventWindow === panelWindow {
            return true
        }

        let eventPoint: NSPoint

        if let eventWindow = event.window {
            eventPoint = eventWindow.convertPoint(toScreen: event.locationInWindow)
        } else {
            eventPoint = NSEvent.mouseLocation
        }

        if panelWindow.frame.contains(eventPoint) {
            return true
        }

        if statusItemButtonContains(eventPoint) {
            return true
        }

        return panelWindow.childWindows?.contains { childWindow in
            childWindow.frame.contains(eventPoint)
        } ?? false
    }

    private func statusItemButtonContains(_ screenPoint: NSPoint) -> Bool {
        guard let button = statusItem?.button,
              let buttonWindow = button.window
        else {
            return false
        }

        let buttonRect = button.convert(button.bounds, to: nil)
        return buttonWindow.convertToScreen(buttonRect).contains(screenPoint)
    }

    private static let panelSize = NSSize(
        width: KeyboardLayoutView.panelWidth + 4,
        height: KeyboardLayoutView.panelHeight + 4
    )
    private static let panelSpacing: CGFloat = 8
    private static let screenPadding: CGFloat = 8
}

private final class KeyFlowPanelWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
