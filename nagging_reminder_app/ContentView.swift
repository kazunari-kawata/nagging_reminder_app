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
  @State private var undoTask: TaskItem?
  @State private var showUndo = false
  @State private var undoWorkItem: DispatchWorkItem?

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

      if showUndo {
        undoSnackbar
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
          .padding(.bottom, 90)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showUndo)
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
    .fullScreenCover(item: $editingTask) { task in
      TaskQuickEditView(
        task: task,
        onDelete: {
          let snapshot = task
          taskManager.deleteTask(id: task.id)
          undoTask = snapshot
          undoWorkItem?.cancel()
          withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showUndo = true }
          let work = DispatchWorkItem {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showUndo = false }
            undoTask = nil
          }
          undoWorkItem = work
          DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
        }
      )
      .environment(taskManager)
      .presentationBackground(.clear)
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
          .frame(width: 36, height: 36)
          .clipShape(Circle())
          .padding(.trailing, 6)
        Text(LocalizedStringResource("tab.tasks"))
          .font(.title.bold())
          .tracking(-0.5)
        Spacer()
        Button {
          showAddTask = true
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.blue)
            .frame(width: 40, height: 40)
            .background(Color.blue.opacity(0.1))
            .clipShape(Circle())
        }
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
      .padding(.top, 8)
      .padding(.bottom, 10)
    }
    .background(Color(.systemBackground))
  }

  // MARK: - Task Sections

  private let cal = Calendar.current

  /// Deduplicated task list — keeps the first occurrence for each (name, schedule) pair.
  private var uniqueTasks: [TaskItem] {
    var seen = Set<Int>()
    return taskManager.tasks.filter { task in
      var hasher = Hasher()
      hasher.combine(task.name)
      hasher.combine(task.repeatSchedule)
      let key = hasher.finalize()
      return seen.insert(key).inserted
    }
  }

  private func isOverdue(_ task: TaskItem) -> Bool {
    guard let tod = task.repeatSchedule.timeOfDay else { return false }
    let taskTime = cal.date(
      bySettingHour: tod.hour, minute: tod.minute, second: 0, of: currentTime)!
    return currentTime > taskTime
  }

  private var overdueTasksToday: [TaskItem] {
    uniqueTasks.filter {
      taskManager.isApplicableToday($0) && !$0.isCompleted && isOverdue($0)
    }
  }

  private var upcomingTasksToday: [TaskItem] {
    uniqueTasks.filter {
      taskManager.isApplicableToday($0) && !$0.isCompleted && !isOverdue($0)
    }
  }

  /// Tasks NOT applicable today, plus completed repeating tasks (whose next occurrence is tomorrow or later).
  private var notTodayTasks: [TaskItem] {
    uniqueTasks.filter { task in
      !taskManager.isApplicableToday(task)
        || (task.isCompleted && task.repeatSchedule.isRepeating)
    }
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

  /// Tasks 8+ days away (sorted).
  private var laterTasks: [TaskItem] {
    let cutoff = cal.date(byAdding: .day, value: 8, to: cal.startOfDay(for: currentTime))!
    return notTodayTasks.filter { task in
      guard let next = taskManager.nextOccurrenceDate(for: task) else { return true }
      return next >= cutoff
    }.sorted {
      (taskManager.nextOccurrenceDate(for: $0) ?? .distantFuture)
        < (taskManager.nextOccurrenceDate(for: $1) ?? .distantFuture)
    }
  }

  private var taskListSection: some View {
    ScrollView {
      LazyVStack(spacing: 8) {

        // OVERDUE
        if !overdueTasksToday.isEmpty {
          sectionHeader(String(localized: "OVERDUE"), accent: .red)
          ForEach(overdueTasksToday) { task in
            taskCard(task)
          }
        }

        // TODAY
        if !upcomingTasksToday.isEmpty || overdueTasksToday.isEmpty {
          sectionHeader(String(localized: "TODAY"), accent: .blue).padding(
            .top, overdueTasksToday.isEmpty ? 0 : 4)
          if upcomingTasksToday.isEmpty {
            Text(LocalizedStringResource("message.all.done"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.leading, 4)
              .padding(.bottom, 4)
          } else {
            ForEach(upcomingTasksToday) { task in
              taskCard(task)
            }
          }
        }

        // TOMORROW
        if !tomorrowTasks.isEmpty {
          sectionHeader(String(localized: "TOMORROW")).padding(.top, 4)
          ForEach(tomorrowTasks) { task in
            taskCard(task)
          }
        }

        // THIS WEEK
        if !thisWeekTasks.isEmpty {
          sectionHeader(String(localized: "THIS WEEK")).padding(.top, 4)
          ForEach(thisWeekTasks) { task in
            taskCard(task)
          }
        }

        // LATER
        if !laterTasks.isEmpty {
          sectionHeader(String(localized: "LATER"), accent: Color(.systemGray)).padding(.top, 4)
          ForEach(laterTasks) { task in
            taskCard(task)
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 8)
      .padding(.bottom, 80)
    }
  }

  private func taskCard(_ task: TaskItem) -> some View {
    TaskCardView(
      task: task,
      onComplete: {
        taskManager.completeTask(task)
        if !purchaseManager.isAdFree { interstitialAdManager.showIfReady() }
      },
      onDelete: {
        let snapshot = task
        taskManager.deleteTask(id: task.id)
        undoTask = snapshot
        undoWorkItem?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showUndo = true }
        let work = DispatchWorkItem {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showUndo = false }
          undoTask = nil
        }
        undoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
      },
      onEdit: { editingTask = task },
      onDuplicate: { taskManager.duplicateTask(task) }
    )
    .id("\(task.id)_\(task.repeatSchedule.hashValue)_\(task.isCompleted)")
  }

  private var undoSnackbar: some View {
    HStack(spacing: 12) {
      Text(undoTask?.name ?? "")
        .font(.subheadline)
        .foregroundStyle(Color(.label))
        .lineLimit(1)
      Spacer()
      Button(String(localized: "task.delete.undo.button")) {
        undoWorkItem?.cancel()
        undoWorkItem = nil
        if let task = undoTask { taskManager.restoreTask(task) }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showUndo = false }
        undoTask = nil
      }
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.blue)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    .padding(.horizontal, 16)
  }

  private func sectionHeader(_ title: String, accent: Color? = nil) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(accent ?? Color(.systemGray))
        .tracking(1)
        .padding(.horizontal, accent != nil ? 8 : 0)
        .padding(.vertical, accent != nil ? 3 : 0)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill((accent ?? .clear).opacity(0.12))
        )
      Spacer()
    }
    .padding(.leading, 2)
    .padding(.bottom, 2)
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
    .padding(.top, 14)
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
  let onComplete: () -> Void
  let onDelete: () -> Void
  let onEdit: () -> Void
  let onDuplicate: () -> Void

  @State private var dragOffset: CGFloat = 0
  @State private var cardWidth: CGFloat = 320
  @State private var triggeredLight = false
  @State private var triggeredHeavy = false
  @State private var showDeleteConfirm = false
  @State private var dragDirection: DragDirection = .undecided

  private enum DragDirection { case undecided, horizontal, vertical }

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
        .simultaneousGesture(
          DragGesture(minimumDistance: 20)
            .onChanged { value in
              // Lock direction on initial move
              if dragDirection == .undecided {
                if abs(value.translation.width) > abs(value.translation.height) {
                  dragDirection = .horizontal
                } else {
                  dragDirection = .vertical
                }
              }
              guard dragDirection == .horizontal, value.translation.width < 0 else { return }
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
              if dragDirection == .horizontal && t < -deleteThreshold {
                withAnimation(.spring()) { dragOffset = 0 }
                showDeleteConfirm = true
              } else if dragDirection == .horizontal && t < -completeThreshold {
                withAnimation(.spring()) { dragOffset = 0 }
                onComplete()
              } else {
                withAnimation(.spring()) { dragOffset = 0 }
              }
              triggeredLight = false
              triggeredHeavy = false
              dragDirection = .undecided
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
      Button {
        onDuplicate()
      } label: {
        Label(String(localized: "task.duplicate"), systemImage: "doc.on.doc")
      }
      Button(role: .destructive) {
        showDeleteConfirm = true
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
    .alert(
      String(localized: "task.delete.alert.title"),
      isPresented: $showDeleteConfirm
    ) {
      Button(String(localized: "Delete"), role: .destructive) { onDelete() }
      Button(String(localized: "Cancel"), role: .cancel) {}
    }
  }

  private var cardContent: some View {
    HStack(spacing: 12) {
      Text(task.name)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Color(.label))
        .lineLimit(1)

      Spacer()

      Text(scheduleSubtitle)
        .font(.system(size: 12))
        .foregroundStyle(Color(.systemGray))
        .lineLimit(1)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color(.systemGray5), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
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
