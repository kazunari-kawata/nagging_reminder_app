import SwiftUI

// MARK: - ScheduleTypeSelection (picker helper)

enum ScheduleTypeSelection: String, CaseIterable, Identifiable {
  case once, daily, weekdays, customWeekdays, weekly, monthly, yearly
  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .once: return String(localized: "Once")
    case .daily: return String(localized: "Daily")
    case .weekdays: return String(localized: "Weekdays (Mon–Fri)")
    case .customWeekdays: return String(localized: "Custom Days")
    case .weekly: return String(localized: "Weekly")
    case .monthly: return String(localized: "Monthly")
    case .yearly: return String(localized: "Yearly")
    }
  }
}

// MARK: - TaskFormView

struct TaskFormView: View {
  @Environment(TaskManager.self) private var taskManager
  @Environment(\.dismiss) private var dismiss

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
  @State private var nagIntervalHours: Int = 0
  @State private var nagIntervalMins: Int = 5
  @FocusState private var isNameFieldFocused: Bool

  private var nagIntervalMinutes: Int { max(1, nagIntervalHours * 60 + nagIntervalMins) }
  private let taskNameLimit = 50
  private var isOverLimit: Bool { taskName.count > taskNameLimit }

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
            .focused($isNameFieldFocused)
            .onChange(of: taskName) { _, new in
              if new.count > taskNameLimit {
                taskName = String(new.prefix(taskNameLimit))
              }
            }
          if isOverLimit {
            Text("\(taskNameLimit)文字以内にしてください")
              .font(.caption)
              .foregroundStyle(.red)
          }
          HStack {
            Spacer()
            Text("\(taskName.count)/\(taskNameLimit)")
              .font(.caption2)
              .foregroundStyle(taskName.count >= taskNameLimit ? .red : Color(.systemGray3))
          }
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

        // Alert frequency— hour + minute wheel pickers
        Section("Alert frequency") {
          HStack(spacing: 0) {
            Picker("Hours", selection: $nagIntervalHours) {
              ForEach(0...8, id: \.self) { h in
                Text("\(h) hr").tag(h)
              }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("Minutes", selection: $nagIntervalMins) {
              ForEach(0...59, id: \.self) { m in
                Text("\(m) min").tag(m)
              }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
          }
          .frame(height: 120)
        }

      }
      .navigationTitle(LocalizedStringResource("form.add.task"))
      .navigationBarTitleDisplayMode(.inline)
      .scrollDismissesKeyboard(.interactively)
      .onChange(of: scheduleType) { _, _ in isNameFieldFocused = false }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            save()
            dismiss()
          }
          .disabled(taskName.trimmingCharacters(in: .whitespaces).isEmpty || isOverLimit)
        }
      }
    }
  }

  // MARK: - Helpers

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
    taskManager.addTask(
      name: trimmedName, schedule: schedule, nagIntervalMinutes: nagIntervalMinutes, dueDate: due)
  }

  private func weekdayName(_ weekday: Int) -> String {
    let names: [Int: String] = [
      1: String(localized: "Sunday"),
      2: String(localized: "Monday"),
      3: String(localized: "Tuesday"),
      4: String(localized: "Wednesday"),
      5: String(localized: "Thursday"),
      6: String(localized: "Friday"),
      7: String(localized: "Saturday"),
    ]
    return names[weekday] ?? ""
  }

  private func monthName(_ month: Int) -> String {
    let names: [Int: String] = [
      1: String(localized: "January"),
      2: String(localized: "February"),
      3: String(localized: "March"),
      4: String(localized: "April"),
      5: String(localized: "May"),
      6: String(localized: "June"),
      7: String(localized: "July"),
      8: String(localized: "August"),
      9: String(localized: "September"),
      10: String(localized: "October"),
      11: String(localized: "November"),
      12: String(localized: "December"),
    ]
    return names[month] ?? ""
  }
}
