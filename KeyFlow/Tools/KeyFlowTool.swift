import Foundation

protocol KeyFlowTool {
    var id: String { get }
    var title: String { get }
    var subtitle: String { get }
    var systemImage: String { get }
    var defaultInvocation: ToolInvocation { get }

    @MainActor
    func run(_ invocation: ToolInvocation) async throws
}

