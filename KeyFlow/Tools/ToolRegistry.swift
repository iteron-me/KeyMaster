import Foundation

@MainActor
final class ToolRegistry {
    static let shared = ToolRegistry()

    let tools: [any KeyFlowTool]
    private let toolsByID: [String: any KeyFlowTool]

    init(tools: [any KeyFlowTool] = [ScreenshotAreaTool(), PomodoroTool()]) {
        self.tools = tools
        toolsByID = Dictionary(uniqueKeysWithValues: tools.map { ($0.id, $0) })
    }

    func tool(for id: String) -> (any KeyFlowTool)? {
        toolsByID[id]
    }

    func run(_ invocation: ToolInvocation) async throws {
        guard let tool = tool(for: invocation.toolID) else {
            throw ToolRegistryError.toolNotFound(invocation.toolID)
        }

        try await tool.run(invocation)
    }
}

enum ToolRegistryError: LocalizedError {
    case toolNotFound(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let id):
            "Tool not found: \(id)"
        }
    }
}
