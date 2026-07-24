import AppKit
import SwiftUI

@MainActor
final class KeyActionMenuPopoverPresenter {
    private weak var appState: AppState?
    private var key: KeyboardKey?
    private weak var sourceView: NSView?
    private var windowPresenter: AnchoredFloatingWindowPresenter?
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
        let presenter = AnchoredFloatingWindowPresenter()
        windowPresenter = presenter
        presenter.present(
            from: sourceView,
            configuration: AnchoredFloatingWindowConfiguration(contentSize: initialSize),
            onClose: { [weak self] in
                self?.dismiss(notifying: true)
            }
        ) { edge in
            AnyView(
                content(
                    for: key,
                    appState: appState,
                    placementEdge: edge
                )
            )
        }
    }

    func close() {
        dismiss(notifying: true)
    }

    private func content(
        for key: KeyboardKey,
        appState: AppState,
        placementEdge: NSRectEdge
    ) -> some View {
        KeyActionMenuContent(
            key: key,
            placementEdge: placementEdge,
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

        let presenter = windowPresenter
        let closeHandler = closeHandler
        self.windowPresenter = nil
        self.closeHandler = nil
        appState = nil
        key = nil
        sourceView = nil

        presenter?.close(notifying: false)

        if shouldNotify {
            closeHandler?()
        }
    }

    private static func contentSize() -> NSSize {
        NSSize(
            width: ActionMenuMetrics.contentWidth(hasSubmenu: true) + ActionMenuMetrics.contentPadding * 2,
            height: ActionMenuMetrics.maxHeight(toolCount: ToolRegistry.shared.tools.count)
                + ActionMenuMetrics.contentPadding * 2
        )
    }
}
