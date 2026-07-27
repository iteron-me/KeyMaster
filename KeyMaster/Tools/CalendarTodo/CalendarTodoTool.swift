import AppKit
import SwiftUI

struct CalendarTodoTool: KeyMasterTool {
    let id = "calendar.todo"
    let title = "Calendar Todo"
    let subtitle = "Plan tasks by day"
    let systemImage = "calendar"

    var defaultInvocation: ToolInvocation {
        ToolInvocation(toolID: id, displayName: title)
    }

    @MainActor
    func run(_ invocation: ToolInvocation) async throws {
        CalendarTodoWindowController.shared.show()
    }
}

@MainActor
final class CalendarTodoWindowController: NSObject, NSWindowDelegate {
    static let shared = CalendarTodoWindowController()

    private let store = CalendarTodoStore.shared
    private let viewState = CalendarTodoViewState()
    private var window: NSWindow?
    private var hostingController: NSHostingController<AnyView>?

    func show() {
        let window = window ?? makeWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else {
            return
        }
        window = nil
        hostingController = nil
    }

    private func makeWindow() -> NSWindow {
        let content = CalendarTodoView(store: store, state: viewState)
        let controller = NSHostingController(rootView: AnyView(content))
        controller.view.frame = NSRect(origin: .zero, size: Self.initialSize)
        controller.view.autoresizingMask = [.width, .height]

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Calendar Todo"
        window.minSize = Self.minimumSize
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = controller
        window.center()
        window.collectionBehavior = [.managed, .canJoinAllSpaces]

        hostingController = controller
        self.window = window
        return window
    }

    private static let initialSize = NSSize(width: 980, height: 720)
    private static let minimumSize = NSSize(width: 760, height: 560)
}
