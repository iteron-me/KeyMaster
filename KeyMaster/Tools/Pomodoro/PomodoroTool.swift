import Foundation

struct PomodoroTool: KeyMasterTool {
    let id = "pomodoro.timer"
    let title = "Pomodoro Timer"
    let subtitle = "Start or pause a focus timer"
    let systemImage = "timer"

    var defaultInvocation: ToolInvocation {
        ToolInvocation(toolID: id, displayName: title)
    }

    @MainActor
    func run(_ invocation: ToolInvocation) async throws {
        if PomodoroPanelController.shared.isVisible {
            PomodoroPanelController.shared.close()
            return
        }

        if !PomodoroTimer.shared.isActive {
            PomodoroTimer.shared.startFocus()
        }

        PomodoroPanelController.shared.show()
    }
}
