import AppKit
import CoreGraphics

final class KeyCaptureMonitor {
    private var monitor: Any?

    func start(onCapture: @escaping (LauncherKey) -> Void) {
        stop()

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                if let key = Self.launcherKey(fromModifierEvent: event) {
                    onCapture(key)
                    return nil
                }
                return event
            }

            onCapture(
                LauncherKey(
                    keyCode: Int(event.keyCode),
                    displayName: Self.displayName(for: event)
                )
            )
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }

        monitor = nil
    }

    private static func launcherKey(fromModifierEvent event: NSEvent) -> LauncherKey? {
        switch event.keyCode {
        case 55, 54:
            LauncherKey(keyCode: Int(event.keyCode), displayName: "Command")
        case 59, 62:
            LauncherKey(keyCode: Int(event.keyCode), displayName: "Control")
        case 58, 61:
            LauncherKey(keyCode: Int(event.keyCode), displayName: "Option")
        case 56, 60:
            LauncherKey(keyCode: Int(event.keyCode), displayName: "Shift")
        case 57:
            LauncherKey(keyCode: Int(event.keyCode), displayName: "Caps Lock")
        default:
            nil
        }
    }

    private static func displayName(for event: NSEvent) -> String {
        if let key = KeyCatalog.defaultKeys.first(where: { $0.keyCode == Int(event.keyCode) }) {
            return key.label
        }

        if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
            return characters.uppercased()
        }

        return "Key \(event.keyCode)"
    }
}
