import Foundation
import Testing

@testable import nagging_reminder_app

/// Existing installs may have `TaskItem` JSON written with the pre-`RepeatSchedule` shape:
/// `isDaily: Bool` and `nagInterval: Int` (NagInterval rawValue in minutes).
/// `TaskItem.init(from:)` translates those keys; if migration breaks, users lose their tasks.
@Suite("TaskItem legacy migration", .tags(.migration, .codable))
struct TaskItemMigrationTests {

  // MARK: - isDaily → repeatSchedule

  @Test("isDaily=true migrates to .daily(9:00)")
  func legacyIsDailyTrue() throws {
    let task = try decode(legacyJSON(isDaily: true, nagInterval: 60))
    guard case .daily(let time) = task.repeatSchedule else {
      Issue.record("Expected .daily, got \(task.repeatSchedule)")
      return
    }
    #expect(time.hour == 9)
    #expect(time.minute == 0)
  }

  @Test("isDaily=false migrates to .once")
  func legacyIsDailyFalse() throws {
    let task = try decode(legacyJSON(isDaily: false, nagInterval: 60))
    #expect(task.repeatSchedule == .once)
  }

  @Test("Missing schedule keys default to .once")
  func missingScheduleDefaultsToOnce() throws {
    let json = """
      {"id":"\(UUID().uuidString)","name":"x","isCompleted":false,
       "pendingNotificationIDs":[],"nagIntervalMinutes":60}
      """
    let task = try decode(Data(json.utf8))
    #expect(task.repeatSchedule == .once)
  }

  // MARK: - nagInterval → nagIntervalMinutes

  @Test("Legacy nagInterval is read as minutes", arguments: [5, 30, 60, 120])
  func legacyNagIntervalCarriesMinutes(_ minutes: Int) throws {
    let task = try decode(legacyJSON(isDaily: true, nagInterval: minutes))
    #expect(task.nagIntervalMinutes == minutes)
  }

  @Test("Modern nagIntervalMinutes wins over legacy nagInterval")
  func modernKeyTakesPrecedence() throws {
    let json = """
      {"id":"\(UUID().uuidString)","name":"x","isCompleted":false,
       "pendingNotificationIDs":[],"isDaily":true,
       "nagInterval":15,"nagIntervalMinutes":45}
      """
    let task = try decode(Data(json.utf8))
    #expect(task.nagIntervalMinutes == 45)
  }

  @Test("Missing both nag keys defaults to 60")
  func missingNagDefaultsTo60() throws {
    let json = """
      {"id":"\(UUID().uuidString)","name":"x","isCompleted":false,
       "pendingNotificationIDs":[],"isDaily":false}
      """
    let task = try decode(Data(json.utf8))
    #expect(task.nagIntervalMinutes == 60)
  }

  // MARK: - Modern shape round-trip

  @Test("Modern TaskItem survives encode/decode")
  func modernRoundTrip() throws {
    let original = TaskItem(
      name: "exercise",
      repeatSchedule: .daily(time: TimeOfDay(hour: 7, minute: 30)),
      nagIntervalMinutes: 20,
      dueDate: nil
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(TaskItem.self, from: data)
    #expect(decoded.id == original.id)
    #expect(decoded.name == original.name)
    #expect(decoded.repeatSchedule == original.repeatSchedule)
    #expect(decoded.nagIntervalMinutes == original.nagIntervalMinutes)
  }

  // MARK: - Helpers

  private func decode(_ data: Data) throws -> TaskItem {
    try JSONDecoder().decode(TaskItem.self, from: data)
  }

  private func legacyJSON(isDaily: Bool, nagInterval: Int) -> Data {
    let json = """
      {"id":"\(UUID().uuidString)","name":"legacy","isCompleted":false,
       "pendingNotificationIDs":[],"isDaily":\(isDaily),"nagInterval":\(nagInterval)}
      """
    return Data(json.utf8)
  }
}
