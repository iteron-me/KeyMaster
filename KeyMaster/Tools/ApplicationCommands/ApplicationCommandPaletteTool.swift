import Foundation

struct ApplicationCommandPaletteTool: KeyMasterTool {
    let id = "app.commands"
    let title = "App Commands"
    let subtitle = "Search the current app's menu commands"
    let systemImage = "command.square"

    var defaultInvocation: ToolInvocation {
        ToolInvocation(toolID: id, displayName: title)
    }

    @MainActor
    func run(_ invocation: ToolInvocation) async throws {
        ApplicationCommandPaletteController.shared.toggle()
    }
}
