import Foundation

struct KeyMasterConfiguration: Equatable {
    var rules: [ConfigurationRule]
    var history: ConfigurationHistory

    init(rules: [KeyRule], actionHistory: KeyActionHistory) {
        self.rules = rules.map(ConfigurationRule.init)
        history = ConfigurationHistory(actionHistory)
    }

    fileprivate init(rules: [ConfigurationRule], history: ConfigurationHistory) {
        self.rules = rules
        self.history = history
    }

    var actionHistory: KeyActionHistory {
        history.actionHistory
    }

    func makeRules(importedAt: Date = Date()) -> [KeyRule] {
        rules.map { $0.makeRule(importedAt: importedAt) }
    }
}

struct ConfigurationRule: Codable, Equatable {
    var modifiers: Set<ModifierKey>
    var keyCode: Int
    var action: ConfigurationAction
    var isEnabled: Bool

    init(_ rule: KeyRule) {
        modifiers = rule.trigger.modifiers
        keyCode = rule.trigger.keyCode
        action = ConfigurationAction(rule.action)
        isEnabled = rule.isEnabled
    }

    func makeRule(importedAt: Date) -> KeyRule {
        let trigger = KeyTrigger(
            modifiers: modifiers,
            keyCode: keyCode,
            keyDisplayName: KeyCatalog.displayName(forKeyCode: keyCode)
        )

        return KeyRule(
            name: trigger.displayTitle,
            trigger: trigger,
            action: action.keyAction,
            isEnabled: isEnabled,
            createdAt: importedAt,
            updatedAt: importedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case modifiers
        case keyCode
        case action
        case enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modifiers = Set(try container.decode([ModifierKey].self, forKey: .modifiers))
        keyCode = try container.decode(Int.self, forKey: .keyCode)
        action = try container.decode(ConfigurationAction.self, forKey: .action)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modifiers.sortedForDisplay, forKey: .modifiers)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(action, forKey: .action)

        if !isEnabled {
            try container.encode(false, forKey: .enabled)
        }
    }
}

enum ConfigurationAction: Codable, Equatable {
    case app(bundleIdentifier: String, name: String)
    case web(name: String, url: String)
    case command(name: String, command: String)
    case tool(ToolInvocation)
    case keyStroke(modifiers: Set<ModifierKey>, keyCode: Int)
    case lockScreen

    init(_ action: KeyAction) {
        switch action {
        case .openApp(let bundleIdentifier, let displayName):
            self = .app(bundleIdentifier: bundleIdentifier, name: displayName)
        case .openURL(let name, let url):
            self = .web(name: name, url: url)
        case .runCommand(let name, let command):
            self = .command(name: name, command: command)
        case .runTool(let invocation):
            self = .tool(invocation)
        case .sendKeyStroke(let keyStroke):
            self = .keyStroke(
                modifiers: keyStroke.modifiers,
                keyCode: keyStroke.keyCode
            )
        case .lockScreen:
            self = .lockScreen
        }
    }

    var keyAction: KeyAction {
        switch self {
        case .app(let bundleIdentifier, let name):
            .openApp(bundleIdentifier: bundleIdentifier, displayName: name)
        case .web(let name, let url):
            .openURL(name: name, url: url)
        case .command(let name, let command):
            .runCommand(name: name, command: command)
        case .tool(let invocation):
            .runTool(invocation)
        case .keyStroke(let modifiers, let keyCode):
            .sendKeyStroke(
                KeyStroke(
                    modifiers: modifiers,
                    keyCode: keyCode,
                    keyDisplayName: KeyCatalog.displayName(forKeyCode: keyCode)
                )
            )
        case .lockScreen:
            .lockScreen
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case bundleIdentifier
        case name
        case url
        case command
        case tool
        case modifiers
        case keyCode
    }

    private enum ActionType: String, Codable {
        case app
        case web
        case command
        case tool
        case keyStroke
        case lockScreen
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        switch try container.decode(ActionType.self, forKey: .type) {
        case .app:
            self = .app(
                bundleIdentifier: try container.decode(String.self, forKey: .bundleIdentifier),
                name: try container.decode(String.self, forKey: .name)
            )
        case .web:
            self = .web(
                name: try container.decode(String.self, forKey: .name),
                url: try container.decode(String.self, forKey: .url)
            )
        case .command:
            self = .command(
                name: try container.decode(String.self, forKey: .name),
                command: try container.decode(String.self, forKey: .command)
            )
        case .tool:
            self = .tool(try container.decode(ToolInvocation.self, forKey: .tool))
        case .keyStroke:
            self = .keyStroke(
                modifiers: Set(try container.decode([ModifierKey].self, forKey: .modifiers)),
                keyCode: try container.decode(Int.self, forKey: .keyCode)
            )
        case .lockScreen:
            self = .lockScreen
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .app(let bundleIdentifier, let name):
            try container.encode(ActionType.app, forKey: .type)
            try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
            try container.encode(name, forKey: .name)
        case .web(let name, let url):
            try container.encode(ActionType.web, forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(url, forKey: .url)
        case .command(let name, let command):
            try container.encode(ActionType.command, forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(command, forKey: .command)
        case .tool(let invocation):
            try container.encode(ActionType.tool, forKey: .type)
            try container.encode(invocation, forKey: .tool)
        case .keyStroke(let modifiers, let keyCode):
            try container.encode(ActionType.keyStroke, forKey: .type)
            try container.encode(modifiers.sortedForDisplay, forKey: .modifiers)
            try container.encode(keyCode, forKey: .keyCode)
        case .lockScreen:
            try container.encode(ActionType.lockScreen, forKey: .type)
        }
    }
}

struct ConfigurationHistory: Codable, Equatable {
    var web: [WebActionHistoryItem]
    var commands: [CommandActionHistoryItem]

    init(_ history: KeyActionHistory) {
        web = history.webItems
        commands = history.commandItems
    }

    var actionHistory: KeyActionHistory {
        KeyActionHistory(webItems: web, commandItems: commands)
    }
}

enum ConfigurationArchiveError: LocalizedError, Equatable {
    case invalidFile
    case unsupportedVersion(Int)
    case duplicateShortcut(String)

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            "The selected file is not a valid KeyMaster configuration."
        case .unsupportedVersion(let version):
            "This configuration uses format version \(version). This version of KeyMaster supports version \(ConfigurationArchiveService.currentFormatVersion)."
        case .duplicateShortcut(let shortcut):
            "The configuration contains more than one rule for \(shortcut)."
        }
    }
}

struct ConfigurationArchiveService {
    static let currentFormatVersion = 1
    static let fileExtension = "config"

    static func defaultBaseFileName(
        at date: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd"
        return "KM-\(formatter.string(from: date))"
    }

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        decoder = JSONDecoder()
    }

    func data(for configuration: KeyMasterConfiguration) throws -> Data {
        try encoder.encode(
            ConfigurationArchive(
                version: Self.currentFormatVersion,
                rules: configuration.rules,
                history: configuration.history
            )
        )
    }

    func write(_ configuration: KeyMasterConfiguration, to url: URL) throws {
        let data = try data(for: configuration)
        try data.write(to: url, options: [.atomic])
    }

    func configuration(from url: URL) throws -> KeyMasterConfiguration {
        let data = try Data(contentsOf: url)
        return try configuration(from: data)
    }

    func configuration(from data: Data) throws -> KeyMasterConfiguration {
        let version: Int

        do {
            version = try decoder.decode(FormatVersionProbe.self, from: data).version
        } catch {
            throw ConfigurationArchiveError.invalidFile
        }

        guard version == Self.currentFormatVersion else {
            throw ConfigurationArchiveError.unsupportedVersion(version)
        }

        let archive: ConfigurationArchive

        do {
            archive = try decoder.decode(ConfigurationArchive.self, from: data)
        } catch {
            throw ConfigurationArchiveError.invalidFile
        }

        try validate(archive.rules)
        return KeyMasterConfiguration(rules: archive.rules, history: archive.history)
    }

    private func validate(_ rules: [ConfigurationRule]) throws {
        var shortcuts = Set<ConfigurationShortcut>()

        for rule in rules {
            let shortcut = ConfigurationShortcut(
                modifiers: rule.modifiers,
                keyCode: rule.keyCode
            )

            guard shortcuts.insert(shortcut).inserted else {
                let trigger = KeyTrigger(
                    modifiers: rule.modifiers,
                    keyCode: rule.keyCode,
                    keyDisplayName: KeyCatalog.displayName(forKeyCode: rule.keyCode)
                )
                throw ConfigurationArchiveError.duplicateShortcut(trigger.displayTitle)
            }
        }
    }
}

private struct ConfigurationArchive: Codable {
    let version: Int
    let rules: [ConfigurationRule]
    let history: ConfigurationHistory
}

private struct FormatVersionProbe: Decodable {
    let version: Int
}

private struct ConfigurationShortcut: Hashable {
    let modifiers: Set<ModifierKey>
    let keyCode: Int
}
