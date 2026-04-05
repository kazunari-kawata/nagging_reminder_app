import GoogleMobileAds
import SwiftUI
import UserNotifications

@main
struct nagging_reminder_appApp: App {
  @State private var settings = AppSettings()
  @State private var taskManager = TaskManager()
  @State private var timerManager = TimerManager()
  @State private var notificationDelegate = NotificationDelegate()
  @State private var interstitialAdManager = InterstitialAdManager()
  @State private var purchaseManager = PurchaseManager()
  @State private var reviewManager = ReviewManager()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(settings)
        .environment(taskManager)
        .environment(timerManager)
        .environment(notificationDelegate)
        .environment(interstitialAdManager)
        .environment(purchaseManager)
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

          // 4. レビュー促進セットアップ
          reviewManager.recordLaunch(settings: settings)
          taskManager.onTaskCompleted = { [settings, reviewManager] in
            settings.completedTaskCount += 1
            reviewManager.requestReviewIfAppropriate(settings: settings)
          }

          // 5. デモタスク挿入（初回のみ）
          if settings.tutorialCompleted {
            taskManager.insertDemoTasksIfNeeded()
          }
        }.fullScreenCover(
          isPresented: .init(
            get: { !settings.privacyNoticeAccepted },
            set: { _ in }
          )
        ) {
          PrivacyNoticeView()
            .environment(settings)
        }
        .fullScreenCover(
          isPresented: .init(
            get: { settings.privacyNoticeAccepted && !settings.tutorialCompleted },
            set: { _ in }
          )
        ) {
          OnboardingView()
            .environment(settings)
            .onDisappear {
              taskManager.insertDemoTasksIfNeeded()
            }
        }
    }
  }
}
