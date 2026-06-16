import Foundation

protocol KeyRuleStore {
    func loadRules() throws -> [KeyRule]
    func saveRules(_ rules: [KeyRule]) throws
    func loadActionHistory() throws -> KeyActionHistory
    func saveActionHistory(_ history: KeyActionHistory) throws
}

extension KeyRuleStore {
    func loadActionHistory() throws -> KeyActionHistory {
        KeyActionHistory()
    }

    func saveActionHistory(_ history: KeyActionHistory) throws {}
}

struct FileKeyRuleStore: KeyRuleStore {
    private let fileURL: URL
    private let historyFileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileURL: URL = FileKeyRuleStore.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.historyFileURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("action-history.json")
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadRules() throws -> [KeyRule] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([KeyRule].self, from: data)
    }

    func saveRules(_ rules: [KeyRule]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(rules)
        try data.write(to: fileURL, options: [.atomic])
    }

    func loadActionHistory() throws -> KeyActionHistory {
        guard fileManager.fileExists(atPath: historyFileURL.path) else {
            return KeyActionHistory()
        }

        let data = try Data(contentsOf: historyFileURL)
        return try decoder.decode(KeyActionHistory.self, from: data)
    }

    func saveActionHistory(_ history: KeyActionHistory) throws {
        let directoryURL = historyFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(history)
        try data.write(to: historyFileURL, options: [.atomic])
    }

    private static func defaultFileURL() -> URL {
        let applicationSupportDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        return applicationSupportDirectory
            .appendingPathComponent("KeyFlow", isDirectory: true)
            .appendingPathComponent("rules.json")
    }
}
