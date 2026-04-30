import XCTest
@testable import JellyTodo

final class JellyTodoCoreTests: XCTestCase {
    func testDailyCheckInRecordNormalizesDateToStartOfDay() throws {
        let rawDate = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 21, minute: 45)))
        let record = DailyCheckInRecord(date: rawDate, completedTodoCount: 3, totalTodoCount: 3, focusSeconds: 3600)

        XCTAssertEqual(record.date, Calendar.current.startOfDay(for: rawDate))
        XCTAssertFalse(record.isMakeUp)
        XCTAssertNil(record.sourceTag)
    }

    func testAppSettingsRoundTripsCheckInIconSelection() throws {
        let settings = AppSettings(
            themeMode: .pinkJelly,
            hapticsEnabled: false,
            pomodoroGoalPerDay: 6,
            textScale: .large,
            language: .chinese,
            checkInIconSelection: CheckInIconSelection(seriesID: "doodleEmoji", packID: "doodle06")
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.themeMode, .pinkJelly)
        XCTAssertEqual(decoded.textScale, .large)
        XCTAssertEqual(decoded.language, .chinese)
        XCTAssertEqual(decoded.checkInIconSelection, settings.checkInIconSelection)
    }

    func testCheckInIconCatalogFallsBackToDefaultPack() {
        let pack = CheckInIconCatalog.packOption(
            for: CheckInIconSelection(seriesID: "missing", packID: "missing")
        )

        XCTAssertEqual(pack.id, CheckInIconSelection.default.packID)
        XCTAssertEqual(pack.seriesID, CheckInIconSelection.default.seriesID)
        XCTAssertEqual(pack.iconAssetNames.count, 9)
    }

    func testTodoItemNormalizesScheduledDates() throws {
        let calendar = Calendar.current
        let first = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 2, hour: 18)))
        let duplicate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 2, hour: 8)))
        let earlier = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 12)))

        let item = TodoItem(
            id: UUID(),
            title: "Review math",
            isCompleted: false,
            createdAt: first,
            updatedAt: first,
            taskDate: first,
            cycle: .manual,
            scheduledDates: [first, duplicate, earlier]
        )

        XCTAssertEqual(item.scheduledDates, [
            calendar.startOfDay(for: earlier),
            calendar.startOfDay(for: first)
        ])
        XCTAssertEqual(item.scheduleMode, .custom)
    }
}
