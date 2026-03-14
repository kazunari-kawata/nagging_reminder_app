import SwiftUI
import UserNotifications
import GoogleMobileAds

@main
struct nagging_reminder_appApp: App {
  @State private var settings = AppSettings()
  @State private var taskManager = TaskManager()
  @State private var timerManager = TimerManager()
  @State private var notificationDelegate = NotificationDelegate()
  @State private var interstitialAdManager = InterstitialAdManager()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(settings)
        .environment(taskManager)
        .environment(timerManager)
        .environment(notificationDelegate)
        .environment(interstitialAdManager)
        .preferredColorScheme(settings.theme.colorScheme)
        .task {
          // 1. AdMob 初期化
          await MobileAds.shared.start()
          
          // 2. テストデバイス設定（今はまだIDが分からないのでコメントアウトしておく）
          // GADMobileAds.sharedInstance.requestConfiguration.testDeviceIdentifiers = [ "ここに後でIDを入れる" ]
          
          // 3. 通知設定
          notificationDelegate.taskManager = taskManager
          UNUserNotificationCenter.current().delegate = notificationDelegate
          taskManager.requestNotificationPermission()
        }.fullScreenCover(
          isPresented: .init(
            get: { !settings.privacyNoticeAccepted },
            set: { _ in }
          )
        ) {
          PrivacyNoticeView()
            .environment(settings)
        }
    }
  }
}
