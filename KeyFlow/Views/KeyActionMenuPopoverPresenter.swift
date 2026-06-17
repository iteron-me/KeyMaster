import AppKit
import SwiftUI

@MainActor
final class KeyActionMenuPopoverPresenter: NSObject, NSPopoverDelegate {
    private weak var appState: AppState?
    private var key: KeyboardKey?
    private var popover: NSPopover?
    private var hostingController: NSHostingController<AnyView>?
    private weak var sourceView: NSView?
    private var closeHandler: (() -> Void)?
    private var isClosing = false

    func present(
        key: KeyboardKey,
        appState: AppState,
        from sourceView: NSView,
        close: @escaping () -> Void
    ) {
        dismiss(notifying: false)

        self.key = key
        self.appState = appState
        self.sourceView = sourceView
        closeHandler = close
        isClosing = false

        let initialSize = Self.contentSize()
        let controller = NSHostingController(rootView: AnyView(content(for: key, appState: appState)))
        controller.sizingOptions = [.preferredContentSize]
        controller.preferredContentSize = initialSize
        controller.view.frame = NSRect(origin: .zero, size: initialSize)
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = initialSize
        popover.contentViewController = controller
        popover.delegate = self

        self.hostingController = controller
        self.popover = popover

        popover.show(
            relativeTo: sourceView.bounds,
            of: sourceView,
            preferredEdge: .maxX
        )

        DispatchQueue.main.async {
            Self.clearPopoverChrome(around: controller.view)
        }
    }

    func close() {
        dismiss(notifying: true)
    }

    func popoverDidClose(_ notification: Notification) {
        guard notification.object as? NSPopover === popover else {
            return
        }

        dismiss(notifying: true)
    }

    private func content(for key: KeyboardKey, appState: AppState) -> some View {
        KeyActionMenuContent(
            key: key,
            close: { [weak self] in
                self?.close()
            }
        )
        .environmentObject(appState)
        .background(Color.clear)
    }

    private func dismiss(notifying shouldNotify: Bool) {
        guard !isClosing else {
            return
        }

        isClosing = true

        let popover = popover
        let closeHandler = closeHandler
        self.popover = nil
        self.hostingController = nil
        self.closeHandler = nil
        appState = nil
        key = nil
        sourceView = nil

        popover?.delegate = nil
        if popover?.isShown == true {
            popover?.close()
        }

        if shouldNotify {
            closeHandler?()
        }
    }

    private static func contentSize() -> NSSize {
        NSSize(
            width: ActionMenuMetrics.contentWidth(hasSubmenu: true) + ActionMenuMetrics.contentPadding * 2,
            height: ActionMenuMetrics.maxHeight + ActionMenuMetrics.contentPadding * 2
        )
    }

    private static func clearPopoverChrome(around contentView: NSView) {
        guard let window = contentView.window else {
            return
        }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false

        clearBackgrounds(in: window.contentView)
    }

    private static func clearBackgrounds(in view: NSView?) {
        guard let view else {
            return
        }

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.borderWidth = 0
        view.layer?.shadowOpacity = 0

        for subview in view.subviews {
            clearBackgrounds(in: subview)
        }
    }
}
