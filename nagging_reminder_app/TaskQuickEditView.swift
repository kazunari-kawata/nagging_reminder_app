import SwiftUI

// MARK: - TaskQuickEditView

/// Compact dialog-style task view shown when tapping a task card or notification.
/// Displays task info with snooze options and action buttons.
struct TaskQuickEditView: View {
  @Environment(TaskManager.self) private var taskManager
  @Environment(\.dismiss) private var dismiss

  let task: TaskItem
  var onDelete: (() -> Void)?

  @State private var editDate: Date
  @State private var editTime: Date
  @State private var showDatePicker = false
  @State private var showTimePicker = false
  @State private var showFullEdit = false
  @State private var showDeleteConfirm = false

  init(task: TaskItem, onDelete: (() -> Void)? = nil) {
    self.task = task
    self.onDelete = onDelete

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
  }

  // MARK: - Computed: next occurrence from TaskManager

  /// The calculated next occurrence date for this task (used as initial calendar value).
  private var currentNextDate: Date {
    taskManager.nextOccurrenceDate(for: task) ?? Date()
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

  // MARK: - Body

  var body: some View {
    ZStack {
      Color.black.opacity(0.5)
        .ignoresSafeArea()
        .onTapGesture { dismiss() }

      VStack(spacing: 0) {
        dialogContent
        Spacer().frame(height: 40)
        actionBar
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 24)
    }
    .sheet(isPresented: $showFullEdit) {
      TaskFormView(mode: .edit(task))
        .environment(taskManager)
    }
    .alert(
      String(localized: "task.delete.alert.title"),
      isPresented: $showDeleteConfirm
    ) {
      Button(String(localized: "Delete"), role: .destructive) {
        onDelete?()
        dismiss()
      }
      Button(String(localized: "Cancel"), role: .cancel) {}
    }
    .onAppear {
      // Set initial date from calculated next occurrence
      editDate = currentNextDate
    }
  }

  // MARK: - Dialog Content

  private var dialogContent: some View {
    VStack(spacing: 0) {
      // Close button + date/time row + save
      HStack(spacing: 12) {
        Button { dismiss() } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(Color(.systemGray))
        }

        dateTimeRow

        Spacer()

        Button(String(localized: "task.quickedit.save")) {
          saveChanges()
          dismiss()
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Color(.systemGray2))
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 12)

      // Schedule info
      Text(task.repeatSchedule.detailedLabel)
        .font(.system(size: 14))
        .foregroundStyle(Color(.systemGray))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)

      // Snooze section
      snoozeSection

      // Date picker (expandable) — calendar for all types
      if showDatePicker {
        DatePicker(
          "",
          selection: $editDate,
          displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .padding(.horizontal, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }

      // Time picker (expandable)
      if showTimePicker {
        DatePicker(
          "",
          selection: $editTime,
          displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.wheel)
        .frame(height: 150)
        .padding(.horizontal, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    .animation(.easeInOut(duration: 0.25), value: showDatePicker)
    .animation(.easeInOut(duration: 0.25), value: showTimePicker)
  }

  // MARK: - Date/Time Row

  private var dateTimeRow: some View {
    HStack(spacing: 8) {
      Button {
        showDatePicker.toggle()
        if showDatePicker { showTimePicker = false }
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
        if showTimePicker { showDatePicker = false }
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
    }
  }

  // MARK: - Snooze Section

  private var snoozeSection: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        snoozeButton(
          label: String(localized: "snooze.10min"), icon: "bell.and.waves.left.and.right",
          duration: 10 * 60)
        snoozeButton(
          label: String(localized: "snooze.30min"), icon: "bell.and.waves.left.and.right",
          duration: 30 * 60)
        snoozeButton(
          label: String(localized: "snooze.1hr"), icon: "bell.and.waves.left.and.right",
          duration: 60 * 60)
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
  }

  private func snoozeButton(label: String, icon: String, duration: TimeInterval) -> some View {
    Button {
      taskManager.snoozeTask(id: task.id, duration: duration)
      dismiss()
    } label: {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 14))
        Text(label)
          .font(.system(size: 11, weight: .medium))
      }
      .foregroundStyle(.blue)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(Color.blue.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
  }

  // MARK: - Action Bar

  private var actionBar: some View {
    HStack(spacing: 32) {
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

      // Full edit
      Button {
        showFullEdit = true
      } label: {
        Image(systemName: "square.and.pencil")
          .font(.system(size: 22))
          .foregroundStyle(Color(.systemGray))
          .frame(width: 52, height: 52)
          .background(Color(.secondarySystemBackground))
          .clipShape(Circle())
      }

      // Complete
      Button {
        taskManager.completeTask(task)
        dismiss()
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

  // MARK: - Save

  private func saveChanges() {
    let cal = Calendar.current
    let hour = cal.component(.hour, from: editTime)
    let minute = cal.component(.minute, from: editTime)
    let newTime = TimeOfDay(hour: hour, minute: minute)

    if case .once = task.repeatSchedule {
      // For one-time tasks: update dueDate directly
      var comps = cal.dateComponents([.year, .month, .day], from: editDate)
      comps.hour = hour
      comps.minute = minute
      let due = cal.date(from: comps)
      taskManager.updateTask(
        task, name: task.name, schedule: .once,
        nagIntervalMinutes: task.nagIntervalMinutes, dueDate: due)
    } else {
      // For repeating tasks: update time in schedule + override date if changed
      let newSchedule: RepeatSchedule
      switch task.repeatSchedule {
      case .once:
        newSchedule = .once
      case .daily:
        newSchedule = .daily(time: newTime)
      case .weekdays:
        newSchedule = .weekdays(time: newTime)
      case .selectedWeekdays(let weekdays, _):
        newSchedule = .selectedWeekdays(weekdays: weekdays, time: newTime)
      case .weekly(let weekday, _):
        newSchedule = .weekly(weekday: weekday, time: newTime)
      case .monthly(let day, _):
        newSchedule = .monthly(day: day, time: newTime)
      case .yearly(let month, let day, _):
        newSchedule = .yearly(month: month, day: day, time: newTime)
      }

      // Update schedule (time change)
      taskManager.updateTask(
        task, name: task.name, schedule: newSchedule,
        nagIntervalMinutes: task.nagIntervalMinutes, dueDate: nil)

      // If user changed the date, set override to move task to the chosen date
      let selectedDay = cal.startOfDay(for: editDate)
      let originalDay = cal.startOfDay(for: currentNextDate)
      if selectedDay != originalDay {
        // Combine selected date with edited time
        var comps = cal.dateComponents([.year, .month, .day], from: editDate)
        comps.hour = hour
        comps.minute = minute
        if let overrideDate = cal.date(from: comps) {
          taskManager.overrideNextDate(for: task.id, date: overrideDate)
        }
      }
    }
  }
}
