import GoogleMobileAds
import SwiftUI
import UserNotifications

@main
struct nagging_reminder_appApp: App {
  init() {
    MobileAds.shared.start()
  }

  @State private var settings = AppSettings()
  @State private var taskManager = TaskManager()
  @State private var timerManager = TimerManager()
  @State private var interstitialAdManager = InterstitialAdManager()
  @State private var notificationDelegate = NotificationDelegate()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(settings)
        .environment(taskManager)
        .environment(timerManager)
        .environment(interstitialAdManager)
        .preferredColorScheme(settings.theme.colorScheme)
        .task {
          notificationDelegate.taskManager = taskManager
          UNUserNotificationCenter.current().delegate = notificationDelegate
          taskManager.requestNotificationPermission()
        }
    }
  }
}
