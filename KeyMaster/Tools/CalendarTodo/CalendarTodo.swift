import Foundation

struct CalendarTodoDay: Codable, Hashable, Comparable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .calendarTodo) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 1
        month = components.month ?? 1
        day = components.day ?? 1
    }

    func date(in calendar: Calendar = .calendarTodo) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    var isValid: Bool {
        let calendar = Calendar.calendarTodo
        guard let date = date(in: calendar) else {
            return false
        }

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return components.year == year && components.month == month && components.day == day
    }

    static func < (lhs: CalendarTodoDay, rhs: CalendarTodoDay) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        if lhs.month != rhs.month {
            return lhs.month < rhs.month
        }
        return lhs.day < rhs.day
    }
}

struct CalendarTodo: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var notes: String
    var day: CalendarTodoDay
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        day: CalendarTodoDay,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.day = day
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case day
        case isCompleted
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        day = try container.decode(CalendarTodoDay.self, forKey: .day)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct CalendarTodoDocument: Codable, Equatable {
    var version: Int
    var todos: [CalendarTodo]
}

extension Calendar {
    static var calendarTodo: Calendar {
        let systemCalendar = Calendar.autoupdatingCurrent
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = systemCalendar.firstWeekday
        calendar.minimumDaysInFirstWeek = systemCalendar.minimumDaysInFirstWeek
        return calendar
    }
}
