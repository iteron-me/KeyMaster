import Foundation

struct ActionPaletteTool: KeyMasterTool {
    let id = "action.palette"
    let title = "Action Palette"
    let subtitle = "Actions for the current selection"
    let systemImage = "sparkles"

    var defaultInvocation: ToolInvocation {
        ToolInvocation(toolID: id, displayName: title)
    }

    @MainActor
    func run(_ invocation: ToolInvocation) async throws {
        ActionPaletteController.shared.toggle()
    }
}
