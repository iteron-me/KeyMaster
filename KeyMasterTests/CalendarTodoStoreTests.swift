import Foundation
import XCTest
@testable import KeyMaster

@MainActor
final class CalendarTodoStoreTests: XCTestCase {
    func testMutationsPersistAndCompletedItemsSortLast() {
        let (directoryURL, fileURL) = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let day = CalendarTodoDay(year: 2026, month: 7, day: 27)
        let store = CalendarTodoStore(fileURL: fileURL)

        XCTAssertTrue(store.add(title: " First ", notes: " Details ", on: day))
        let first = store.todos[0]
        XCTAssertTrue(store.add(title: "Second", on: day))
        XCTAssertTrue(store.toggleCompletion(first))

        XCTAssertEqual(store.todos(on: day).map(\.title), ["Second", "First"])
        XCTAssertEqual(store.todos(on: day).map(\.isCompleted), [false, true])

        let reloaded = CalendarTodoStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.todos(on: day).map(\.title), ["Second", "First"])
        XCTAssertEqual(reloaded.todos(on: day).map(\.notes), ["", "Details"])
        XCTAssertEqual(reloaded.todos(on: day).map(\.isCompleted), [false, true])
    }

    func testEditCanRescheduleAndDelete() {
        let (directoryURL, fileURL) = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let originalDay = CalendarTodoDay(year: 2026, month: 7, day: 27)
        let newDay = CalendarTodoDay(year: 2026, month: 7, day: 28)
        let store = CalendarTodoStore(fileURL: fileURL)

        XCTAssertTrue(store.add(title: "Move me", on: originalDay))
        let todo = store.todos[0]
        XCTAssertTrue(store.update(todo, title: "Moved", notes: "New content", day: newDay))
        XCTAssertTrue(store.todos(on: originalDay).isEmpty)
        XCTAssertEqual(store.todos(on: newDay).map(\.title), ["Moved"])
        XCTAssertEqual(store.todos(on: newDay).map(\.notes), ["New content"])

        XCTAssertTrue(store.delete(store.todos[0]))
        XCTAssertTrue(CalendarTodoStore(fileURL: fileURL).todos.isEmpty)
    }

    func testArchiveRoundTripAndInvalidArchiveDoNotChangeStore() throws {
        let (directoryURL, fileURL) = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let day = CalendarTodoDay(year: 2026, month: 7, day: 27)
        let store = CalendarTodoStore(fileURL: fileURL)
        XCTAssertTrue(store.add(title: "Keep me", on: day))

        let archive = try store.archiveData()
        let decoded = try XCTUnwrap(store.todos(fromArchiveData: archive).first)
        let original = try XCTUnwrap(store.todos.first)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.notes, original.notes)
        XCTAssertEqual(decoded.day, original.day)
        XCTAssertEqual(decoded.isCompleted, original.isCompleted)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, original.createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.updatedAt.timeIntervalSince1970, original.updatedAt.timeIntervalSince1970, accuracy: 0.001)

        let unsupported = Data(#"{"version":2,"todos":[]}"#.utf8)
        XCTAssertThrowsError(try store.todos(fromArchiveData: unsupported)) { error in
            XCTAssertEqual(error as? CalendarTodoStoreError, .unsupportedVersion(2))
        }
        XCTAssertEqual(store.todos.map(\.title), ["Keep me"])
    }

    func testLegacyArchiveWithoutNotesDefaultsToEmptyContent() throws {
        let (directoryURL, fileURL) = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = CalendarTodoStore(fileURL: fileURL)
        let data = Data(
            #"{"version":1,"todos":[{"id":"00000000-0000-0000-0000-000000000001","title":"Legacy","day":{"year":2026,"month":7,"day":27},"isCompleted":false,"createdAt":"2026-07-27T00:00:00.000Z","updatedAt":"2026-07-27T00:00:00.000Z"}]}"#.utf8
        )

        XCTAssertEqual(try store.todos(fromArchiveData: data).first?.notes, "")
    }

    func testDateOnlyValueDoesNotShiftAcrossTimeZones() throws {
        var shanghai = Calendar(identifier: .gregorian)
        shanghai.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let source = try XCTUnwrap(
            shanghai.date(from: DateComponents(year: 2026, month: 7, day: 27))
        )
        let day = CalendarTodoDay(source, calendar: shanghai)

        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let restored = try XCTUnwrap(day.date(in: losAngeles))
        let components = losAngeles.dateComponents([.year, .month, .day], from: restored)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 27)
    }

    func testDefaultBackupNameIsStable() {
        XCTAssertEqual(
            CalendarTodoStore.defaultBackupFileName(
                at: Date(timeIntervalSince1970: 1_700_000_000),
                timeZone: TimeZone(secondsFromGMT: 0)!
            ),
            "KeyMaster-Todos-20231114.json"
        )
    }

    func testCalendarGridsUseStableDayCounts() {
        let day = CalendarTodoDay(year: 2026, month: 7, day: 27)
        let week = CalendarTodoLayout.week(containing: day)
        let month = CalendarTodoLayout.month(containing: day)

        XCTAssertEqual(week.count, 7)
        XCTAssertTrue(week.contains(day))
        XCTAssertTrue([35, 42].contains(month.count))
        XCTAssertEqual(month.count % 7, 0)
        XCTAssertTrue(month.contains(CalendarTodoDay(year: 2026, month: 7, day: 1)))
        XCTAssertTrue(month.allSatisfy(\.isValid))

        let rowCounts = Set((1...12).map {
            CalendarTodoLayout.month(
                containing: CalendarTodoDay(year: 2026, month: $0, day: 1)
            ).count
        })
        XCTAssertTrue(rowCounts.contains(35))
        XCTAssertTrue(rowCounts.contains(42))
    }

    private func temporaryFileURL() -> (directory: URL, file: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (directory, directory.appendingPathComponent("todos.json"))
    }
}
