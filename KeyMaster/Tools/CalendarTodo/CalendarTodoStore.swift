import Foundation

@MainActor
final class CalendarTodoStore: ObservableObject {
    static let shared = CalendarTodoStore()
    static let currentFormatVersion = 1

    @Published private(set) var todos: [CalendarTodo] = []
    @Published private(set) var errorMessage: String?

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var canMutate = true

    init(
        fileURL: URL = CalendarTodoStore.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(dateStyle))
        }
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            return try dateStyle.parse(value)
        }
        self.decoder = decoder

        load()
    }

    func todos(on day: CalendarTodoDay) -> [CalendarTodo] {
        todos.filter { $0.day == day }
    }

    func count(on day: CalendarTodoDay) -> Int {
        todos.lazy.filter { $0.day == day }.count
    }

    @discardableResult
    func add(title: String, notes: String = "", on day: CalendarTodoDay) -> Bool {
        guard canMutate else {
            fail(CalendarTodoStoreError.liveStoreUnavailable)
            return false
        }

        let now = Self.now()
        return commit(
            todos + [CalendarTodo(title: title, notes: notes, day: day, createdAt: now, updatedAt: now)]
        )
    }

    @discardableResult
    func update(
        _ todo: CalendarTodo,
        title: String,
        notes: String,
        day: CalendarTodoDay
    ) -> Bool {
        guard canMutate else {
            fail(CalendarTodoStoreError.liveStoreUnavailable)
            return false
        }

        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else {
            fail(CalendarTodoStoreError.itemNotFound)
            return false
        }

        var candidate = todos
        candidate[index].title = title
        candidate[index].notes = notes
        candidate[index].day = day
        candidate[index].updatedAt = Self.now()
        return commit(candidate)
    }

    @discardableResult
    func toggleCompletion(_ todo: CalendarTodo) -> Bool {
        guard canMutate else {
            fail(CalendarTodoStoreError.liveStoreUnavailable)
            return false
        }

        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else {
            fail(CalendarTodoStoreError.itemNotFound)
            return false
        }

        var candidate = todos
        candidate[index].isCompleted.toggle()
        candidate[index].updatedAt = Self.now()
        return commit(candidate)
    }

    @discardableResult
    func delete(_ todo: CalendarTodo) -> Bool {
        guard canMutate else {
            fail(CalendarTodoStoreError.liveStoreUnavailable)
            return false
        }

        let candidate = todos.filter { $0.id != todo.id }
        guard candidate.count != todos.count else {
            fail(CalendarTodoStoreError.itemNotFound)
            return false
        }
        return commit(candidate)
    }

    func archiveData() throws -> Data {
        guard canMutate else {
            throw CalendarTodoStoreError.liveStoreUnavailable
        }
        return try encoder.encode(
            CalendarTodoDocument(version: Self.currentFormatVersion, todos: todos)
        )
    }

    func todos(fromArchiveData data: Data) throws -> [CalendarTodo] {
        let document: CalendarTodoDocument
        do {
            document = try decoder.decode(CalendarTodoDocument.self, from: data)
        } catch {
            throw CalendarTodoStoreError.invalidArchive
        }

        guard document.version == Self.currentFormatVersion else {
            throw CalendarTodoStoreError.unsupportedVersion(document.version)
        }
        return try Self.validated(document.todos)
    }

    @discardableResult
    func replace(with importedTodos: [CalendarTodo]) -> Bool {
        do {
            let candidate = try Self.validated(importedTodos)
            try persist(candidate)
            todos = candidate
            canMutate = true
            errorMessage = nil
            return true
        } catch {
            fail(error)
            return false
        }
    }

    static func defaultBackupFileName(
        at date: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd"
        return "KeyMaster-Todos-\(formatter.string(from: date)).json"
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            todos = try todos(fromArchiveData: Data(contentsOf: fileURL))
            errorMessage = nil
        } catch {
            todos = []
            canMutate = false
            fail(error)
        }
    }

    private func commit(_ candidate: [CalendarTodo]) -> Bool {
        do {
            let candidate = try Self.validated(candidate)
            try persist(candidate)
            todos = candidate
            errorMessage = nil
            return true
        } catch {
            fail(error)
            return false
        }
    }

    private func persist(_ candidate: [CalendarTodo]) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(
            CalendarTodoDocument(version: Self.currentFormatVersion, todos: candidate)
        )
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func validated(_ todos: [CalendarTodo]) throws -> [CalendarTodo] {
        var ids = Set<UUID>()
        var normalized: [CalendarTodo] = []
        normalized.reserveCapacity(todos.count)

        for var todo in todos {
            todo.title = todo.title.trimmingCharacters(in: .whitespacesAndNewlines)
            todo.notes = todo.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !todo.title.isEmpty else {
                throw CalendarTodoStoreError.invalidTitle
            }
            guard todo.day.isValid else {
                throw CalendarTodoStoreError.invalidDate
            }
            guard ids.insert(todo.id).inserted else {
                throw CalendarTodoStoreError.duplicateID
            }
            normalized.append(todo)
        }

        return normalized.sorted { lhs, rhs in
            if lhs.day != rhs.day {
                return lhs.day < rhs.day
            }
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func fail(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    private static func now() -> Date {
        let milliseconds = (Date().timeIntervalSince1970 * 1_000).rounded(.down)
        return Date(timeIntervalSince1970: milliseconds / 1_000)
    }

    private static func defaultFileURL() -> URL {
        let applicationSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        return applicationSupport
            .appendingPathComponent("KeyMaster", isDirectory: true)
            .appendingPathComponent("todos.json")
    }
}

enum CalendarTodoStoreError: LocalizedError, Equatable {
    case invalidArchive
    case unsupportedVersion(Int)
    case invalidTitle
    case invalidDate
    case duplicateID
    case itemNotFound
    case liveStoreUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            "The Todo data file is invalid."
        case .unsupportedVersion(let version):
            "The Todo data file uses unsupported format version \(version)."
        case .invalidTitle:
            "Todo titles cannot be empty."
        case .invalidDate:
            "The Todo contains an invalid calendar date."
        case .duplicateID:
            "The Todo data file contains duplicate items."
        case .itemNotFound:
            "The Todo no longer exists."
        case .liveStoreUnavailable:
            "The Todo file could not be loaded. Move or remove it, then reopen KeyMaster."
        }
    }
}
