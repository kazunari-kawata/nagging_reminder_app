import SwiftUI

// MARK: - TaskQuickEditView

/// Compact dialog-style task view shown when tapping a task card or notification.
/// Integrates full editing (name, schedule, nag interval) with snooze and action buttons.
struct TaskQuickEditView: View {
  @Environment(TaskManager.self) private var taskManager
  @Environment(\.dismiss) private var dismiss

  let task: TaskItem
  var onDelete: (() -> Void)?

  // Date / Time
  @State private var editDate: Date
  @State private var editTime: Date
  @State private var initialDate: Date = .distantPast
  @State private var initialTime: Date = .distantPast

  // Task name
  @State private var taskName: String
  @State private var initialName: String = ""
  private let taskNameLimit = 50

  // Schedule
  @State private var scheduleType: ScheduleTypeSelection
  @State private var initialScheduleType: ScheduleTypeSelection = .once
  @State private var selectedWeekday: Int
  @State private var selectedWeekdays: Set<Int>
  @State private var selectedDay: Int
  @State private var selectedMonth: Int

  // Nag interval
  @State private var nagIntervalHours: Int
  @State private var nagIntervalMins: Int
  @State private var initialNagHours: Int = 0
  @State private var initialNagMins: Int = 5

  // Due date for .once
  @State private var hasDueDate: Bool
  @State private var dueDate: Date

  // Section visibility
  @State private var showDatePicker = false
  @State private var showTimePicker = false
  @State private var showScheduleEditor = false
  @State private var showNagEditor = false
  @State private var showDeleteConfirm = false

  // Dialog animation
  @State private var dialogVisible = false

  private var nagIntervalMinutes: Int { max(1, nagIntervalHours * 60 + nagIntervalMins) }

  init(task: TaskItem, onDelete: (() -> Void)? = nil) {
    self.task = task
    self.onDelete = onDelete

    _taskName = State(initialValue: task.name)

    // Initialize time from schedule
    let now = Date()
    if let tod = task.repeatSchedule.timeOfDay {
      let cal = Calendar.current
      let t = cal.date(bySettingHour: tod.hour, minute: tod.minute, second: 0, of: now) ?? now
      _editTime = State(initialValue: t)
    } else if let due = task.dueDate {
      _editTime = State(initialValue: due)
    } else {
      _editTime = State(initialValue: now)
    }
    _editDate = State(initialValue: task.dueDate ?? now)

    // Nag interval
    _nagIntervalHours = State(initialValue: task.nagIntervalMinutes / 60)
    _nagIntervalMins = State(initialValue: task.nagIntervalMinutes % 60)

    // Due date for .once
    _hasDueDate = State(initialValue: task.dueDate != nil)
    _dueDate = State(initialValue: task.dueDate ?? now.addingTimeInterval(3600))

    // Schedule fields
    switch task.repeatSchedule {
    case .once:
      _scheduleType = State(initialValue: .once)
      _selectedWeekday = State(initialValue: 2)
      _selectedWeekdays = State(initialValue: [2, 3, 4, 5, 6])
      _selectedDay = State(initialValue: 1)
      _selectedMonth = State(initialValue: 1)
    case .daily:
      _scheduleType = State(initialValue: .daily)
      _selectedWeekday = State(initialValue: 2)
      _selectedWeekdays = State(initialValue: [2, 3, 4, 5, 6])
      _selectedDay = State(initialValue: 1)
      _selectedMonth = State(initialValue: 1)
    case .weekdays:
      _scheduleType = State(initialValue: .weekdays)
      _selectedWeekday = State(initialValue: 2)
      _selectedWeekdays = State(initialValue: [2, 3, 4, 5, 6])
      _selectedDay = State(initialValue: 1)
      _selectedMonth = State(initialValue: 1)
    case .selectedWeekdays(let weekdays, _):
      _scheduleType = State(initialValue: .customWeekdays)
      _selectedWeekday = State(initialValue: 2)
      _selectedWeekdays = State(initialValue: Set(weekdays))
      _selectedDay = State(initialValue: 1)
      _selectedMonth = State(initialValue: 1)
    case .weekly(let weekday, _):
      _scheduleType = State(initialValue: .weekly)
      _selectedWeekday = State(initialValue: weekday)
      _selectedWeekdays = State(initialValue: [2, 3, 4, 5, 6])
      _selectedDay = State(initialValue: 1)
      _selectedMonth = State(initialValue: 1)
    case .monthly(let day, _):
      _scheduleType = State(initialValue: .monthly)
      _selectedWeekday = State(initialValue: 2)
      _selectedWeekdays = State(initialValue: [2, 3, 4, 5, 6])
      _selectedDay = State(initialValue: day)
      _selectedMonth = State(initialValue: 1)
    case .yearly(let month, let day, _):
      _scheduleType = State(initialValue: .yearly)
      _selectedWeekday = State(initialValue: 2)
      _selectedWeekdays = State(initialValue: [2, 3, 4, 5, 6])
      _selectedDay = State(initialValue: day)
      _selectedMonth = State(initialValue: month)
    }
  }

  // MARK: - Computed: next occurrence from TaskManager

  private var currentNextDate: Date {
    taskManager.nextOccurrenceDate(for: task) ?? Date()
  }

  // MARK: - Change Detection

  private var hasChanges: Bool {
    let cal = Calendar.current
    let dateChanged = cal.startOfDay(for: editDate) != cal.startOfDay(for: initialDate)
    let timeH = cal.component(.hour, from: editTime)
    let timeM = cal.component(.minute, from: editTime)
    let initH = cal.component(.hour, from: initialTime)
    let initM = cal.component(.minute, from: initialTime)
    let timeChanged = timeH != initH || timeM != initM
    let nameChanged = taskName.trimmingCharacters(in: .whitespaces) != initialName
    let scheduleChanged = scheduleType != initialScheduleType
    let nagChanged = nagIntervalHours != initialNagHours || nagIntervalMins != initialNagMins
    return dateChanged || timeChanged || nameChanged || scheduleChanged || nagChanged
  }

  private var canSave: Bool {
    !taskName.trimmingCharacters(in: .whitespaces).isEmpty && taskName.count <= taskNameLimit
  }

  // MARK: - Formatters

  private var dateString: String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy/MM/dd"
    return fmt.string(from: editDate)
  }

  private var timeString: String {
    let fmt = DateFormatter()
    fmt.dateFormat = "H:mm"
    return fmt.string(from: editTime)
  }

  private var nagSummary: String {
    if nagIntervalHours > 0 && nagIntervalMins > 0 {
      return "\(nagIntervalHours)h \(nagIntervalMins)min"
    } else if nagIntervalHours > 0 {
      return "\(nagIntervalHours)h"
    } else {
      return "\(max(1, nagIntervalMins))min"
    }
  }

  /// Dynamic max-height ratio based on which picker is open.
  private var maxHeightRatio: CGFloat {
    let base: CGFloat = 0.4
    if showDatePicker { return base + 0.25 }  // graphical calendar is tall
    if showTimePicker { return base + 0.12 }  // wheel picker ~150pt
    if showNagEditor { return base + 0.10 }  // two wheels ~120pt
    if showScheduleEditor { return base + 0.08 }  // menu picker row
    return base
  }

  // MARK: - Body

  var body: some View {
    ZStack {
      Color.black.opacity(dialogVisible ? 0.95 : 0)
        .ignoresSafeArea()
        .onTapGesture { dismissAnimated() }

      VStack(spacing: 0) {
        dialogContent
        Spacer().frame(height: 40)
        actionBar
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 24)
      .opacity(dialogVisible ? 1 : 0)
      .offset(y: dialogVisible ? 0 : 80)
      .animation(.easeOut(duration: 0.3), value: dialogVisible)
    }
    .alert(
      String(localized: "task.delete.alert.title"),
      isPresented: $showDeleteConfirm
    ) {
      Button(String(localized: "Delete"), role: .destructive) {
        onDelete?()
        dismissAnimated()
      }
      Button(String(localized: "Cancel"), role: .cancel) {}
    }
    .onAppear {
      editDate = currentNextDate
      initialDate = currentNextDate
      initialTime = editTime
      initialName = task.name
      initialScheduleType = scheduleType
      initialNagHours = nagIntervalHours
      initialNagMins = nagIntervalMins
      withAnimation(.easeOut(duration: 0.3)) { dialogVisible = true }
    }
  }

  // MARK: - Dialog Content

  private var dialogContent: some View {
    ScrollView {
      VStack(spacing: 0) {
        // Header: close + save
        HStack(spacing: 12) {
          Button {
            dismissAnimated()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 24))
              .foregroundStyle(Color(.systemGray))
          }
          Spacer()
          Button(String(localized: "task.quickedit.save")) {
            dismissAnimated()
          }
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(hasChanges && canSave ? Color.blue : Color(.systemGray2))
          .disabled(!canSave)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)

        // Task name
        nameSection

        // Schedule section (collapsible)
        scheduleSection

        // Date / Time row
        dateTimeRow
          .padding(.horizontal, 16)
          .padding(.bottom, 8)

        // Date picker (expandable)
        if showDatePicker {
          DatePicker("", selection: $editDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .padding(.horizontal, 8)
            .transition(.move(edge: .top))
        }

        // Time picker (expandable)
        if showTimePicker {
          DatePicker("", selection: $editTime, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .frame(height: 150)
            .background(Color(.secondarySystemBackground))
            .padding(.horizontal, 8)
            .transition(.move(edge: .top))
        }

        // Snooze section
        snoozeSection

        // Nag interval section (collapsible)
        nagIntervalSection
      }
    }
    .background(Color(.secondarySystemBackground))
    .scrollBounceBehavior(.basedOnSize)
    .frame(maxHeight: UIScreen.main.bounds.height * maxHeightRatio)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    .transition(.move(edge: .bottom))
    .animation(.easeInOut(duration: 0.3), value: showDatePicker)
    .animation(.easeInOut(duration: 0.3), value: showTimePicker)
    .animation(.easeInOut(duration: 0.3), value: showScheduleEditor)
    .animation(.easeInOut(duration: 0.3), value: showNagEditor)
  }

  // MARK: - Name Section

  private var nameSection: some View {
    VStack(spacing: 4) {
      HStack {
        TextField(String(localized: "Task name"), text: $taskName)
          .font(.system(size: 16, weight: .medium))
          .onChange(of: taskName) { _, new in
            if new.count > taskNameLimit {
              taskName = String(new.prefix(taskNameLimit))
            }
          }
        Text("\(taskName.count)/\(taskNameLimit)")
          .font(.system(size: 11))
          .foregroundStyle(
            taskName.count >= taskNameLimit ? .red : Color(.systemGray3))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(Color(.tertiarySystemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
  }

  // MARK: - Schedule Section

  private var scheduleSection: some View {
    VStack(spacing: 0) {
      // Summary row
      Button {
        showScheduleEditor.toggle()
        if showScheduleEditor {
          showDatePicker = false
          showTimePicker = false
          showNagEditor = false
        }
      } label: {
        HStack {
          Image(systemName: "repeat")
            .font(.system(size: 13))
            .foregroundStyle(Color(.systemGray))
          Text(scheduleType.displayName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color(.label))
          Spacer()
          Image(systemName: showScheduleEditor ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(.systemGray2))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
          showScheduleEditor ? Color.blue.opacity(0.08) : Color(.tertiarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 6)

      // Expanded editor
      if showScheduleEditor {
        VStack(spacing: 8) {
          // Schedule type picker
          Picker("", selection: $scheduleType) {
            ForEach(ScheduleTypeSelection.allCases) { type in
              Text(type.displayName).tag(type)
            }
          }
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)

          // Custom weekday selector
          if scheduleType == .customWeekdays {
            weekdaySelector
          }

          if scheduleType == .weekly {
            Picker(String(localized: "Day"), selection: $selectedWeekday) {
              ForEach(1...7, id: \.self) { day in
                Text(weekdayName(day)).tag(day)
              }
            }
            .pickerStyle(.menu)
          }

          if scheduleType == .monthly {
            Picker(String(localized: "Day of month"), selection: $selectedDay) {
              ForEach(1...31, id: \.self) { day in
                Text("Day \(day)").tag(day)
              }
            }
            .pickerStyle(.menu)
          }

          if scheduleType == .yearly {
            HStack {
              Picker(String(localized: "Month"), selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { month in
                  Text(monthName(month)).tag(month)
                }
              }
              .pickerStyle(.menu)
              Picker(String(localized: "Day"), selection: $selectedDay) {
                ForEach(1...31, id: \.self) { day in
                  Text("Day \(day)").tag(day)
                }
              }
              .pickerStyle(.menu)
            }
          }

          if scheduleType == .once {
            Toggle(String(localized: "Set due date"), isOn: $hasDueDate)
              .font(.system(size: 14))
            if hasDueDate {
              DatePicker(
                String(localized: "Due date"),
                selection: $dueDate,
                displayedComponents: [.date, .hourAndMinute]
              )
              .font(.system(size: 14))
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .transition(.move(edge: .top))
      }
    }
  }

  // MARK: - Weekday Selector

  private var weekdaySelector: some View {
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
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 32, height: 32)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundStyle(isSelected ? Color.white : Color(.label))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Date/Time Row

  private var dateTimeRow: some View {
    HStack(spacing: 8) {
      Button {
        showDatePicker.toggle()
        if showDatePicker {
          showTimePicker = false
          showScheduleEditor = false
          showNagEditor = false
        }
      } label: {
        Text(dateString)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(Color(.label))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(
            showDatePicker
              ? Color.blue.opacity(0.15) : Color(.tertiarySystemBackground)
          )
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }

      Button {
        showTimePicker.toggle()
        if showTimePicker {
          showDatePicker = false
          showScheduleEditor = false
          showNagEditor = false
        }
      } label: {
        Text(timeString)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(Color(.label))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(
            showTimePicker
              ? Color.blue.opacity(0.15) : Color(.tertiarySystemBackground)
          )
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }

      Spacer()
    }
  }

  // MARK: - Snooze Section

  private var snoozeSection: some View {
    VStack(spacing: 6) {
      HStack(spacing: 8) {
        snoozeButton(label: String(localized: "snooze.-10min"), duration: -10 * 60)
        snoozeButton(label: String(localized: "snooze.-30min"), duration: -30 * 60)
        snoozeButton(label: String(localized: "snooze.-1hr"), duration: -60 * 60)
      }
      HStack(spacing: 8) {
        snoozeButton(label: String(localized: "snooze.10min"), duration: 10 * 60)
        snoozeButton(label: String(localized: "snooze.30min"), duration: 30 * 60)
        snoozeButton(label: String(localized: "snooze.1hr"), duration: 60 * 60)
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 12)
  }

  private func snoozeButton(label: String, duration: TimeInterval) -> some View {
    let isNegative = duration < 0
    let color: Color = isNegative ? .orange : .blue
    return Button {
      editTime = editTime.addingTimeInterval(duration)
    } label: {
      Text(label)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
  }

  // MARK: - Nag Interval Section

  private var nagIntervalSection: some View {
    VStack(spacing: 0) {
      Button {
        showNagEditor.toggle()
        if showNagEditor {
          showDatePicker = false
          showTimePicker = false
          showScheduleEditor = false
        }
      } label: {
        HStack {
          Image(systemName: "bell.badge")
            .font(.system(size: 13))
            .foregroundStyle(Color(.systemGray))
          Text(String(localized: "Alert frequency"))
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color(.label))
          Text(nagSummary)
            .font(.system(size: 13))
            .foregroundStyle(Color(.systemGray))
          Spacer()
          Image(systemName: showNagEditor ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(.systemGray2))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
          showNagEditor ? Color.blue.opacity(0.08) : Color(.tertiarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .padding(.horizontal, 16)
      .padding(.top, 4)
      .padding(.bottom, showNagEditor ? 0 : 16)

      if showNagEditor {
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
        .background(Color(.secondarySystemBackground))
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .transition(.move(edge: .top))
      }
    }
  }

  // MARK: - Action Bar

  private var actionBar: some View {
    HStack(spacing: 48) {
      // Delete
      Button {
        showDeleteConfirm = true
      } label: {
        Image(systemName: "trash")
          .font(.system(size: 22))
          .foregroundStyle(Color(.systemGray))
          .frame(width: 52, height: 52)
          .background(Color(.secondarySystemBackground))
          .clipShape(Circle())
      }

      // Complete
      Button {
        taskManager.completeTask(task)
        dismissAnimated()
      } label: {
        Image(systemName: "checkmark")
          .font(.system(size: 22, weight: .medium))
          .foregroundStyle(Color(.systemGray))
          .frame(width: 52, height: 52)
          .background(Color(.secondarySystemBackground))
          .clipShape(Circle())
      }
    }
  }

  // MARK: - Dismiss Animation

  private func dismissAnimated() {
    if hasChanges && canSave { saveChanges() }
    withAnimation(.easeIn(duration: 0.25)) { dialogVisible = false }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { dismiss() }
  }

  // MARK: - Build Schedule

  private func buildSchedule() -> RepeatSchedule {
    let cal = Calendar.current
    let hour = cal.component(.hour, from: editTime)
    let minute = cal.component(.minute, from: editTime)
    let time = TimeOfDay(hour: hour, minute: minute)
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

  // MARK: - Save

  private func saveChanges() {
    let cal = Calendar.current
    let hour = cal.component(.hour, from: editTime)
    let minute = cal.component(.minute, from: editTime)
    let trimmedName = taskName.trimmingCharacters(in: .whitespaces)
    let schedule = buildSchedule()

    if case .once = schedule {
      // For one-time tasks: update dueDate directly
      let due: Date?
      if hasDueDate {
        due = dueDate
      } else {
        var comps = cal.dateComponents([.year, .month, .day], from: editDate)
        comps.hour = hour
        comps.minute = minute
        due = cal.date(from: comps)
      }
      taskManager.updateTask(
        task, name: trimmedName, schedule: .once,
        nagIntervalMinutes: nagIntervalMinutes, dueDate: due)
    } else {
      // For repeating tasks: update schedule + override date if changed
      taskManager.updateTask(
        task, name: trimmedName, schedule: schedule,
        nagIntervalMinutes: nagIntervalMinutes, dueDate: nil)

      // If user changed the date, set override
      let selectedStartOfDay = cal.startOfDay(for: editDate)
      let originalDay = cal.startOfDay(for: currentNextDate)
      if selectedStartOfDay != originalDay {
        var comps = cal.dateComponents([.year, .month, .day], from: editDate)
        comps.hour = hour
        comps.minute = minute
        if let overrideDate = cal.date(from: comps) {
          taskManager.overrideNextDate(for: task.id, date: overrideDate)
        }
      }
    }
  }

  // MARK: - Helpers

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
