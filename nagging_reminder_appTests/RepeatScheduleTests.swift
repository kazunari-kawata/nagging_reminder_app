import Foundation
import Testing

@testable import nagging_reminder_app

@Suite("RepeatSchedule", .tags(.codable))
struct RepeatScheduleTests {

  // MARK: - Codable round-trip

  /// Every enum case must survive an encode/decode round-trip with its associated values intact.
  /// Catches drift between `encode(to:)` and `init(from:)` when a new case is added.
  @Test("Codable round-trip preserves every case", arguments: Self.allCases)
  func codableRoundTrip(_ original: RepeatSchedule) throws {
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(RepeatSchedule.self, from: data)
    #expect(decoded == original)
  }

  /// Unknown discriminator strings fall through to `.once` (forward-compat for stale installs).
  @Test("Unknown type discriminator decodes to .once")
  func unknownTypeFallsBackToOnce() throws {
    let json = #"{"type":"some_future_case"}"#.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(RepeatSchedule.self, from: json)
    #expect(decoded == .once)
  }

  // MARK: - Helpers

  @Test("isRepeating is false only for .once", arguments: Self.allCases)
  func isRepeatingMatchesCase(_ schedule: RepeatSchedule) {
    let expected = !(schedule == .once)
    #expect(schedule.isRepeating == expected)
  }

  @Test("timeOfDay is nil only for .once", arguments: Self.allCases)
  func timeOfDayPresence(_ schedule: RepeatSchedule) {
    if schedule == .once {
      #expect(schedule.timeOfDay == nil)
    } else {
      #expect(schedule.timeOfDay != nil)
    }
  }

  // MARK: - Fixtures

  /// One representative value per case, used by parameterized tests above.
  /// When you add a new `RepeatSchedule` case, add it here and the suite re-validates it.
  static let allCases: [RepeatSchedule] = [
    .once,
    .daily(time: TimeOfDay(hour: 9, minute: 0)),
    .weekdays(time: TimeOfDay(hour: 8, minute: 30)),
    .selectedWeekdays(weekdays: [2, 4, 6], time: TimeOfDay(hour: 18, minute: 15)),
    .weekly(weekday: 3, time: TimeOfDay(hour: 12, minute: 0)),
    .monthly(day: 15, time: TimeOfDay(hour: 7, minute: 45)),
    .yearly(month: 5, day: 10, time: TimeOfDay(hour: 10, minute: 0)),
  ]
}
