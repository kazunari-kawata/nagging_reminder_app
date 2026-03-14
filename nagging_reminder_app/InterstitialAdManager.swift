import GoogleMobileAds
import SwiftUI

@Observable
final class InterstitialAdManager: NSObject {
  private let adUnitID = "ca-app-pub-6204247576058151/4096927871"
  private let intervalSeconds: TimeInterval = 2 * 60 * 60  // 2時間

  private var interstitialAd: InterstitialAd?
  private(set) var isAdReady = false

  /// Last time an interstitial was shown (persisted across app launches).
  private var lastShownDate: Date? {
    get { UserDefaults.standard.object(forKey: "interstitialLastShown") as? Date }
    set { UserDefaults.standard.set(newValue, forKey: "interstitialLastShown") }
  }

  override init() {
    super.init()
    loadAd()
  }

  // MARK: - Load

  func loadAd() {
    InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
      guard let self else { return }
      if let error {
        print("[AdMob] Interstitial load failed: \(error.localizedDescription)")
        self.isAdReady = false
        return
      }
      print("[AdMob] Interstitial loaded")
      self.interstitialAd = ad
      self.interstitialAd?.fullScreenContentDelegate = self
      self.isAdReady = true
    }
  }

  // MARK: - Show

  /// Returns true if the 2-hour cooldown has elapsed.
  var canShow: Bool {
    guard let last = lastShownDate else { return true }
    return Date().timeIntervalSince(last) >= intervalSeconds
  }

  /// Attempts to show the interstitial ad. Returns false if not ready or cooldown hasn't elapsed.
  @discardableResult
  func showIfReady() -> Bool {
    guard canShow, isAdReady, let ad = interstitialAd else { return false }
    guard
      let rootVC = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?
        .rootViewController
    else { return false }

    // Find the topmost presented VC
    var topVC = rootVC
    while let presented = topVC.presentedViewController {
      topVC = presented
    }

    ad.present(from: topVC)
    return true
  }
}

// MARK: - FullScreenContentDelegate

extension InterstitialAdManager: FullScreenContentDelegate {
  nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      print("[AdMob] Interstitial dismissed")
      lastShownDate = Date()
      isAdReady = false
      loadAd()  // preload next ad
    }
  }

  nonisolated func ad(
    _ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error
  ) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      print("[AdMob] Interstitial present failed: \(error.localizedDescription)")
      isAdReady = false
      loadAd()
    }
  }

  nonisolated func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
    print("[AdMob] Interstitial will present")
  }
}
