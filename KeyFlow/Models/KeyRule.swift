import Foundation

struct KeyRule: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var trigger: KeyTrigger
    var action: KeyAction
    var isEnabled = true
    var createdAt = Date()
    var updatedAt = Date()
}

struct KeyTrigger: Codable, Equatable, Hashable {
    var launcherKeyCode: Int
    var launcherDisplayName: String
    var keyCode: Int
}

enum ModifierKey: String, CaseIterable, Codable, Identifiable {
    case control
    case option
    case command
    case shift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .control: "Control"
        case .option: "Option"
        case .command: "Command"
        case .shift: "Shift"
        }
    }

    var symbol: String {
        switch self {
        case .control: "control"
        case .option: "option"
        case .command: "command"
        case .shift: "shift"
        }
    }
}

enum KeyAction: Codable, Equatable {
    case openApp(bundleIdentifier: String, displayName: String)
    case openURL(name: String, url: String)
    case runCommand(name: String, command: String)

    var displayTitle: String {
        switch self {
        case .openApp(_, let displayName):
            displayName
        case .openURL(let name, _):
            name
        case .runCommand(let name, _):
            name
        }
    }

    var kind: ActionKind {
        switch self {
        case .openApp:
            .app
        case .openURL:
            .url
        case .runCommand:
            .command
        }
    }
}

enum ActionKind: String, CaseIterable, Codable, Identifiable {
    case app
    case url
    case command

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: "App"
        case .url: "Web"
        case .command: "Command"
        }
    }

    var systemImage: String {
        switch self {
        case .app: "app.fill"
        case .url: "link"
        case .command: "terminal.fill"
        }
    }

    var tintName: String {
        switch self {
        case .app: "blue"
        case .url: "green"
        case .command: "orange"
        }
    }
}

struct LauncherKey: Codable, Equatable, Hashable {
    var keyCode: Int
    var displayName: String

    static let defaultKey = LauncherKey(keyCode: 59, displayName: "Control")
}
