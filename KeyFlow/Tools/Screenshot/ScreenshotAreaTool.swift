import Foundation

struct ScreenshotAreaTool: KeyFlowTool {
    let id = "screenshot.area"
    let title = "Screenshot Area"
    let subtitle = "Drag to capture a rectangle"
    let systemImage = "camera.viewfinder"

    var defaultInvocation: ToolInvocation {
        ToolInvocation(toolID: id, displayName: title)
    }

    @MainActor
    func run(_ invocation: ToolInvocation) async throws {
        ScreenshotOverlayController.shared.beginCapture()
    }
}

