import Combine
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
  @Environment(TaskManager.self) private var taskManager
  @Environment(AppSettings.self) private var settings
  @Environment(TimerManager.self) private var timerManager
  @Environment(NotificationDelegate.self) private var notificationDelegate
  @Environment(InterstitialAdManager.self) private var interstitialAdManager
  @Environment(PurchaseManager.self) private var purchaseManager
  @Environment(\.scenePhase) private var scenePhase

  @State private var showAddTask = false
  @State private var showSettings = false
  @State private var editingTask: TaskItem?
  @State private var selectedTab = 0
  @State private var showAdFreePromo = false
  @State private var currentTime = Date()

  private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

  var body: some View {
    ZStack {
      Color(.systemBackground).ignoresSafeArea()

      VStack(spacing: 0) {
        if selectedTab == 0 {
          tasksPageView
        } else {
          TimerView()
            .environment(timerManager)
        }
        // if !purchaseManager.isAdFree {
        //   BannerAdContainer()
        // }
        bottomTabBar
      }
    }
    .sheet(isPresented: $showAddTask) {
      TaskFormView(mode: .add)
        .environment(taskManager)
        .environment(settings)
    }
    .sheet(isPresented: $showSettings) {
      SettingsView()
        .environment(settings)
        .environment(taskManager)
        .environment(purchaseManager)
    }
    .sheet(item: $editingTask) { task in
      TaskFormView(mode: .edit(task))
        .environment(taskManager)
        .environment(settings)
    }
    .sheet(isPresented: $showAdFreePromo) {
      AdFreeView()
        .environment(purchaseManager)
        .environment(settings)
    }
    .onChange(of: interstitialAdManager.shouldShowAdFreePrompt) { _, newValue in
      if newValue && !purchaseManager.isAdFree {
        showAdFreePromo = true
        interstitialAdManager.shouldShowAdFreePrompt = false
      }
    }
    .onChange(of: notificationDelegate.tappedTaskID) { _, newID in
      guard let id = newID else { return }
      editingTask = taskManager.tasks.first { $0.id == id }
      notificationDelegate.tappedTaskID = nil
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        currentTime = Date()
        taskManager.performMidnightResetIfNeeded()
      }
    }
    .onReceive(timer) { _ in
      currentTime = Date()
    }
    .preferredColorScheme(settings.theme.colorScheme)
  }

  // MARK: - Tasks Page

  private var tasksPageView: some View {
    VStack(spacing: 0) {
      headerSection
      taskListSection
    }
  }

  // MARK: - Header

  private var headerSection: some View {
    VStack(spacing: 0) {
      HStack {
        Image("HeaderIcon")
          .resizable()
          .scaledToFit()
          .frame(width: 44, height: 44)
          .clipShape(Circle())
          .padding(.trailing, 6)
        Text(LocalizedStringResource("tab.tasks"))
          .font(.largeTitle.bold())
          .tracking(-0.5)
        Spacer()
        Button {
          showSettings = true
        } label: {
          Image(systemName: "gearshape")
            .font(.system(size: 18))
            .foregroundStyle(.blue)
            .frame(width: 40, height: 40)
            .background(Color.blue.opacity(0.1))
            .clipShape(Circle())
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 12)
      .padding(.bottom, 16)

      Button {
        showAddTask = true
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 20))
          Text(LocalizedStringResource("button.add.task"))
            .font(.system(size: 16, weight: .semibold))
          Spacer()
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 16)
    }
    .background(Color(.systemBackground))
  }

  // MARK: - Task Sections

  private let cal = Calendar.current

  private func isOverdue(_ task: TaskItem) -> Bool {
    guard let tod = task.repeatSchedule.timeOfDay else { return false }
    let taskTime = cal.date(
      bySettingHour: tod.hour, minute: tod.minute, second: 0, of: currentTime)!
    return currentTime > taskTime
  }

  private var overdueTasksToday: [TaskItem] {
    taskManager.tasks.filter {
      taskManager.isApplicableToday($0) && !$0.isCompleted && isOverdue($0)
    }
  }

  private var upcomingTasksToday: [TaskItem] {
    taskManager.tasks.filter {
      taskManager.isApplicableToday($0) && !$0.isCompleted && !isOverdue($0)
    }
  }

  /// Tasks NOT applicable today (excludes completed-today tasks).
  private var notTodayTasks: [TaskItem] {
    taskManager.tasks.filter { !taskManager.isApplicableToday($0) }
  }

  /// Tasks with next occurrence tomorrow.
  private var tomorrowTasks: [TaskItem] {
    notTodayTasks.filter { task in
      guard let next = taskManager.nextOccurrenceDate(for: task) else { return false }
      return cal.isDateInTomorrow(next)
    }
  }

  /// Tasks with next occurrence 2–7 days from now, sorted by date.
  private var thisWeekTasks: [TaskItem] {
    let start = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: currentTime))!
    let end = cal.date(byAdding: .day, value: 8, to: cal.startOfDay(for: currentTime))!
    return notTodayTasks.filter { task in
      guard let next = taskManager.nextOccurrenceDate(for: task) else { return false }
      return next >= start && next < end
    }.sorted {
      (taskManager.nextOccurrenceDate(for: $0) ?? .distantFuture)
        < (taskManager.nextOccurrenceDate(for: $1) ?? .distantFuture)
    }
  }

  /// Tasks 8+ days away (sorted) + completed-today tasks.
  private var laterTasks: [TaskItem] {
    let cutoff = cal.date(byAdding: .day, value: 8, to: cal.startOfDay(for: currentTime))!
    let completedToday = taskManager.tasks.filter {
      taskManager.isApplicableToday($0) && $0.isCompleted
    }
    let later = notTodayTasks.filter { task in
      guard let next = taskManager.nextOccurrenceDate(for: task) else { return true }
      return next >= cutoff
    }.sorted {
      (taskManager.nextOccurrenceDate(for: $0) ?? .distantFuture)
        < (taskManager.nextOccurrenceDate(for: $1) ?? .distantFuture)
    }
    return completedToday + later
  }

  private var taskListSection: some View {
    ScrollView {
      LazyVStack(spacing: 12) {

        // OVERDUE
        if !overdueTasksToday.isEmpty {
          sectionHeader(String(localized: "OVERDUE"), accent: .red)
          ForEach(overdueTasksToday) { task in
            taskCard(task, badge: task.repeatSchedule.shortLabel)
          }
        }

        // TODAY
        if !upcomingTasksToday.isEmpty || overdueTasksToday.isEmpty {
          sectionHeader(String(localized: "TODAY"), accent: .blue).padding(.top, overdueTasksToday.isEmpty ? 0 : 8)
          if upcomingTasksToday.isEmpty {
            Text(LocalizedStringResource("message.all.done"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.leading, 4)
              .padding(.bottom, 4)
          } else {
            ForEach(upcomingTasksToday) { task in
              taskCard(task, badge: task.repeatSchedule.shortLabel)
            }
          }
        }

        // TOMORROW
        if !tomorrowTasks.isEmpty {
          sectionHeader(String(localized: "TOMORROW")).padding(.top, 8)
          ForEach(tomorrowTasks) { task in
            taskCard(task, badge: String(localized: "TOMORROW"))
          }
        }

        // THIS WEEK
        if !thisWeekTasks.isEmpty {
          sectionHeader(String(localized: "THIS WEEK")).padding(.top, 8)
          ForEach(thisWeekTasks) { task in
            taskCard(task, badge: dateLabel(for: task))
          }
        }

        // LATER
        if !laterTasks.isEmpty {
          sectionHeader(String(localized: "LATER"), accent: Color(.systemGray)).padding(.top, 8)
          ForEach(laterTasks) { task in
            taskCard(
              task, badge: task.isCompleted ? String(localized: "DONE") : dateLabel(for: task))
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 16)
      .padding(.bottom, 100)
    }
  }

  private func taskCard(_ task: TaskItem, badge: String) -> some View {
    TaskCardView(
      task: task,
      badgeLabel: badge,
      onComplete: {
        taskManager.completeTask(task)
        if !purchaseManager.isAdFree { interstitialAdManager.showIfReady() }
      },
      onDelete: { taskManager.deleteTask(id: task.id) },
      onEdit: { editingTask = task }
    )
    .id("\(task.id)_\(task.repeatSchedule.hashValue)_\(task.isCompleted)")
  }

  private func sectionHeader(_ title: String, accent: Color? = nil) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(accent ?? Color(.systemGray))
        .tracking(1)
        .padding(.horizontal, accent != nil ? 8 : 0)
        .padding(.vertical, accent != nil ? 3 : 0)
        .background(
          accent.map { $0.opacity(0.12) }
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
      Spacer()
    }
    .padding(.leading, 4)
    .padding(.bottom, 4)
  }

  /// Badge label showing the next occurrence date.
  /// ja: "5月10日（日）", ko: "5월10일（일）", others: "WED 12 MAR"
  private func dateLabel(for task: TaskItem) -> String {
    guard let next = taskManager.nextOccurrenceDate(for: task) else {
      return task.repeatSchedule.shortLabel
    }
    let fmt = DateFormatter()
    let langCode = Locale.current.language.languageCode?.identifier ?? ""
    switch langCode {
    case "ja":
      fmt.locale = Locale(identifier: "ja_JP")
      fmt.dateFormat = "M月d日（E）"
    case "ko":
      fmt.locale = Locale(identifier: "ko_KR")
      fmt.dateFormat = "M월d일（E）"
    default:
      fmt.dateFormat = "EEE d MMM"
      return fmt.string(from: next).uppercased()
    }
    return fmt.string(from: next)
  }

  // MARK: - Bottom Tab Bar

  private var bottomTabBar: some View {
    HStack {
      Spacer()
      tabBarItem(
        icon: "list.bullet.rectangle", label: String(localized: "tab.tasks"), index: 0, filled: true
      )
      Spacer()
      tabBarItem(icon: "timer", label: String(localized: "tab.timer"), index: 1)
      Spacer()
    }
    .padding(.horizontal, 32)
    .padding(.top, 24)
    .background(
      Color(.systemBackground)
        .ignoresSafeArea()
        .opacity(0.8)
        .background(.ultraThinMaterial)
    )
  }

  private func tabBarItem(icon: String, label: String, index: Int, filled: Bool = false)
    -> some View
  {
    Button {
      selectedTab = index
    } label: {
      VStack(spacing: 4) {
        Image(systemName: selectedTab == index && filled ? "\(icon).fill" : icon)
          .font(.system(size: 22))
        Text(label)
          .font(.system(size: 10, weight: .medium))
      }
      .foregroundStyle(selectedTab == index ? .blue : Color(.systemGray))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - TaskCardView

struct TaskCardView: View {
  let task: TaskItem
  let badgeLabel: String
  let onComplete: () -> Void
  let onDelete: () -> Void
  let onEdit: () -> Void

  @State private var dragOffset: CGFloat = 0
  @State private var cardWidth: CGFloat = 320
  @State private var triggeredLight = false
  @State private var triggeredHeavy = false

  /// 15% of card width — swipe past to mark complete.
  private var completeThreshold: CGFloat { cardWidth * 0.15 }
  /// 70% of card width — swipe past to delete.
  private var deleteThreshold: CGFloat { cardWidth * 0.70 }

  private var scheduleSubtitle: String {
    if case .once = task.repeatSchedule {
      if let due = task.dueDate {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: due)
      }
      return String(localized: "One-time")
    }
    return task.repeatSchedule.detailedLabel
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      // Reveal background
      if dragOffset < -(completeThreshold * 0.4) {
        RoundedRectangle(cornerRadius: 16)
          .fill(dragOffset < -deleteThreshold ? Color.red : Color.green)
        HStack {
          Spacer()
          Image(systemName: dragOffset < -deleteThreshold ? "trash" : "checkmark")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .padding(.trailing, 24)
        }
      }

      cardContent
        .offset(x: dragOffset)
        .gesture(
          DragGesture()
            .onChanged { value in
              guard value.translation.width < 0 else { return }
              dragOffset = value.translation.width

              if dragOffset < -completeThreshold && !triggeredLight {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                triggeredLight = true
                triggeredHeavy = false
              }
              if dragOffset < -deleteThreshold && !triggeredHeavy {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                triggeredHeavy = true
              }
              if dragOffset > -completeThreshold {
                triggeredLight = false
                triggeredHeavy = false
              }
            }
            .onEnded { value in
              let t = value.translation.width
              if t < -deleteThreshold {
                withAnimation(.easeOut(duration: 0.25)) { dragOffset = -500 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onDelete() }
              } else if t < -completeThreshold {
                withAnimation(.spring()) { dragOffset = 0 }
                onComplete()
              } else {
                withAnimation(.spring()) { dragOffset = 0 }
              }
              triggeredLight = false
              triggeredHeavy = false
            }
        )
        .onTapGesture { onEdit() }
    }
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .background(
      GeometryReader { geo in
        Color.clear.onAppear { cardWidth = geo.size.width }
      }
    )
    .contextMenu {
      if !task.isCompleted {
        Button {
          onComplete()
        } label: {
          Label("Mark Complete", systemImage: "checkmark.circle")
        }
      }
      Button {
        onEdit()
      } label: {
        Label("Edit", systemImage: "pencil")
      }
      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  private var cardContent: some View {
    HStack(spacing: 12) {
      // Task name + schedule subtitle
      VStack(alignment: .leading, spacing: 3) {
        Text(task.name)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(task.isCompleted ? Color(.systemGray3) : Color(.label))

        Text(scheduleSubtitle)
          .font(.system(size: 12))
          .foregroundStyle(task.isCompleted ? Color(.systemGray4) : Color(.systemGray))
      }

      Spacer()

      // Badge
      Text(badgeLabel)
        .font(.system(size: 10, weight: .bold))
        .tracking(0.5)
        .foregroundStyle(badgeForeground)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(badgeBackground)
        .clipShape(Capsule())
    }
    .padding(16)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color(.systemGray5), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    .opacity(task.isCompleted ? 0.65 : 1.0)
  }

  private var badgeForeground: Color {
    if badgeLabel == "DONE" { return Color.green }
    if task.isCompleted { return Color(.systemGray) }
    return task.repeatSchedule.isRepeating ? .blue : Color(.systemGray)
  }

  private var badgeBackground: Color {
    if badgeLabel == "DONE" { return Color.green.opacity(0.12) }
    if task.isCompleted { return Color(.systemGray6) }
    return task.repeatSchedule.isRepeating ? Color.blue.opacity(0.1) : Color(.systemGray6)
  }
}

#Preview {
  ContentView()
    .environment(TaskManager())
    .environment(AppSettings())
    .environment(TimerManager())
    .environment(NotificationDelegate())
    .environment(InterstitialAdManager())
    .environment(PurchaseManager())
}
