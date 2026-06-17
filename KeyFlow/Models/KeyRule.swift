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

struct KeyActionHistory: Codable, Equatable {
    var webItems: [WebActionHistoryItem] = []
    var commandItems: [CommandActionHistoryItem] = []

    mutating func record(_ action: KeyAction) -> Bool {
        let previous = self

        switch action {
        case .openApp:
            break
        case .openURL(let name, let url):
            let item = WebActionHistoryItem(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                url: url.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            upsert(item, in: &webItems)
        case .runCommand(let name, let command):
            let item = CommandActionHistoryItem(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                command: command.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            upsert(item, in: &commandItems)
        }

        return self != previous
    }

    mutating func delete(_ item: WebActionHistoryItem) -> Bool {
        delete(item, from: &webItems)
    }

    mutating func delete(_ item: CommandActionHistoryItem) -> Bool {
        delete(item, from: &commandItems)
    }

    private func upsert<Item: Equatable>(_ item: Item, in items: inout [Item]) {
        items.removeAll { $0 == item }
        items.insert(item, at: 0)

        if items.count > Self.maximumItemsPerKind {
            items.removeLast(items.count - Self.maximumItemsPerKind)
        }
    }

    private func delete<Item: Equatable>(_ item: Item, from items: inout [Item]) -> Bool {
        let previousCount = items.count
        items.removeAll { $0 == item }
        return items.count != previousCount
    }

    private static let maximumItemsPerKind = 30
}

struct WebActionHistoryItem: Identifiable, Codable, Equatable, Hashable {
    var name: String
    var url: String

    var id: String {
        "\(name)|\(url)"
    }
}

struct CommandActionHistoryItem: Identifiable, Codable, Equatable, Hashable {
    var name: String
    var command: String

    var id: String {
        "\(name)|\(command)"
    }
}

struct LauncherKey: Codable, Equatable, Hashable {
    var keyCode: Int
    var displayName: String

    static let defaultKey = LauncherKey(keyCode: 59, displayName: "Control")
}
