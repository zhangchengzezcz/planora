import XCTest
@testable import planora

final class TaskTextRecognizerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 5))!
    }

    func testRecognizesChineseQuickTaskWithoutInventingFields() {
        let result = TaskTextRecognizer.recognize(
            "明天物理作业 完成力学第5题 紧急",
            subjects: ["Physics HL", "Mathematics AA HL"],
            availableTypes: [.assignment, .exam, .custom],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "zh_Hans")
        )

        XCTAssertEqual(result.title, "完成力学第5题")
        XCTAssertEqual(result.subject, "Physics HL")
        XCTAssertEqual(result.type, .assignment)
        XCTAssertEqual(result.priority, .high)
        XCTAssertEqual(PlanoraCalendarDay(date: result.deadline!, calendar: calendar).identifier, "2026-09-06")
    }

    func testRecognizesEnglishSubjectTypeAndExplicitDate() {
        let result = TaskTextRecognizer.recognize(
            "Physics HL lab report: wave investigation 2026-09-18",
            subjects: ["Physics HL", "Mathematics AA HL"],
            availableTypes: [.assignment, .practical, .exam],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(result.title, "wave investigation")
        XCTAssertEqual(result.subject, "Physics HL")
        XCTAssertEqual(result.type, .practical)
        XCTAssertEqual(PlanoraCalendarDay(date: result.deadline!, calendar: calendar).identifier, "2026-09-18")
    }

    func testMonthDayRollsForwardInsteadOfCreatingPastDeadline() {
        let result = TaskTextRecognizer.recognize(
            "Math exam 9/4",
            subjects: ["Mathematics AA HL"],
            availableTypes: [.assignment, .exam],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(PlanoraCalendarDay(date: result.deadline!, calendar: calendar).identifier, "2027-09-04")
    }

    func testSameWeekdayMeansNextWeek() {
        // 2026-09-05 is a Saturday.
        let result = TaskTextRecognizer.recognize(
            "Math quiz Saturday",
            subjects: ["Mathematics"],
            availableTypes: [.exam],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(PlanoraCalendarDay(date: result.deadline!, calendar: calendar).identifier, "2026-09-12")
    }

    func testUnavailableTypeIsNotReturnedOrRemoved() {
        let result = TaskTextRecognizer.recognize(
            "TOK exhibition outline tomorrow",
            subjects: ["English"],
            availableTypes: [.assignment, .exam],
            now: now,
            calendar: calendar
        )

        XCTAssertNil(result.type)
        XCTAssertTrue(result.title.contains("TOK"))
        XCTAssertNotNil(result.deadline)
    }

    func testInvalidCalendarDateIsIgnored() {
        let result = TaskTextRecognizer.recognize(
            "Chemistry homework 2026-02-30",
            subjects: ["Chemistry"],
            availableTypes: [.assignment],
            now: now,
            calendar: calendar
        )

        XCTAssertNil(result.deadline)
        XCTAssertTrue(result.title.contains("2026-02-30"))
    }

    func testShortAcademicAcronymRequiresTokenBoundary() {
        let result = TaskTextRecognizer.recognize(
            "Differential equations practice",
            subjects: ["Mathematics AA HL"],
            availableTypes: [.ia, .assignment],
            now: now,
            calendar: calendar
        )

        XCTAssertNil(result.type)
        XCTAssertEqual(result.title, "Differential equations practice")
    }
}
