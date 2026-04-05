import Foundation
import SwiftUI
import UserNotifications

// MARK: - TaskManager

@Observable
final class TaskManager {
  private static let storageKey = "savedTasks_v2"
  private static let historyKey = "taskHistory"

  var tasks: [TaskItem] = [] {
    didSet { save() }
  }

  var history: [HistoryItem] = [] {
    didSet { saveHistory() }
  }

  /// Called after a task is completed so the app layer can trigger a review prompt.
  var onTaskCompleted: (() -> Void)?

  init() {
    load()
    loadHistory()
    registerNotificationCategories()
  }

  // MARK: - Persistence (tasks)

  private func save() {
    if let data = try? JSONEncoder().encode(tasks) {
      UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
      let decoded = try? JSONDecoder().decode([TaskItem].self, from: data)
    else { return }
    tasks = decoded
  }

  // MARK: - Persistence (history)

  private func saveHistory() {
    if let data = try? JSONEncoder().encode(history) {
      UserDefaults.standard.set(data, forKey: Self.historyKey)
    }
  }

  private func loadHistory() {
    guard let data = UserDefaults.standard.data(forKey: Self.historyKey),
      let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data)
    else { return }
    history = decoded
  }

  func clearHistory() {
    history = []
  }

  func deleteAllData() {
    for task in tasks { cancelNotifications(for: task) }
    tasks = []
    history = []
    UserDefaults.standard.removeObject(forKey: Self.storageKey)
    UserDefaults.standard.removeObject(forKey: Self.historyKey)
  }

  /// Archives a task to history (helper used by delete/complete).
  private func archive(_ task: TaskItem, reason: HistoryItem.ArchiveReason) {
    let item = HistoryItem(
      name: task.name,
      schedule: task.repeatSchedule,
      archivedDate: Date(),
      reason: reason
    )
    history.append(item)
  }

  // MARK: - Notification Permission & Categories

  func requestNotificationPermission() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .notDetermined:
        UNUserNotificationCenter.current().requestAuthorization(
          options: [.alert, .sound, .badge]
        ) { granted, _ in
          guard granted else { return }
          DispatchQueue.main.async {
            self.registerNotificationCategories()
            self.rescheduleAllNotifications()
          }
        }
      case .authorized, .provisional, .ephemeral:
        DispatchQueue.main.async { self.rescheduleAllNotifications() }
      default:
        break
      }
    }
  }

  /// Cancels and re-schedules notifications for all incomplete tasks.
  /// Called on launch when permission is authorized, ensuring stale notifications are refreshed.
  func rescheduleAllNotifications() {
    for index in tasks.indices where !tasks[index].isCompleted {
      cancelNotifications(for: tasks[index])
      let ids = buildAndScheduleNotifications(for: tasks[index])
      tasks[index].pendingNotificationIDs = ids
    }
  }

  private func registerNotificationCategories() {
    let snoozeAction = UNNotificationAction(
      identifier: "SNOOZE_1HR",
      title: "Snooze",
      options: []
    )
    let doneAction = UNNotificationAction(
      identifier: "DONE",
      title: "Done",
      options: []
    )
    let category = UNNotificationCategory(
      identifier: "TASK_REMINDER",
      actions: [snoozeAction, doneAction],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  // MARK: - CRUD

  func addTask(name: String, schedule: RepeatSchedule, nagIntervalMinutes: Int, dueDate: Date?) {
    var task = TaskItem(
      name: name, repeatSchedule: schedule, nagIntervalMinutes: nagIntervalMinutes, dueDate: dueDate
    )
    let ids = buildAndScheduleNotifications(for: task)
    task.pendingNotificationIDs = ids
    tasks.append(task)
  }

  /// Inserts preset tasks the first time the user opens the app after onboarding.
  func insertDemoTasksIfNeeded() {
    guard !UserDefaults.standard.bool(forKey: "demoTasksInserted") else { return }
    UserDefaults.standard.set(true, forKey: "demoTasksInserted")

    let presetTasks: [(name: String, schedule: RepeatSchedule, nag: Int)] = [
      (
        String(localized: "preset.task.exercise"),
        .daily(time: TimeOfDay(hour: 9, minute: 0)),
        30
      ),
      (
        String(localized: "preset.task.drink.water"),
        .daily(time: TimeOfDay(hour: 13, minute: 0)),
        30
      ),
      (
        String(localized: "preset.task.vitamin"),
        .daily(time: TimeOfDay(hour: 10, minute: 0)),
        30
      ),
      (
        String(localized: "preset.task.reply.emails"),
        .weekly(weekday: 3, time: TimeOfDay(hour: 11, minute: 30)),
        30
      ),
      (
        String(localized: "preset.task.call.parents"),
        .yearly(month: 5, day: 10, time: TimeOfDay(hour: 10, minute: 0)),
        60
      ),
    ]
    for (name, schedule, nag) in presetTasks {
      addTask(name: name, schedule: schedule, nagIntervalMinutes: nag, dueDate: nil)
    }
  }

  func updateTask(
    _ task: TaskItem, name: String, schedule: RepeatSchedule, nagIntervalMinutes: Int,
    dueDate: Date?
  ) {
    guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
    cancelNotifications(for: tasks[index])
    var updated = tasks[index]
    updated.name = name
    updated.repeatSchedule = schedule
    updated.nagIntervalMinutes = nagIntervalMinutes
    updated.dueDate = dueDate
    updated.isCompleted = false
    updated.lastCompletedDate = nil
    let ids = buildAndScheduleNotifications(for: updated)
    updated.pendingNotificationIDs = ids
    tasks[index] = updated  // single atomic replacement — triggers one UI update
  }

  func deleteTask(at offsets: IndexSet) {
    for index in offsets {
      archive(tasks[index], reason: .deleted)
      cancelNotifications(for: tasks[index])
    }
    tasks.remove(atOffsets: offsets)
  }

  func deleteTask(id: UUID) {
    guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
    archive(tasks[index], reason: .deleted)
    cancelNotifications(for: tasks[index])
    tasks.remove(at: index)
  }

  func completeTask(_ task: TaskItem) {
    guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
    cancelNotifications(for: tasks[index])
    tasks[index].pendingNotificationIDs = []

    if task.repeatSchedule.isRepeating {
      tasks[index].isCompleted = true
      tasks[index].lastCompletedDate = Date()
    } else {
      // Non-repeating: archive to history, then remove
      archive(tasks[index], reason: .completed)
      tasks.remove(at: index)
    }

    onTaskCompleted?()
  }

  // MARK: - Midnight Reset

  func performMidnightResetIfNeeded() {
    let today = Calendar.current.startOfDay(for: Date())
    for index in tasks.indices {
      let task = tasks[index]
      guard task.isCompleted, task.repeatSchedule.isRepeating else { continue }

      let shouldReset: Bool
      if let lastCompleted = task.lastCompletedDate {
        shouldReset = Calendar.current.startOfDay(for: lastCompleted) < today
      } else {
        shouldReset = true
      }

      guard shouldReset else { continue }
      tasks[index].isCompleted = false
      tasks[index].lastCompletedDate = nil
      let ids = buildAndScheduleNotifications(for: tasks[index])
      tasks[index].pendingNotificationIDs = ids
    }
  }

  // MARK: - Snooze

  func snoozeTask(id: UUID, duration: TimeInterval) {
    guard let task = tasks.first(where: { $0.id == id }) else { return }

    let content = makeContent(for: task)
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
    let snoozeID = "\(id.uuidString)_snooze_\(Int(Date().timeIntervalSince1970))"
    let request = UNNotificationRequest(identifier: snoozeID, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)

    if let index = tasks.firstIndex(where: { $0.id == id }) {
      tasks[index].pendingNotificationIDs.append(snoozeID)
    }
  }

  // MARK: - Private Notification Helpers

  private func cancelNotifications(for task: TaskItem) {
    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers: task.pendingNotificationIDs)
  }

  private func makeContent(for task: TaskItem) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = "Baddger"
    content.body = task.name
    content.sound = .default
    content.categoryIdentifier = "TASK_REMINDER"
    content.userInfo = ["taskID": task.id.uuidString]
    return content
  }

  /// Schedules all notifications for the task and returns the list of IDs.
  @discardableResult
  private func buildAndScheduleNotifications(for task: TaskItem) -> [String] {
    let center = UNUserNotificationCenter.current()
    let content = makeContent(for: task)
    let base = task.id.uuidString
    var ids: [String] = []

    func add(id: String, trigger: UNNotificationTrigger) {
      let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
      center.add(req) { error in
        if let error { print("[Notification] Failed to schedule \(id): \(error)") }
      }
      ids.append(id)
    }

    func addNagChain(after baseDate: Date) {
      let intervalSeconds = TimeInterval(task.nagIntervalMinutes * 60)
      // Schedule enough nags to cover at least 12 hours, capped at iOS limit of 60 per task
      let maxNags = min(60, 720 / max(1, task.nagIntervalMinutes))
      for i in 1...maxNags {
        let nagDate = baseDate.addingTimeInterval(intervalSeconds * Double(i))
        guard nagDate > Date() else { continue }
        let comps = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute], from: nagDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        add(id: "\(base)_nag_\(i)", trigger: trigger)
      }
    }

    switch task.repeatSchedule {

    case .once:
      if let due = task.dueDate, due > Date() {
        let comps = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute], from: due
        )
        add(
          id: "\(base)_0",
          trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        addNagChain(after: due)
      } else if task.dueDate == nil {
        add(
          id: "\(base)_0",
          trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false))
      }

    case .daily(let time):
      var comps = DateComponents()
      comps.hour = time.hour
      comps.minute = time.minute
      add(
        id: "\(base)_0",
        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
      if let next = nextFireDate(for: task.repeatSchedule) { addNagChain(after: next) }

    case .weekdays(let time):
      for weekday in 2...6 {
        var comps = DateComponents()
        comps.weekday = weekday
        comps.hour = time.hour
        comps.minute = time.minute
        add(
          id: "\(base)_wd_\(weekday)",
          trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
      }
      if let next = nextFireDate(for: task.repeatSchedule) { addNagChain(after: next) }

    case .selectedWeekdays(let weekdays, let time):
      for weekday in weekdays {
        var comps = DateComponents()
        comps.weekday = weekday
        comps.hour = time.hour
        comps.minute = time.minute
        add(
          id: "\(base)_wd_\(weekday)",
          trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
      }
      if let next = nextFireDate(for: task.repeatSchedule) { addNagChain(after: next) }

    case .weekly(let weekday, let time):
      var comps = DateComponents()
      comps.weekday = weekday
      comps.hour = time.hour
      comps.minute = time.minute
      add(
        id: "\(base)_0",
        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
      if let next = nextFireDate(for: task.repeatSchedule) { addNagChain(after: next) }

    case .monthly(let day, let time):
      var comps = DateComponents()
      comps.day = day
      comps.hour = time.hour
      comps.minute = time.minute
      add(
        id: "\(base)_0",
        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
      if let next = nextFireDate(for: task.repeatSchedule) { addNagChain(after: next) }

    case .yearly(let month, let day, let time):
      var comps = DateComponents()
      comps.month = month
      comps.day = day
      comps.hour = time.hour
      comps.minute = time.minute
      add(
        id: "\(base)_0",
        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
      if let next = nextFireDate(for: task.repeatSchedule) { addNagChain(after: next) }
    }

    return ids
  }

  // MARK: - Public Helpers

  /// Returns the next scheduled fire date for a task (used by UI for section grouping).
  /// For `.once` tasks the due date is used as the next occurrence.
  func nextOccurrenceDate(for task: TaskItem) -> Date? {
    if case .once = task.repeatSchedule { return task.dueDate }
    return nextFireDate(for: task.repeatSchedule)
  }

  /// Returns true if this task's schedule applies to today's calendar date.
  func isApplicableToday(_ task: TaskItem) -> Bool {
    let cal = Calendar.current
    let now = Date()
    let weekday = cal.component(.weekday, from: now)  // 1=Sun … 7=Sat
    let day = cal.component(.day, from: now)
    let month = cal.component(.month, from: now)
    switch task.repeatSchedule {
    case .once:
      if let due = task.dueDate { return cal.isDateInToday(due) }
      return true
    case .daily:
      return true
    case .weekdays:
      return weekday >= 2 && weekday <= 6
    case .selectedWeekdays(let weekdays, _):
      return weekdays.contains(weekday)
    case .weekly(let wd, _):
      return weekday == wd
    case .monthly(let d, _):
      return day == d
    case .yearly(let m, let d, _):
      return month == m && day == d
    }
  }

  private func nextFireDate(for schedule: RepeatSchedule, after date: Date = Date()) -> Date? {
    let cal = Calendar.current

    switch schedule {
    case .once:
      return nil

    case .daily(let time):
      var comps = DateComponents()
      comps.hour = time.hour
      comps.minute = time.minute
      comps.second = 0
      return cal.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)

    case .weekdays(let time):
      var comps = DateComponents()
      comps.hour = time.hour
      comps.minute = time.minute
      comps.second = 0
      var search = date
      for _ in 0..<14 {
        guard
          let candidate = cal.nextDate(after: search, matching: comps, matchingPolicy: .nextTime)
        else { break }
        let wd = cal.component(.weekday, from: candidate)
        if wd >= 2 && wd <= 6 { return candidate }
        search = candidate
      }
      return nil

    case .selectedWeekdays(let weekdays, let time):
      var comps = DateComponents()
      comps.hour = time.hour
      comps.minute = time.minute
      comps.second = 0
      var search = date
      for _ in 0..<14 {
        guard
          let candidate = cal.nextDate(after: search, matching: comps, matchingPolicy: .nextTime)
        else { break }
        let wd = cal.component(.weekday, from: candidate)
        if weekdays.contains(wd) { return candidate }
        search = candidate
      }
      return nil

    case .weekly(let weekday, let time):
      var comps = DateComponents()
      comps.weekday = weekday
      comps.hour = time.hour
      comps.minute = time.minute
      comps.second = 0
      return cal.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)

    case .monthly(let day, let time):
      var comps = DateComponents()
      comps.day = day
      comps.hour = time.hour
      comps.minute = time.minute
      comps.second = 0
      return cal.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)

    case .yearly(let month, let day, let time):
      var comps = DateComponents()
      comps.month = month
      comps.day = day
      comps.hour = time.hour
      comps.minute = time.minute
      comps.second = 0
      return cal.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)
    }
  }
}

// MARK: - NotificationDelegate

@Observable
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  var taskManager: TaskManager?
  var tappedTaskID: UUID?

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let uuidString = response.notification.request.content.userInfo["taskID"] as? String
    let uuid = uuidString.flatMap { UUID(uuidString: $0) }

    if response.actionIdentifier == "SNOOZE_1HR", let uuid {
      let duration: TimeInterval
      if let task = taskManager?.tasks.first(where: { $0.id == uuid }) {
        duration = TimeInterval(task.nagIntervalMinutes * 60)
      } else {
        duration = 3600
      }
      taskManager?.snoozeTask(id: uuid, duration: duration)
    } else if response.actionIdentifier == "DONE", let uuid,
      let task = taskManager?.tasks.first(where: { $0.id == uuid })
    {
      taskManager?.completeTask(task)
    } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier, let uuid {
      DispatchQueue.main.async { self.tappedTaskID = uuid }
    }
    completionHandler()
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
