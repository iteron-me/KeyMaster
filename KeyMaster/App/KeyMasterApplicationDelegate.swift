import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class KeyMasterApplicationDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let appState = AppState()
    private let configurationArchiveService = ConfigurationArchiveService()
    private var statusItem: NSStatusItem?
    private var panelWindow: KeyMasterPanelWindow?
    private var hostingController: NSHostingController<AnyView>?
    private var outsideClickLocalMonitor: Any?
    private var outsideClickGlobalMonitor: Any?
    private var statusItemCancellables = Set<AnyCancellable>()

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
        updateStatusItemState()

        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func updateStatusItemState() {
        guard let button = statusItem?.button else {
            return
        }

        if let statusTitle = PomodoroTimer.shared.statusItemTitle {
            let image = NSImage(
                systemSymbolName: PomodoroTimer.shared.statusItemSystemImage,
                accessibilityDescription: PomodoroTimer.shared.statusItemAccessibilityDescription
            )
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.title = statusTitle
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            button.toolTip = PomodoroTimer.shared.statusItemAccessibilityDescription
            return
        }

        let imageName = appState.isEngineRunning ? "keyboard.badge.eye" : "keyboard"
        let image = NSImage(
            systemSymbolName: imageName,
            accessibilityDescription: "KeyMaster"
        )
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
        button.font = .systemFont(ofSize: NSFont.systemFontSize)
        button.toolTip = "KeyMaster"
    }

    private func observeStatusItemState() {
        appState.$isEngineRunning
            .sink { [weak self] _ in
                self?.updateStatusItemState()
            }
            .store(in: &statusItemCancellables)

        Publishers.CombineLatest3(
            PomodoroTimer.shared.$mode,
            PomodoroTimer.shared.$phase,
            PomodoroTimer.shared.$remainingSeconds
        )
        .sink { [weak self] _, _, _ in
            self?.updateStatusItemState()
        }
        .store(in: &statusItemCancellables)
    }

    @objc
    private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showConfigurationMenu()
            return
        }

        if panelWindow?.isVisible == true {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showConfigurationMenu() {
        guard let event = NSApp.currentEvent,
              let button = statusItem?.button
        else {
            return
        }

        closePanel()

        let menu = NSMenu()
        menu.autoenablesItems = false

        let importItem = NSMenuItem(
            title: "Import Configuration...",
            action: #selector(importConfiguration),
            keyEquivalent: ""
        )
        importItem.image = NSImage(
            systemSymbolName: "square.and.arrow.down",
            accessibilityDescription: "Import Configuration"
        )
        importItem.target = self
        importItem.isEnabled = true
        menu.addItem(importItem)

        let exportItem = NSMenuItem(
            title: "Export Configuration...",
            action: #selector(exportConfiguration),
            keyEquivalent: ""
        )
        exportItem.image = NSImage(
            systemSymbolName: "square.and.arrow.up",
            accessibilityDescription: "Export Configuration"
        )
        exportItem.target = self
        exportItem.isEnabled = true
        menu.addItem(exportItem)

        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    @objc
    private func exportConfiguration() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSSavePanel()
        panel.title = "Export KeyMaster Configuration"
        panel.message = "The exported file contains all shortcuts, URLs, commands, and action history."
        panel.nameFieldStringValue = ConfigurationArchiveService.defaultBaseFileName()
        panel.allowedContentTypes = [Self.configurationContentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try configurationArchiveService.write(
                appState.configurationSnapshot(),
                to: url
            )
            showInformationAlert(
                title: "Configuration Exported",
                message: "Your complete KeyMaster configuration was saved to \(url.lastPathComponent)."
            )
        } catch {
            showErrorAlert(title: "Export Failed", error: error)
        }
    }

    @objc
    private func importConfiguration() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Import KeyMaster Configuration"
        panel.message = "Choose a KeyMaster configuration file to replace the current configuration."
        panel.allowedContentTypes = Self.configurationImportContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let configuration = try configurationArchiveService.configuration(from: url)

            guard confirmConfigurationReplacement(configuration) else {
                return
            }

            try appState.replaceConfiguration(with: configuration)
            showInformationAlert(
                title: "Configuration Imported",
                message: "Imported \(configuration.rules.count) shortcut rules and \(historyItemCount(in: configuration)) history items."
            )
        } catch {
            showErrorAlert(title: "Import Failed", error: error)
        }
    }

    private func confirmConfigurationReplacement(_ configuration: KeyMasterConfiguration) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Replace Current Configuration?"
        alert.informativeText = "This will replace all current shortcut rules and action history with \(configuration.rules.count) rules and \(historyItemCount(in: configuration)) history items from the selected file."
        alert.addButton(withTitle: "Replace Configuration")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func historyItemCount(in configuration: KeyMasterConfiguration) -> Int {
        configuration.actionHistory.webItems.count
            + configuration.actionHistory.commandItems.count
    }

    private func showInformationAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showErrorAlert(title: String, error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
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

    private func makePanelWindow() -> KeyMasterPanelWindow {
        let content = KeyMasterPanelView()
            .environmentObject(appState)

        let controller = NSHostingController(rootView: AnyView(content))
        controller.view.frame = NSRect(origin: .zero, size: Self.panelSize)
        controller.view.autoresizingMask = [.width, .height]
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor

        let window = KeyMasterPanelWindow(
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
    private static let configurationContentType = UTType(
        exportedAs: "app.keymaster.mac.configuration",
        conformingTo: .json
    )
    private static let configurationImportContentTypes: [UTType] = {
        guard let filenameContentType = UTType(
            filenameExtension: ConfigurationArchiveService.fileExtension
        ) else {
            return [configurationContentType]
        }

        return [configurationContentType, filenameContentType]
    }()
}

private final class KeyMasterPanelWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
