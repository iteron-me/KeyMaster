import Foundation

enum CalendarTodoViewMode: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: Self { self }

    var title: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .day: "clock"
        case .week: "calendar.badge.clock"
        case .month: "calendar"
        case .year: "square.grid.3x3"
        }
    }
}

@MainActor
final class CalendarTodoViewState: ObservableObject {
    @Published var viewMode: CalendarTodoViewMode = .month
    @Published private(set) var selectedDay = CalendarTodoDay(Date())
    @Published private(set) var focusRequest = UUID()

    func move(_ direction: Int) {
        guard let date = selectedDay.date() else {
            return
        }

        let component: Calendar.Component
        let value: Int
        switch viewMode {
        case .day:
            component = .day
            value = direction
        case .week:
            component = .day
            value = direction * 7
        case .month:
            component = .month
            value = direction
        case .year:
            component = .year
            value = direction
        }

        guard let moved = Calendar.calendarTodo.date(byAdding: component, value: value, to: date) else {
            return
        }
        selectedDay = CalendarTodoDay(moved)
    }

    func goToToday() {
        selectedDay = CalendarTodoDay(Date())
    }

    func openDay(_ day: CalendarTodoDay) {
        selectedDay = day
        viewMode = .day
        focusRequest = UUID()
    }

    func openMonth(_ day: CalendarTodoDay) {
        selectedDay = day
        viewMode = .month
    }
}

enum CalendarTodoLayout {
    static func week(containing day: CalendarTodoDay) -> [CalendarTodoDay] {
        guard let date = day.date() else {
            return []
        }
        let calendar = Calendar.calendarTodo
        let weekday = calendar.component(.weekday, from: date)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let start = calendar.date(byAdding: .day, value: -offset, to: date) else {
            return []
        }
        return days(startingAt: start, count: 7, calendar: calendar)
    }

    static func month(containing day: CalendarTodoDay) -> [CalendarTodoDay] {
        guard let date = day.date() else {
            return []
        }
        let calendar = Calendar.calendarTodo
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let first = calendar.date(from: components) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: first)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -offset, to: first) else {
            return []
        }
        guard let dayCount = calendar.range(of: .day, in: .month, for: first)?.count else {
            return []
        }
        let rowCount = max(5, Int(ceil(Double(offset + dayCount) / 7)))
        return days(startingAt: gridStart, count: rowCount * 7, calendar: calendar)
    }

    static func months(inYearContaining day: CalendarTodoDay) -> [CalendarTodoDay] {
        (1...12).map { CalendarTodoDay(year: day.year, month: $0, day: 1) }
    }

    static func weekdaySymbols(compact: Bool = false) -> [String] {
        let calendar = Calendar.calendarTodo
        let symbols = compact
            ? calendar.veryShortStandaloneWeekdaySymbols
            : calendar.shortStandaloneWeekdaySymbols
        let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }

    static func periodTitle(mode: CalendarTodoViewMode, day: CalendarTodoDay) -> String {
        guard let date = day.date() else {
            return "Calendar"
        }

        switch mode {
        case .day:
            let formatter = DateFormatter()
            formatter.calendar = .calendarTodo
            formatter.locale = .autoupdatingCurrent
            formatter.dateStyle = .full
            return formatter.string(from: date)
        case .week:
            let dates = week(containing: day).compactMap { $0.date() }
            guard let start = dates.first, let end = dates.last else {
                return "Week"
            }
            let formatter = DateIntervalFormatter()
            formatter.calendar = .calendarTodo
            formatter.locale = .autoupdatingCurrent
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: start, to: end)
        case .month:
            return formatted(date, template: "LLLL yyyy")
        case .year:
            return formatted(date, template: "yyyy")
        }
    }

    static func monthTitle(_ day: CalendarTodoDay, includesYear: Bool = false) -> String {
        guard let date = day.date() else {
            return ""
        }
        return formatted(date, template: includesYear ? "LLLL yyyy" : "LLLL")
    }

    static func isToday(_ day: CalendarTodoDay) -> Bool {
        day == CalendarTodoDay(Date())
    }

    static func dayTitle(_ day: CalendarTodoDay) -> String {
        guard day.day == 1, let date = day.date() else {
            return "\(day.day)"
        }
        return formatted(date, template: "MMMd")
    }

    static func weekNumber(containing day: CalendarTodoDay) -> Int? {
        guard let date = day.date() else {
            return nil
        }
        return Calendar.calendarTodo.component(.weekOfYear, from: date)
    }

    private static func days(
        startingAt start: Date,
        count: Int,
        calendar: Calendar
    ) -> [CalendarTodoDay] {
        var result: [CalendarTodoDay] = []
        result.reserveCapacity(count)
        for offset in 0..<count {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                continue
            }
            result.append(CalendarTodoDay(date, calendar: calendar))
        }
        return result
    }

    private static func formatted(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .calendarTodo
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
