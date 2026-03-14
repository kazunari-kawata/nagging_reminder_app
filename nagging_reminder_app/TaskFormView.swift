import SwiftUI

// MARK: - ScheduleTypeSelection (picker helper)

enum ScheduleTypeSelection: String, CaseIterable, Identifiable {
  case once, daily, weekdays, customWeekdays, weekly, monthly, yearly
  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .once: return "Once"
    case .daily: return "Daily"
    case .weekdays: return "Weekdays (Mon–Fri)"
    case .customWeekdays: return "Custom Days"
    case .weekly: return "Weekly"
    case .monthly: return "Monthly"
    case .yearly: return "Yearly"
    }
  }
}

// MARK: - NagIntervalOption

enum NagIntervalOption: Int, CaseIterable, Identifiable {
  case off = 0
  case every1min = 1
  case every5min = 5
  case every10min = 10
  case every15min = 15
  case every30min = 30
  case every60min = 60

  var id: Int { rawValue }

  var displayName: String {
    switch self {
    case .off: return "自動スヌーズオフ"
    case .every1min: return "毎分"
    case .every5min: return "毎5分"
    case .every10min: return "毎10分"
    case .every15min: return "毎15分"
    case .every30min: return "毎30分"
    case .every60min: return "毎時"
    }
  }

  /// Map from a stored nagIntervalMinutes value to the closest option.
  static func from(minutes: Int) -> NagIntervalOption {
    if minutes <= 0 { return .off }
    // Find the closest match
    return allCases.filter { $0 != .off }.min(by: {
      abs($0.rawValue - minutes) < abs($1.rawValue - minutes)
    }) ?? .every60min
  }
}

// MARK: - TaskFormMode

enum TaskFormMode {
  case add
  case edit(TaskItem)
}

// MARK: - TaskFormView

struct TaskFormView: View {
  @Environment(TaskManager.self) private var taskManager
  @Environment(\.dismiss) private var dismiss

  let mode: TaskFormMode

  // Form state
  @State private var taskName: String = ""
  @State private var scheduleType: ScheduleTypeSelection = .once
  @State private var selectedWeekday: Int = 2  // Monday (for .weekly)
  @State private var selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6]  // Mon–Fri (for .customWeekdays)
  @State private var selectedDay: Int = 1
  @State private var selectedMonth: Int = 1
  @State private var selectedHour: Int = 9
  @State private var selectedMinute: Int = 0
  @State private var hasDueDate: Bool = false
  @State private var dueDate: Date = Date().addingTimeInterval(3600)
  @State private var nagIntervalOption: NagIntervalOption = .every60min
  @State private var nagCount: Int = 3
  @State private var isTimeSensitive: Bool = false
  @State private var showPastDateAlert: Bool = false

  private var isEditing: Bool {
    if case .edit = mode { return true }
    return false
  }

  // Derived time binding for DatePicker
  private var timeDateBinding: Binding<Date> {
    Binding(
      get: {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = selectedHour
        comps.minute = selectedMinute
        return Calendar.current.date(from: comps) ?? Date()
      },
      set: { date in
        selectedHour = Calendar.current.component(.hour, from: date)
        selectedMinute = Calendar.current.component(.minute, from: date)
      }
    )
  }

  var body: some View {
    NavigationStack {
      Form {
        // Task Name
        Section {
          TextField("Task name", text: $taskName)
        }

        // Schedule
        Section("Schedule") {
          Picker("Repeat", selection: $scheduleType) {
            ForEach(ScheduleTypeSelection.allCases) { type in
              Text(type.displayName).tag(type)
            }
          }

          // Custom weekday selector
          if scheduleType == .customWeekdays {
            HStack(spacing: 6) {
              ForEach(1...7, id: \.self) { day in
                let shortNames = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                let isSelected = selectedWeekdays.contains(day)
                Button {
                  if isSelected {
                    selectedWeekdays.remove(day)
                  } else {
                    selectedWeekdays.insert(day)
                  }
                } label: {
                  Text(shortNames[day - 1])
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(isSelected ? Color.white : Color(.label))
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
              }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
          }

          if scheduleType == .weekly {
            Picker("Day", selection: $selectedWeekday) {
              ForEach(1...7, id: \.self) { day in
                Text(weekdayName(day)).tag(day)
              }
            }
          }

          if scheduleType == .monthly {
            Picker("Day of month", selection: $selectedDay) {
              ForEach(1...31, id: \.self) { day in
                Text("Day \(day)").tag(day)
              }
            }
          }

          if scheduleType == .yearly {
            Picker("Month", selection: $selectedMonth) {
              ForEach(1...12, id: \.self) { month in
                Text(monthName(month)).tag(month)
              }
            }
            Picker("Day", selection: $selectedDay) {
              ForEach(1...31, id: \.self) { day in
                Text("Day \(day)").tag(day)
              }
            }
          }

          if scheduleType != .once {
            DatePicker("Time", selection: timeDateBinding, displayedComponents: .hourAndMinute)
          }

          if scheduleType == .once {
            Toggle("Set due date", isOn: $hasDueDate)
            if hasDueDate {
              DatePicker(
                "Due date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
            }
          }
        }

        // Nag Interval
        Section("Nag interval") {
          Picker("Interval", selection: $nagIntervalOption) {
            ForEach(NagIntervalOption.allCases) { option in
              Text(option.displayName).tag(option)
            }
          }
        }

        // Nag Count (hidden when snooze is off)
        if nagIntervalOption != .off {
          Section("Nag count") {
            Stepper("\(nagCount) times", value: $nagCount, in: 1...20)
          }
        }

        // Time Sensitive
        Section {
          Toggle("時間を意識した通知", isOn: $isTimeSensitive)

          if isTimeSensitive {
            Text("集中モード / おやすみモード中でも通知が届きます")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("Time Sensitive")
        }
      }
      .navigationTitle(isEditing ? "Edit Task" : "Add Task")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            let due: Date? = (scheduleType == .once && hasDueDate) ? dueDate : nil
            if let due, due < Date() {
              showPastDateAlert = true
            } else {
              save()
              dismiss()
            }
          }
          .disabled(taskName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
    .onAppear {
      populateIfEditing()
    }
    .alert("過去の日付のタスクは追加できません", isPresented: $showPastDateAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("期日には現在より先の日時を設定してください。")
    }
  }

  // MARK: - Helpers

  private func populateIfEditing() {
    guard case .edit(let task) = mode else { return }
    taskName = task.name
    nagIntervalOption = NagIntervalOption.from(minutes: task.nagIntervalMinutes)
    nagCount = task.nagCount
    isTimeSensitive = task.isTimeSensitive

    switch task.repeatSchedule {
    case .once:
      scheduleType = .once
      if let due = task.dueDate {
        hasDueDate = true
        dueDate = due
      }
    case .daily(let time):
      scheduleType = .daily
      selectedHour = time.hour
      selectedMinute = time.minute
    case .weekdays(let time):
      scheduleType = .weekdays
      selectedHour = time.hour
      selectedMinute = time.minute
    case .selectedWeekdays(let weekdays, let time):
      scheduleType = .customWeekdays
      selectedWeekdays = Set(weekdays)
      selectedHour = time.hour
      selectedMinute = time.minute
    case .weekly(let weekday, let time):
      scheduleType = .weekly
      selectedWeekday = weekday
      selectedHour = time.hour
      selectedMinute = time.minute
    case .monthly(let day, let time):
      scheduleType = .monthly
      selectedDay = day
      selectedHour = time.hour
      selectedMinute = time.minute
    case .yearly(let month, let day, let time):
      scheduleType = .yearly
      selectedMonth = month
      selectedDay = day
      selectedHour = time.hour
      selectedMinute = time.minute
    }
  }

  private func buildSchedule() -> RepeatSchedule {
    let time = TimeOfDay(hour: selectedHour, minute: selectedMinute)
    switch scheduleType {
    case .once: return .once
    case .daily: return .daily(time: time)
    case .weekdays: return .weekdays(time: time)
    case .customWeekdays:
      return .selectedWeekdays(weekdays: Array(selectedWeekdays).sorted(), time: time)
    case .weekly: return .weekly(weekday: selectedWeekday, time: time)
    case .monthly: return .monthly(day: selectedDay, time: time)
    case .yearly: return .yearly(month: selectedMonth, day: selectedDay, time: time)
    }
  }

  private func save() {
    let trimmedName = taskName.trimmingCharacters(in: .whitespaces)
    let schedule = buildSchedule()
    let due: Date? = (scheduleType == .once && hasDueDate) ? dueDate : nil
    let intervalMinutes = nagIntervalOption.rawValue
    let effectiveNagCount = nagIntervalOption == .off ? 1 : nagCount

    switch mode {
    case .add:
      taskManager.addTask(
        name: trimmedName, schedule: schedule, nagIntervalMinutes: intervalMinutes,
        nagCount: effectiveNagCount, isTimeSensitive: isTimeSensitive, dueDate: due)
    case .edit(let task):
      taskManager.updateTask(
        task, name: trimmedName, schedule: schedule, nagIntervalMinutes: intervalMinutes,
        nagCount: effectiveNagCount, isTimeSensitive: isTimeSensitive, dueDate: due)
    }
  }

  private func weekdayName(_ weekday: Int) -> String {
    let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    guard weekday >= 1 && weekday <= 7 else { return "" }
    return names[weekday - 1]
  }

  private func monthName(_ month: Int) -> String {
    let names = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December",
    ]
    guard month >= 1 && month <= 12 else { return "" }
    return names[month - 1]
  }
}
