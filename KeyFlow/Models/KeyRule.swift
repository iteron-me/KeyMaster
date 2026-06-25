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
    var modifiers: Set<ModifierKey>
    var keyCode: Int
    var keyDisplayName: String

    init(
        modifiers: Set<ModifierKey>,
        keyCode: Int,
        keyDisplayName: String
    ) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.keyDisplayName = keyDisplayName
    }

    var displayTitle: String {
        KeyStroke(
            modifiers: modifiers,
            keyCode: keyCode,
            keyDisplayName: keyDisplayName
        )
        .displayTitle
    }

    private enum CodingKeys: String, CodingKey {
        case modifiers
        case keyCode
        case keyDisplayName
        case launcherKeyCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(Int.self, forKey: .keyCode)
        keyDisplayName = try container.decodeIfPresent(String.self, forKey: .keyDisplayName)
            ?? KeyCatalog.displayName(forKeyCode: keyCode)

        if let modifiers = try container.decodeIfPresent([ModifierKey].self, forKey: .modifiers) {
            self.modifiers = Set(modifiers)
            return
        }

        let launcherKeyCode = try container.decode(Int.self, forKey: .launcherKeyCode)
        modifiers = ModifierKey.key(forLegacyKeyCode: launcherKeyCode).map { [$0] } ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modifiers.sortedForDisplay, forKey: .modifiers)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(keyDisplayName, forKey: .keyDisplayName)
    }
}

struct KeyStroke: Codable, Equatable, Hashable {
    var modifiers: Set<ModifierKey>
    var keyCode: Int
    var keyDisplayName: String

    init(
        modifiers: Set<ModifierKey>,
        keyCode: Int,
        keyDisplayName: String
    ) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.keyDisplayName = keyDisplayName
    }

    var displayTitle: String {
        let modifierSymbols = modifiers.displaySymbols

        if modifierSymbols.isEmpty {
            return keyDisplayName
        }

        return "\(modifierSymbols) \(keyDisplayName)"
    }

    private enum CodingKeys: String, CodingKey {
        case modifiers
        case keyCode
        case keyDisplayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modifiers = Set(try container.decodeIfPresent([ModifierKey].self, forKey: .modifiers) ?? [])
        keyCode = try container.decode(Int.self, forKey: .keyCode)
        keyDisplayName = try container.decodeIfPresent(String.self, forKey: .keyDisplayName)
            ?? KeyCatalog.displayName(forKeyCode: keyCode)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modifiers.sortedForDisplay, forKey: .modifiers)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(keyDisplayName, forKey: .keyDisplayName)
    }
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

    var shortSymbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .command: "⌘"
        case .shift: "⇧"
        }
    }

    fileprivate var displayOrder: Int {
        switch self {
        case .control: 0
        case .option: 1
        case .shift: 2
        case .command: 3
        }
    }

    static func key(forLegacyKeyCode keyCode: Int) -> ModifierKey? {
        switch keyCode {
        case 55, 54:
            .command
        case 59, 62:
            .control
        case 58, 61:
            .option
        case 56, 60:
            .shift
        default:
            nil
        }
    }
}

enum KeyAction: Codable, Equatable {
    case openApp(bundleIdentifier: String, displayName: String)
    case openURL(name: String, url: String)
    case runCommand(name: String, command: String)
    case runTool(ToolInvocation)
    case sendKeyStroke(KeyStroke)
    case lockScreen

    static let lockScreenDisplayTitle = "Lock Screen"
    static let lockScreenPresetSubtitle = "System lock screen"

    var displayTitle: String {
        switch self {
        case .openApp(_, let displayName):
            displayName
        case .openURL(let name, _):
            name
        case .runCommand(let name, _):
            name
        case .runTool(let invocation):
            invocation.displayName
        case .sendKeyStroke(let keyStroke):
            keyStroke.displayTitle
        case .lockScreen:
            Self.lockScreenDisplayTitle
        }
    }

    var kind: ActionKind {
        switch self {
        case .openApp:
            .app
        case .openURL:
            .url
        case .runCommand, .runTool:
            .command
        case .sendKeyStroke:
            .mapping
        case .lockScreen:
            .command
        }
    }

    var allowsRepeat: Bool {
        switch self {
        case .sendKeyStroke:
            true
        case .openApp, .openURL, .runCommand, .runTool, .lockScreen:
            false
        }
    }
}

enum ActionKind: String, CaseIterable, Codable, Identifiable {
    case app
    case url
    case command
    case mapping

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: "App"
        case .url: "Web"
        case .command: "Command"
        case .mapping: "Key Mapping"
        }
    }

    var systemImage: String {
        switch self {
        case .app: "macwindow"
        case .url: "globe"
        case .command: "terminal.fill"
        case .mapping: "keyboard"
        }
    }

    var tintName: String {
        switch self {
        case .app: "blue"
        case .url: "green"
        case .command: "orange"
        case .mapping: "purple"
        }
    }
}

struct KeyActionHistory: Codable, Equatable {
    var webItems: [WebActionHistoryItem] = []
    var commandItems: [CommandActionHistoryItem] = []

    mutating func record(_ action: KeyAction) -> Bool {
        let previous = self

        switch action {
        case .openApp, .runTool, .sendKeyStroke, .lockScreen:
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

    mutating func removeLegacyCommandPresets() -> Bool {
        let previousCount = commandItems.count
        commandItems.removeAll(where: \.isLegacyLockScreenPreset)
        return commandItems.count != previousCount
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

    var isLegacyLockScreenPreset: Bool {
        name == Self.lockScreenName && command == Self.legacyLockScreenCommand
    }

    static let lockScreenName = "Lock Screen"
    static let legacyLockScreenCommand = "'/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession' -suspend"
}

extension Set where Element == ModifierKey {
    var sortedForDisplay: [ModifierKey] {
        sorted { lhs, rhs in
            lhs.displayOrder < rhs.displayOrder
        }
    }

    var displayTitle: String {
        sortedForDisplay.map(\.displayName).joined(separator: " + ")
    }

    var displaySymbols: String {
        sortedForDisplay.map(\.shortSymbol).joined(separator: " ")
    }
}

struct LauncherKey: Codable, Equatable, Hashable {
    var keyCode: Int
    var displayName: String

    static let defaultKey = LauncherKey(keyCode: 59, displayName: "Control")
}
