import StoreKit
import SwiftUI

@Observable
final class ReviewManager {
  private let minimumCompletions = 5
  private let minimumLaunches = 10
  private let daysBetweenRequests = 120  // ~3 requests per year max

  func recordLaunch(settings: AppSettings) {
    settings.appLaunchCount += 1
  }

  func requestReviewIfAppropriate(settings: AppSettings) {
    guard settings.completedTaskCount >= minimumCompletions,
      settings.appLaunchCount >= minimumLaunches
    else { return }

    if let lastDate = settings.lastReviewRequestDate {
      let daysSince =
        Calendar.current.dateComponents(
          [.day], from: lastDate, to: Date()
        ).day ?? 0
      guard daysSince >= daysBetweenRequests else { return }
    }

    guard
      let windowScene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first
    else { return }

    AppStore.requestReview(in: windowScene)
    settings.lastReviewRequestDate = Date()
    settings.reviewRequestCount += 1
  }
}
