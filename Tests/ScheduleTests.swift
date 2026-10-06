import Foundation
import XCTest
@testable import CrazyAlarmCore

final class ScheduleTests: XCTestCase {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }
    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testDailySchedulesNextMorning() {
        let alarm = AlarmRecord()
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 10, 6, 18, 14), calendar: calendar), date(2026, 10, 7, 7, 20))
    }
    func testOneShotBeforeAndAfterSelectedTime() {
        var alarm = AlarmRecord(); alarm.weekdays = []
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 10, 6, 7, 19), calendar: calendar), date(2026, 10, 6, 7, 20))
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 10, 6, 7, 20), calendar: calendar), date(2026, 10, 7, 7, 20))
    }
    func testSpecificWeekdaysSkipWeekend() {
        var alarm = AlarmRecord(); alarm.weekdays = [.monday, .wednesday, .friday]
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 10, 9, 8, 0), calendar: calendar), date(2026, 10, 12, 7, 20))
    }
    func testSpringDSTGapUsesNextValidTime() {
        var alarm = AlarmRecord(); alarm.hour = 2; alarm.minute = 30
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 3, 8, 0, 0), calendar: calendar), date(2026, 3, 8, 3, 0))
    }
    func testFallDSTOverlapUsesFirstOccurrence() {
        var alarm = AlarmRecord(); alarm.hour = 1; alarm.minute = 30
        let result = alarm.nextFireDate(after: date(2026, 11, 1, 0, 0), calendar: calendar)!
        XCTAssertEqual(calendar.timeZone.secondsFromGMT(for: result), -4 * 3600)
    }
    func testMidnightRolloverAndInvalidTimes() {
        var alarm = AlarmRecord(); alarm.hour = 0; alarm.minute = 0
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 12, 31, 23, 59), calendar: calendar), date(2027, 1, 1, 0, 0))
        alarm.hour = 24
        XCTAssertThrowsError(try alarm.validate())
        XCTAssertNil(alarm.nextFireDate(calendar: calendar))
        alarm.hour = 7; alarm.minute = -1
        XCTAssertThrowsError(try alarm.validate())
    }
    func testMusicAndWeekdaysPersist() throws {
        var alarm = AlarmRecord(); alarm.weekdays = [.monday, .friday]
        alarm.sound = AlarmSound(title: "Song", fileName: "song.mp3", alertFileName: "song-alert.caf")
        let restored = try JSONDecoder().decode(AlarmRecord.self, from: JSONEncoder().encode(alarm))
        XCTAssertEqual(restored, alarm)
    }
}
