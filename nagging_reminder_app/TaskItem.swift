import Foundation

struct TaskItem: Identifiable, Equatable {
  var id: UUID
  var name: String
  var repeatSchedule: RepeatSchedule
  var nagIntervalMinutes: Int  // minutes between nag notifications
  var dueDate: Date?
  var isCompleted: Bool
  var lastCompletedDate: Date?
  var nextDateOverride: Date?  // manual override for next occurrence date
  var pendingNotificationIDs: [String]

  init(
    id: UUID = UUID(),
    name: String,
    repeatSchedule: RepeatSchedule = .once,
    nagIntervalMinutes: Int = 60,
    dueDate: Date? = nil,
    isCompleted: Bool = false,
    lastCompletedDate: Date? = nil,
    nextDateOverride: Date? = nil,
    pendingNotificationIDs: [String] = []
  ) {
    self.id = id
    self.name = name
    self.repeatSchedule = repeatSchedule
    self.nagIntervalMinutes = nagIntervalMinutes
    self.dueDate = dueDate
    self.isCompleted = isCompleted
    self.lastCompletedDate = lastCompletedDate
    self.nextDateOverride = nextDateOverride
    self.pendingNotificationIDs = pendingNotificationIDs
  }
}

// MARK: - Codable with legacy migration

extension TaskItem: Codable {
  enum CodingKeys: String, CodingKey {
    case id, name, repeatSchedule
    case nagIntervalMinutes
    case nagInterval  // legacy key (NagInterval enum, stored as Int rawValue in minutes)
    case dueDate, isCompleted, lastCompletedDate, nextDateOverride, pendingNotificationIDs
    case isDaily  // legacy key
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(name, forKey: .name)
    try c.encode(repeatSchedule, forKey: .repeatSchedule)
    try c.encode(nagIntervalMinutes, forKey: .nagIntervalMinutes)
    try c.encodeIfPresent(dueDate, forKey: .dueDate)
    try c.encode(isCompleted, forKey: .isCompleted)
    try c.encodeIfPresent(lastCompletedDate, forKey: .lastCompletedDate)
    try c.encodeIfPresent(nextDateOverride, forKey: .nextDateOverride)
    try c.encode(pendingNotificationIDs, forKey: .pendingNotificationIDs)
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)

    id = try c.decode(UUID.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)

    // Migration: prefer new repeatSchedule; fall back to legacy isDaily bool
    if let schedule = try c.decodeIfPresent(RepeatSchedule.self, forKey: .repeatSchedule) {
      repeatSchedule = schedule
    } else if let wasDaily = try c.decodeIfPresent(Bool.self, forKey: .isDaily) {
      let defaultTime = TimeOfDay(hour: 9, minute: 0)
      repeatSchedule = wasDaily ? .daily(time: defaultTime) : .once
    } else {
      repeatSchedule = .once
    }

    // Migration: prefer nagIntervalMinutes; fall back to legacy nagInterval (NagInterval enum rawValue = minutes)
    if let minutes = try c.decodeIfPresent(Int.self, forKey: .nagIntervalMinutes) {
      nagIntervalMinutes = minutes
    } else if let legacyRaw = try c.decodeIfPresent(Int.self, forKey: .nagInterval) {
      nagIntervalMinutes = legacyRaw
    } else {
      nagIntervalMinutes = 60
    }

    dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
    isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
    lastCompletedDate = try c.decodeIfPresent(Date.self, forKey: .lastCompletedDate)
    nextDateOverride = try c.decodeIfPresent(Date.self, forKey: .nextDateOverride)
    pendingNotificationIDs =
      try c.decodeIfPresent([String].self, forKey: .pendingNotificationIDs) ?? []
  }
}
