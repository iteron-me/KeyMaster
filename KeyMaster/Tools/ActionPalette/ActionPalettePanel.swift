import AppKit
import SwiftUI
import WebKit

@MainActor
final class ActionPaletteController: NSObject, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    static let shared = ActionPaletteController()

    private var window: ActionPaletteWindow?
    private var hostingController: NSHostingController<AnyView>?
    private var state: ActionPaletteState?
    private var webView: WKWebView?
    private var sourceProcessID: pid_t?
    private var sourceScreen: NSScreen?
    private var localKeyMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var applicationActivationObserver: NSObjectProtocol?

    func toggle() {
        window?.isVisible == true ? close() : show()
    }

    func close() {
        removeMonitors()
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView = nil
        sourceProcessID = nil
        sourceScreen = nil

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
        guard let capture = ActionPaletteSelectionReader.capture() else {
            return
        }

        let state = ActionPaletteState(
            selectionText: capture.text,
            captureError: capture.errorMessage
        )
        let webView = makeWebView()
        let initialSize = ActionPaletteMetrics.chooserSize(hasError: capture.errorMessage != nil)
        let window = makeWindow(state: state, webView: webView, size: initialSize)
        let frame = ActionPaletteGeometry.chooserFrame(
            selectionFrame: capture.selectionFrame,
            visibleFrame: capture.screen.visibleFrame,
            size: initialSize
        )
        window.setFrame(frame, display: false)

        self.state = state
        self.webView = webView
        self.window = window
        sourceProcessID = capture.processID
        sourceScreen = capture.screen
        installMonitors()

        window.orderFrontRegardless()
        window.makeKey()
    }

    private func makeWebView() -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsMagnification = true
        return webView
    }

    private func makeWindow(
        state: ActionPaletteState,
        webView: WKWebView,
        size: CGSize
    ) -> ActionPaletteWindow {
        let view = ActionPaletteView(
            state: state,
            webView: webView,
            search: { [weak self] in self?.search() },
            goBack: { [weak self] in self?.webView?.goBack() },
            goForward: { [weak self] in self?.webView?.goForward() },
            reload: { [weak self] in self?.reload() },
            openInBrowser: { [weak self] in self?.openInBrowser() },
            close: { [weak self] in self?.close() }
        )
        let controller = NSHostingController(rootView: AnyView(view))
        controller.view.frame = NSRect(origin: .zero, size: size)
        controller.view.autoresizingMask = [.width, .height]
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor

        let window = ActionPaletteWindow(
            contentRect: NSRect(origin: .zero, size: size),
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

    private func search() {
        guard let state,
              let text = state.selectionText,
              let url = ActionPaletteSupport.googleSearchURL(for: text),
              let webView,
              let sourceScreen
        else {
            return
        }

        state.showPreview()
        let frame = ActionPaletteGeometry.previewFrame(
            visibleFrame: sourceScreen.visibleFrame,
            preferredSize: ActionPaletteMetrics.previewSize
        )
        window?.setFrame(frame, display: true, animate: true)
        webView.load(URLRequest(url: url))
    }

    private func reload() {
        guard let webView else {
            return
        }
        state?.clearWebError()
        if webView.url == nil {
            search()
        } else {
            webView.reload()
        }
    }

    private func openInBrowser() {
        guard let url = webView?.url,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else {
            return
        }
        NSWorkspace.shared.open(url)
        close()
    }

    private func installMonitors() {
        let paletteWindowNumber = window?.windowNumber
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.windowNumber == paletteWindowNumber,
                  let command = ActionPaletteKeyCommand(keyCode: event.keyCode)
            else {
                return event
            }

            guard self?.shouldHandle(command) == true else {
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
            let processID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication)?.processIdentifier
            Task { @MainActor [weak self] in
                guard let self,
                      let sourceProcessID = self.sourceProcessID,
                      let processID,
                      processID != sourceProcessID
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

    private func shouldHandle(_ command: ActionPaletteKeyCommand) -> Bool {
        state?.phase == .chooser || command == .close
    }

    private func handle(_ command: ActionPaletteKeyCommand) {
        switch command {
        case .execute:
            search()
        case .moveSelection:
            break
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

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        state?.startLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        state?.finishLoading(webView: webView)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation?,
        withError error: Error
    ) {
        state?.failLoading(webView: webView)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation?,
        withError error: Error
    ) {
        state?.failLoading(webView: webView)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let scheme = navigationAction.request.url?.scheme?.lowercased(),
              ["http", "https", "about"].contains(scheme)
        else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              let url = navigationAction.request.url,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else {
            return nil
        }
        webView.load(URLRequest(url: url))
        return nil
    }
}

enum ActionPaletteMetrics {
    static let chooserSize = CGSize(width: 188, height: 48)
    static let errorSize = CGSize(width: 300, height: 48)
    static let previewSize = CGSize(width: 760, height: 560)

    static func chooserSize(hasError: Bool) -> CGSize {
        hasError ? errorSize : chooserSize
    }
}

@MainActor
private final class ActionPaletteState: ObservableObject {
    enum Phase: Equatable {
        case chooser
        case preview
    }

    let selectionText: String?
    let captureError: String?
    @Published private(set) var phase: Phase = .chooser
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var webError: String?

    init(selectionText: String?, captureError: String?) {
        self.selectionText = selectionText
        self.captureError = captureError
    }

    func showPreview() {
        phase = .preview
        isLoading = true
        webError = nil
    }

    func startLoading() {
        isLoading = true
        webError = nil
    }

    func finishLoading(webView: WKWebView) {
        isLoading = false
        updateNavigation(webView: webView)
    }

    func failLoading(webView: WKWebView) {
        isLoading = false
        webError = "Page unavailable"
        updateNavigation(webView: webView)
    }

    func clearWebError() {
        webError = nil
    }

    private func updateNavigation(webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }
}

private struct ActionPaletteView: View {
    @ObservedObject var state: ActionPaletteState
    let webView: WKWebView
    let search: () -> Void
    let goBack: () -> Void
    let goForward: () -> Void
    let reload: () -> Void
    let openInBrowser: () -> Void
    let close: () -> Void

    var body: some View {
        Group {
            switch state.phase {
            case .chooser:
                chooser
            case .preview:
                preview
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(paletteShape)
        .overlay {
            paletteShape.strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var chooser: some View {
        if let error = state.captureError {
            HStack(spacing: 9) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                iconButton("xmark", help: "Close", action: close)
            }
            .padding(.horizontal, 10)
        } else {
            HStack(spacing: 6) {
                Button(action: search) {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityHint("Search Google for the selected text")

                iconButton("xmark", help: "Close", action: close)
            }
            .padding(5)
        }
    }

    private var preview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                iconButton("chevron.left", help: "Back", isDisabled: !state.canGoBack, action: goBack)
                iconButton("chevron.right", help: "Forward", isDisabled: !state.canGoForward, action: goForward)
                iconButton("arrow.clockwise", help: "Reload", action: reload)

                if state.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 6)
                }

                Spacer()
                iconButton("arrow.up.forward.app", help: "Open in Browser", action: openInBrowser)
                iconButton("xmark", help: "Close", action: close)
            }
            .padding(.horizontal, 8)
            .frame(height: 42)
            .background(.bar)

            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 1)

            ZStack {
                ActionPaletteWebView(webView: webView)

                if let error = state.webError {
                    VStack(spacing: 12) {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Button(action: reload) {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func iconButton(
        _ systemName: String,
        help: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? Color.secondary.opacity(0.42) : Color.primary)
        .disabled(isDisabled)
        .help(help)
        .accessibilityLabel(help)
    }

    private var paletteShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }
}

private struct ActionPaletteWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

private final class ActionPaletteWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
