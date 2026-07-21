import Foundation

struct ScreenNavigationTool: KeyMasterTool {
    let id = "screen.navigation"
    let title = "Screen Navigation"
    let subtitle = "Keyboard hints for visible UI elements"
    let systemImage = "keyboard.badge.eye"

    var defaultInvocation: ToolInvocation {
        ToolInvocation(toolID: id, displayName: title)
    }

    @MainActor
    func run(_ invocation: ToolInvocation) async throws {
        ScreenNavigationController.shared.beginNavigation()
    }
}
