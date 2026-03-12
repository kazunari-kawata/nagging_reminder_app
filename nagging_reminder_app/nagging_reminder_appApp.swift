import SwiftUI
import UserNotifications

@main
struct nagging_reminder_appApp: App {
    @State private var settings = AppSettings()
    @State private var taskManager = TaskManager()
    @State private var timerManager = TimerManager()
    @State private var notificationDelegate = NotificationDelegate()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(taskManager)
                .environment(timerManager)
                .preferredColorScheme(settings.theme.colorScheme)
                .task {
                    notificationDelegate.taskManager = taskManager
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                    taskManager.requestNotificationPermission()
                }
        }
    }
}
