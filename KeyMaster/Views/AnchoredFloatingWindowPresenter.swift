import AppKit
import SwiftUI

struct AnchoredFloatingWindowConfiguration {
    var contentSize: NSSize
    var preferredEdge: NSRectEdge = .maxX
    var spacing: CGFloat = 8
    var closesOnOutsideClick = true
    var attachesToParentWindow = true
    var activatesApplication = true
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
        @ViewBuilder content: (NSRectEdge) -> Content
    ) {
        close(notifying: false)

        guard let parentWindow = sourceView.window else {
            return
        }

        self.sourceView = sourceView
        self.parentWindow = parentWindow
        closeHandler = onClose
        isClosing = false

        let placement = placement(for: sourceView, in: parentWindow, configuration: configuration)
        let controller = NSHostingController(rootView: AnyView(content(placement.edge)))
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
        window.acceptsMouseMovedEvents = true
        window.setFrame(placement.frame, display: false)

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
                    guard let self else {
                        return
                    }

                    if !self.contains(event) {
                        self.close(notifying: true)
                    }
                }

                return event
            }
        }

        if configuration.activatesApplication {
            NSApp.activate(ignoringOtherApps: true)
        }

        window.orderFrontRegardless()
        window.makeMain()
        window.makeKey()

        DispatchQueue.main.async { [weak window] in
            window?.makeMain()
            window?.makeKey()
        }
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

    private func placement(
        for sourceView: NSView,
        in parentWindow: NSWindow,
        configuration: AnchoredFloatingWindowConfiguration
    ) -> AnchoredFloatingWindowPlacement {
        let sourceRectInWindow = sourceView.convert(sourceView.bounds, to: nil)
        let sourceRectOnScreen = parentWindow.convertToScreen(sourceRectInWindow)
        let contentSize = configuration.contentSize
        let visibleFrame = parentWindow.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(origin: .zero, size: contentSize)
        let edge = resolvedEdge(
            preferredEdge: configuration.preferredEdge,
            sourceRect: sourceRectOnScreen,
            contentSize: contentSize,
            spacing: configuration.spacing,
            visibleFrame: visibleFrame
        )
        let origin = clampedOrigin(
            origin(
                for: edge,
                sourceRect: sourceRectOnScreen,
                contentSize: contentSize,
                spacing: configuration.spacing
            ),
            contentSize: contentSize,
            visibleFrame: visibleFrame
        )

        return AnchoredFloatingWindowPlacement(
            frame: NSRect(origin: origin, size: contentSize),
            edge: edge
        )
    }

    private func origin(
        for edge: NSRectEdge,
        sourceRect: NSRect,
        contentSize: NSSize,
        spacing: CGFloat
    ) -> NSPoint {
        switch edge {
        case .minX:
            NSPoint(
                x: sourceRect.minX - contentSize.width - spacing,
                y: sourceRect.midY - contentSize.height / 2
            )
        case .minY:
            NSPoint(
                x: sourceRect.midX - contentSize.width / 2,
                y: sourceRect.minY - contentSize.height - spacing
            )
        case .maxY:
            NSPoint(
                x: sourceRect.midX - contentSize.width / 2,
                y: sourceRect.maxY + spacing
            )
        default:
            NSPoint(
                x: sourceRect.maxX + spacing,
                y: sourceRect.midY - contentSize.height / 2
            )
        }
    }

    private func resolvedEdge(
        preferredEdge: NSRectEdge,
        sourceRect: NSRect,
        contentSize: NSSize,
        spacing: CGFloat,
        visibleFrame: NSRect
    ) -> NSRectEdge {
        switch preferredEdge {
        case .maxX:
            let rightFrame = NSRect(
                origin: origin(
                    for: .maxX,
                    sourceRect: sourceRect,
                    contentSize: contentSize,
                    spacing: spacing
                ),
                size: contentSize
            )

            guard rightFrame.maxX > visibleFrame.maxX else {
                return .maxX
            }

            let leftFrame = NSRect(
                origin: origin(
                    for: .minX,
                    sourceRect: sourceRect,
                    contentSize: contentSize,
                    spacing: spacing
                ),
                size: contentSize
            )

            if leftFrame.minX >= visibleFrame.minX {
                return .minX
            }

            return .maxX
        case .minX:
            let leftFrame = NSRect(
                origin: origin(
                    for: .minX,
                    sourceRect: sourceRect,
                    contentSize: contentSize,
                    spacing: spacing
                ),
                size: contentSize
            )

            guard leftFrame.minX < visibleFrame.minX else {
                return .minX
            }

            let rightFrame = NSRect(
                origin: origin(
                    for: .maxX,
                    sourceRect: sourceRect,
                    contentSize: contentSize,
                    spacing: spacing
                ),
                size: contentSize
            )

            if rightFrame.maxX <= visibleFrame.maxX {
                return .maxX
            }

            return .minX
        default:
            return preferredEdge
        }
    }

    private func clampedOrigin(
        _ origin: NSPoint,
        contentSize: NSSize,
        visibleFrame: NSRect
    ) -> NSPoint {
        let maxX = visibleFrame.maxX - contentSize.width
        let maxY = visibleFrame.maxY - contentSize.height

        return NSPoint(
            x: maxX >= visibleFrame.minX ? min(max(origin.x, visibleFrame.minX), maxX) : visibleFrame.minX,
            y: maxY >= visibleFrame.minY ? min(max(origin.y, visibleFrame.minY), maxY) : visibleFrame.minY
        )
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

    private func contains(_ event: NSEvent) -> Bool {
        guard let window else {
            return false
        }

        let eventPoint: NSPoint

        if let eventWindow = event.window {
            eventPoint = eventWindow.convertPoint(toScreen: event.locationInWindow)
        } else {
            eventPoint = NSEvent.mouseLocation
        }

        return window.frame.contains(eventPoint)
    }
}

private struct AnchoredFloatingWindowPlacement {
    var frame: NSRect
    var edge: NSRectEdge
}

private final class AnchoredFloatingWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
