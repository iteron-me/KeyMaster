import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class ApplicationCommandPaletteController: NSObject, NSWindowDelegate {
    static let shared = ApplicationCommandPaletteController()

    private var window: ApplicationCommandPaletteWindow?
    private var hostingController: NSHostingController<AnyView>?
    private var state: ApplicationCommandPaletteState?
    private var menuSession: ApplicationMenuSession?
    private var scanTask: Task<Void, Never>?
    private var executionTask: Task<Void, Never>?
    private var activationID: UUID?
    private var targetProcessID: pid_t?
    private var paletteTopEdge: CGFloat?
    private var localKeyMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var applicationActivationObserver: NSObjectProtocol?

    func toggle() {
        if window?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func close() {
        scanTask?.cancel()
        executionTask?.cancel()
        scanTask = nil
        executionTask = nil
        activationID = nil
        targetProcessID = nil
        paletteTopEdge = nil
        removeMonitors()

        let session = menuSession
        menuSession = nil
        Task {
            await session?.clear()
        }

        let window = window
        self.window = nil
        hostingController = nil
        state = nil
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

    private func show() {
        let target = captureTarget()
        let fallbackScreen = NSScreen.main ?? NSScreen.screens.first

        guard let target, let screen = target.screen ?? fallbackScreen else {
            return
        }

        let state = ApplicationCommandPaletteState(
            applicationName: target.applicationName,
            applicationIcon: target.applicationIcon
        )
        let window = makeWindow(state: state)
        position(window, on: screen)

        self.state = state
        self.window = window
        targetProcessID = target.processID
        installMonitors()

        window.orderFrontRegardless()
        window.makeKey()

        guard let processID = target.processID else {
            state.fail("No active app")
            return
        }

        guard PermissionService().currentStatus().isAccessibilityTrusted else {
            state.fail("Accessibility permission required")
            return
        }

        startScan(processID: processID)
    }

    private func startScan(processID: pid_t) {
        let activationID = UUID()
        let session = ApplicationMenuSession(processID: processID)
        self.activationID = activationID
        menuSession = session

        scanTask = Task { [weak self] in
            let commands = await session.scan()
            guard !Task.isCancelled, self?.activationID == activationID else {
                return
            }

            self?.state?.finish(commands: commands)
            self?.scanTask = nil
        }
    }

    private func execute(commandID: UUID) {
        guard executionTask == nil,
              let state,
              let command = state.command(withID: commandID),
              let session = menuSession,
              let activationID
        else {
            return
        }

        guard command.isEnabled else {
            state.fail("Command unavailable")
            return
        }

        window?.resignKey()
        if let targetProcessID,
           let targetApplication = NSRunningApplication(processIdentifier: targetProcessID) {
            targetApplication.activate(options: [.activateAllWindows])
        }
        executionTask = Task { [weak self] in
            await Task.yield()
            let succeeded = await session.perform(commandID: commandID)
            guard !Task.isCancelled, self?.activationID == activationID else {
                return
            }

            self?.executionTask = nil
            if succeeded {
                self?.close()
            } else {
                self?.state?.fail("Command unavailable")
                self?.window?.orderFrontRegardless()
                self?.window?.makeKey()
            }
        }
    }

    private func makeWindow(state: ApplicationCommandPaletteState) -> ApplicationCommandPaletteWindow {
        let view = ApplicationCommandPaletteView(
            state: state,
            close: { [weak self] in self?.close() },
            execute: { [weak self] commandID in self?.execute(commandID: commandID) },
            resize: { [weak self] height in self?.resizeWindow(to: height) }
        )
        let controller = NSHostingController(rootView: AnyView(view))
        controller.view.frame = NSRect(origin: .zero, size: Self.initialContentSize)
        controller.view.autoresizingMask = [.width, .height]
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor

        let window = ApplicationCommandPaletteWindow(
            contentRect: NSRect(origin: .zero, size: Self.initialContentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = controller
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.transient, .canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        hostingController = controller
        return window
    }

    private func position(_ window: NSWindow, on screen: NSScreen) {
        let visibleFrame = screen.visibleFrame
        let size = window.frame.size
        let preferredTop = visibleFrame.minY + visibleFrame.height * Self.verticalPositionRatio
        let top = min(
            max(
                preferredTop,
                visibleFrame.minY + ApplicationCommandPaletteMetrics.maxContentHeight + Self.screenPadding
            ),
            visibleFrame.maxY - Self.screenPadding
        )
        let origin = NSPoint(
            x: min(
                max(visibleFrame.midX - size.width / 2, visibleFrame.minX + Self.screenPadding),
                visibleFrame.maxX - size.width - Self.screenPadding
            ),
            y: top - size.height
        )
        window.setFrame(NSRect(origin: origin, size: size), display: false)
        paletteTopEdge = top
    }

    private func resizeWindow(to height: CGFloat) {
        guard let window,
              let paletteTopEdge,
              abs(window.frame.height - height) > 0.5
        else {
            return
        }

        var frame = window.frame
        frame.origin.y = ApplicationCommandPaletteMetrics.originY(
            topEdge: paletteTopEdge,
            height: height
        )
        frame.size.height = height
        window.setFrame(frame, display: true)
    }

    private func installMonitors() {
        let paletteWindowNumber = window?.windowNumber
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.windowNumber == paletteWindowNumber,
                  let command = ApplicationCommandPaletteKeyCommand(keyCode: event.keyCode)
            else {
                return event
            }

            Task { @MainActor [weak self] in
                self?.handle(command)
            }
            return nil
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, !self.contains(event) else {
                    return
                }
                self.close()
            }
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.close()
            }
        }

        applicationActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let activatedProcessID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication)?.processIdentifier
            Task { @MainActor [weak self] in
                guard let self,
                      let targetProcessID = self.targetProcessID,
                      let activatedProcessID,
                      activatedProcessID != targetProcessID
                else {
                    return
                }
                self.close()
            }
        }
    }

    private func removeMonitors() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let applicationActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(applicationActivationObserver)
            self.applicationActivationObserver = nil
        }
    }

    private func handle(_ command: ApplicationCommandPaletteKeyCommand) {
        switch command {
        case .execute:
            if let selectedID = state?.selectedID {
                execute(commandID: selectedID)
            }
        case .moveSelection(let offset):
            state?.moveSelection(by: offset)
        case .close:
            close()
        }
    }

    private func contains(_ event: NSEvent) -> Bool {
        guard let window else {
            return false
        }
        let point = event.window.map {
            $0.convertPoint(toScreen: event.locationInWindow)
        } ?? NSEvent.mouseLocation
        return window.frame.contains(point)
    }

    private func captureTarget() -> ApplicationCommandTarget? {
        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ownProcessID,
              !application.isTerminated
        else {
            return ApplicationCommandTarget(
                processID: nil,
                applicationName: "App Commands",
                applicationIcon: NSImage(
                    systemSymbolName: "command.square",
                    accessibilityDescription: "App Commands"
                ) ?? NSImage(),
                screen: NSScreen.main
            )
        }

        let processID = application.processIdentifier
        return ApplicationCommandTarget(
            processID: processID,
            applicationName: application.localizedName ?? "Application",
            applicationIcon: application.icon ?? NSImage(),
            screen: targetScreen(processID: processID)
        )
    }

    private func targetScreen(processID: pid_t) -> NSScreen? {
        let application = AXUIElementCreateApplication(processID)
        if let window = elementAttribute(application, kAXFocusedWindowAttribute),
           let frame = frame(of: window),
           let screen = screen(containing: frame) {
            return screen
        }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        if let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
            for window in windows {
                guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                      ownerPID == processID,
                      let layer = window[kCGWindowLayer as String] as? Int,
                      layer == 0,
                      let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                      let frame = rect(from: bounds),
                      let screen = screen(containing: frame)
                else {
                    continue
                }
                return screen
            }
        }

        return NSScreen.main
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        guard let screen = NSScreen.screens.max(by: { lhs, rhs in
            intersectionArea(frame, displayBounds(for: lhs))
                < intersectionArea(frame, displayBounds(for: rhs))
        }), intersectionArea(frame, displayBounds(for: screen)) > 0 else {
            return nil
        }
        return screen
    }

    private func displayBounds(for screen: NSScreen) -> CGRect {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return .null
        }
        return CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
    }

    private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private func rect(from bounds: [String: CGFloat]) -> CGRect? {
        guard let x = bounds["X"],
              let y = bounds["Y"],
              let width = bounds["Width"],
              let height = bounds["Height"]
        else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(element, kAXPositionAttribute),
              let size = sizeAttribute(element, kAXSizeAttribute)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func attributeValue(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as AnyObject?
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = attributeValue(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func pointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let value = attributeValue(element, attribute),
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    private func sizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let value = attributeValue(element, attribute),
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else {
            return nil
        }
        return size
    }

    private static let initialContentSize = NSSize(
        width: ApplicationCommandPaletteMetrics.width,
        height: ApplicationCommandPaletteMetrics.searchHeight
    )
    private static let screenPadding: CGFloat = 12
    private static let verticalPositionRatio: CGFloat = 0.68
}

enum ApplicationCommandPaletteMetrics {
    static let width: CGFloat = 640
    static let searchHeight: CGFloat = 66
    static let rowHeight: CGFloat = 64
    static let statusHeight: CGFloat = 58
    static let resultsPadding: CGFloat = 8
    static let dividerHeight: CGFloat = 1
    static let maxVisibleResults = 8
    static let maxContentHeight = searchHeight
        + dividerHeight
        + CGFloat(maxVisibleResults) * rowHeight
        + resultsPadding

    static func contentHeight(hasQuery: Bool, resultCount: Int) -> CGFloat {
        guard hasQuery else {
            return searchHeight
        }
        let resultsHeight = resultCount > 0
            ? CGFloat(min(resultCount, maxVisibleResults)) * rowHeight + resultsPadding
            : statusHeight
        return searchHeight + dividerHeight + resultsHeight
    }

    static func originY(topEdge: CGFloat, height: CGFloat) -> CGFloat {
        topEdge - height
    }
}

enum ApplicationCommandPaletteKeyCommand: Equatable {
    case execute
    case moveSelection(Int)
    case close

    init?(keyCode: UInt16) {
        switch keyCode {
        case 36, 76:
            self = .execute
        case 125:
            self = .moveSelection(1)
        case 126:
            self = .moveSelection(-1)
        case 53:
            self = .close
        default:
            return nil
        }
    }
}

@MainActor
private final class ApplicationCommandPaletteState: ObservableObject {
    enum Phase: Equatable {
        case scanning
        case ready
        case failed(String)
    }

    let applicationName: String
    let applicationIcon: NSImage
    @Published var query = "" {
        didSet {
            if case .failed = phase, !commands.isEmpty {
                phase = .ready
            }
            refreshResults()
        }
    }
    @Published private(set) var results: [ApplicationMenuCommand] = []
    @Published private(set) var selectedID: UUID?
    @Published private(set) var phase: Phase = .scanning
    private var commands: [ApplicationMenuCommand] = []

    init(applicationName: String, applicationIcon: NSImage) {
        self.applicationName = applicationName
        self.applicationIcon = applicationIcon
    }

    func finish(commands: [ApplicationMenuCommand]) {
        self.commands = commands
        phase = commands.isEmpty ? .failed("No menu commands found") : .ready
        refreshResults()
    }

    func fail(_ message: String) {
        phase = .failed(message)
    }

    func command(withID id: UUID) -> ApplicationMenuCommand? {
        results.first { $0.id == id }
    }

    func select(_ id: UUID) {
        selectedID = id
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else {
            selectedID = nil
            return
        }

        let currentIndex = selectedID.flatMap { id in results.firstIndex { $0.id == id } } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), results.count - 1)
        selectedID = results[nextIndex].id
    }

    private func refreshResults() {
        results = ApplicationMenuSearch.results(for: query, in: commands)
        if !results.contains(where: { $0.id == selectedID }) {
            selectedID = results.first?.id
        }
    }
}

private struct ApplicationCommandPaletteView: View {
    @ObservedObject var state: ApplicationCommandPaletteState
    let close: () -> Void
    let execute: (UUID) -> Void
    let resize: (CGFloat) -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            if hasQuery {
                Divider()
                    .padding(.horizontal, 18)
                    .opacity(0.2)
                resultArea
            }
        }
        .frame(width: ApplicationCommandPaletteMetrics.width, height: contentHeight, alignment: .top)
        .background {
            paletteShape
                .fill(.ultraThinMaterial)
                .overlay {
                    paletteShape.fill(Color.white.opacity(0.52))
                }
        }
        .overlay {
            paletteShape.strokeBorder(Color.white.opacity(0.68), lineWidth: 1)
        }
        .clipShape(paletteShape)
        .onAppear {
            resize(contentHeight)
            DispatchQueue.main.async {
                searchFocused = true
            }
        }
        .onChange(of: contentHeight) { _, height in
            DispatchQueue.main.async {
                resize(height)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search menu commands", text: $state.query)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($searchFocused)

            trailingStatus
        }
        .padding(.horizontal, 18)
        .frame(height: ApplicationCommandPaletteMetrics.searchHeight)
    }

    private var resultArea: some View {
        Group {
            if state.results.isEmpty {
                HStack(spacing: 8) {
                    if case .scanning = state.phase {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(statusMessage ?? "No matching commands")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            Spacer(minLength: 4)
                            ForEach(state.results) { command in
                                commandRow(command)
                                    .id(command.id)
                            }
                            Spacer(minLength: 4)
                        }
                    }
                    .onChange(of: state.selectedID) { _, selectedID in
                        guard let selectedID else {
                            return
                        }
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(selectedID, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: resultAreaHeight)
    }

    private func commandRow(_ command: ApplicationMenuCommand) -> some View {
        let isSelected = command.id == state.selectedID
        let selectionShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return Button {
            state.select(command.id)
            execute(command.id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(command.pathLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let shortcut = command.shortcut {
                    Text(shortcut)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.72))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .frame(minHeight: 28)
                        .background {
                            Capsule()
                                .fill(Color.primary.opacity(isSelected ? 0.08 : 0.055))
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
                        }
                }
            }
            .padding(.horizontal, 14)
            .frame(
                maxWidth: .infinity,
                minHeight: ApplicationCommandPaletteMetrics.rowHeight - 6,
                maxHeight: ApplicationCommandPaletteMetrics.rowHeight - 6
            )
            .background {
                if isSelected {
                    selectionShape.fill(Color.primary.opacity(0.11))
                }
            }
            .contentShape(selectionShape)
            .padding(.horizontal, 8)
            .frame(height: ApplicationCommandPaletteMetrics.rowHeight)
            .opacity(command.isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(command.title)
        .accessibilityValue(command.isEnabled ? command.pathLabel : "Unavailable")
    }

    private var statusMessage: String? {
        switch state.phase {
        case .scanning:
            "Reading menus..."
        case .failed(let message):
            message
        case .ready:
            !state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && state.results.isEmpty ? "No matching commands" : nil
        }
    }

    @ViewBuilder
    private var trailingStatus: some View {
        if case .scanning = state.phase {
            ProgressView()
                .controlSize(.small)
        }

        if case .failed(let message) = state.phase {
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.red)
                .lineLimit(1)
        } else {
            Image(nsImage: state.applicationIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)

            Text(state.applicationName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var hasQuery: Bool {
        !state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var resultAreaHeight: CGFloat {
        contentHeight
            - ApplicationCommandPaletteMetrics.searchHeight
            - ApplicationCommandPaletteMetrics.dividerHeight
    }

    private var contentHeight: CGFloat {
        ApplicationCommandPaletteMetrics.contentHeight(
            hasQuery: hasQuery,
            resultCount: state.results.count
        )
    }

    private var paletteShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: ApplicationCommandPaletteMetrics.searchHeight / 2,
            style: .continuous
        )
    }
}

private struct ApplicationCommandTarget {
    let processID: pid_t?
    let applicationName: String
    let applicationIcon: NSImage
    let screen: NSScreen?
}

private final class ApplicationCommandPaletteWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
