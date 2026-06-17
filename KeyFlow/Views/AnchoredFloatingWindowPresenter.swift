import AppKit
import SwiftUI

struct AnchoredFloatingWindowConfiguration {
    var contentSize: NSSize
    var preferredEdge: NSRectEdge = .maxX
    var spacing: CGFloat = 8
    var closesOnOutsideClick = true
    var attachesToParentWindow = true
}

@MainActor
final class AnchoredFloatingWindowPresenter: NSObject, NSWindowDelegate {
    private var window: AnchoredFloatingWindow?
    private var hostingController: NSHostingController<AnyView>?
    private weak var sourceView: NSView?
    private weak var parentWindow: NSWindow?
    private var parentWindowCloseObserver: NSObjectProtocol?
    private var outsideClickMonitor: Any?
    private var closeHandler: (() -> Void)?
    private var isClosing = false

    func present<Content: View>(
        from sourceView: NSView,
        configuration: AnchoredFloatingWindowConfiguration,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        close(notifying: false)

        guard let parentWindow = sourceView.window else {
            return
        }

        self.sourceView = sourceView
        self.parentWindow = parentWindow
        closeHandler = onClose
        isClosing = false

        let controller = NSHostingController(rootView: AnyView(content()))
        controller.sizingOptions = [.preferredContentSize]
        controller.preferredContentSize = configuration.contentSize
        controller.view.frame = NSRect(origin: .zero, size: configuration.contentSize)
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor

        let window = AnchoredFloatingWindow(
            contentRect: NSRect(origin: .zero, size: configuration.contentSize),
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
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.collectionBehavior = [.transient, .ignoresCycle]
        window.setFrame(frame(for: sourceView, in: parentWindow, configuration: configuration), display: false)

        self.hostingController = controller
        self.window = window

        if configuration.attachesToParentWindow {
            parentWindow.addChildWindow(window, ordered: .above)
        }

        parentWindowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: parentWindow,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.close(notifying: true)
            }
        }

        if configuration.closesOnOutsideClick {
            outsideClickMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                Task { @MainActor [weak self] in
                    guard let self, event.window !== self.window else {
                        return
                    }

                    self.close(notifying: true)
                }

                return event
            }
        }

        window.makeKeyAndOrderFront(nil)
    }

    func close(notifying shouldNotify: Bool = true) {
        guard !isClosing else {
            return
        }

        isClosing = true

        let window = window
        let parentWindow = parentWindow
        let closeHandler = closeHandler

        removeObservers()

        self.window = nil
        self.hostingController = nil
        self.closeHandler = nil
        self.sourceView = nil
        self.parentWindow = nil

        if let window {
            parentWindow?.removeChildWindow(window)
            window.delegate = nil
            window.orderOut(nil)
            window.close()
        }

        if shouldNotify {
            closeHandler?()
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else {
            return
        }

        close(notifying: true)
    }

    private func frame(
        for sourceView: NSView,
        in parentWindow: NSWindow,
        configuration: AnchoredFloatingWindowConfiguration
    ) -> NSRect {
        let sourceRectInWindow = sourceView.convert(sourceView.bounds, to: nil)
        let sourceRectOnScreen = parentWindow.convertToScreen(sourceRectInWindow)
        let contentSize = configuration.contentSize
        let origin: NSPoint

        switch configuration.preferredEdge {
        case .minX:
            origin = NSPoint(
                x: sourceRectOnScreen.minX - contentSize.width - configuration.spacing,
                y: sourceRectOnScreen.midY - contentSize.height / 2
            )
        case .minY:
            origin = NSPoint(
                x: sourceRectOnScreen.midX - contentSize.width / 2,
                y: sourceRectOnScreen.minY - contentSize.height - configuration.spacing
            )
        case .maxY:
            origin = NSPoint(
                x: sourceRectOnScreen.midX - contentSize.width / 2,
                y: sourceRectOnScreen.maxY + configuration.spacing
            )
        default:
            origin = NSPoint(
                x: sourceRectOnScreen.maxX + configuration.spacing,
                y: sourceRectOnScreen.midY - contentSize.height / 2
            )
        }

        return NSRect(origin: origin, size: contentSize)
    }

    private func removeObservers() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }

        if let parentWindowCloseObserver {
            NotificationCenter.default.removeObserver(parentWindowCloseObserver)
            self.parentWindowCloseObserver = nil
        }
    }
}

private final class AnchoredFloatingWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
