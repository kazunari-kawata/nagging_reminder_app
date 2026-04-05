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
          // 1. 通知設定（UI描画をブロックしないよう先に実行）
          notificationDelegate.taskManager = taskManager
          UNUserNotificationCenter.current().delegate = notificationDelegate
          taskManager.requestNotificationPermission()

          // 2. レビュー促進セットアップ
          reviewManager.recordLaunch(settings: settings)
          taskManager.onTaskCompleted = { [settings, reviewManager] in
            settings.completedTaskCount += 1
            reviewManager.requestReviewIfAppropriate(settings: settings)
          }

          // 3. デモタスク挿入（初回のみ）
          if settings.tutorialCompleted {
            taskManager.insertDemoTasksIfNeeded()
          }

          // 4. AdMob 初期化（メインスレッドをブロックしないよう非同期で実行）
          await MobileAds.shared.start()
          interstitialAdManager.loadAd()
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
