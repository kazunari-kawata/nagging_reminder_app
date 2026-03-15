import GoogleMobileAds
import SwiftUI

// MARK: - BannerAdView

struct BannerAdView: UIViewControllerRepresentable {
  #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/2934735716"  // Google公式テスト用バナーID
  #else
    private let adUnitID = "ca-app-pub-6204247576058151/4942271536"
  #endif

  func makeUIViewController(context: Context) -> BannerAdViewController {
    let vc = BannerAdViewController()
    vc.adUnitID = adUnitID
    return vc
  }

  func updateUIViewController(_ uiViewController: BannerAdViewController, context: Context) {}
}

// MARK: - BannerAdViewController

final class BannerAdViewController: UIViewController {
  var adUnitID: String?
  private var bannerView: BannerView?
  private var hasLoaded = false

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard !hasLoaded, view.bounds.width > 0 else { return }
    hasLoaded = true
    loadBanner()
  }

  private func loadBanner() {
    let banner = BannerView()
    banner.adUnitID = adUnitID
    banner.rootViewController = self
    banner.delegate = self
    banner.translatesAutoresizingMaskIntoConstraints = false

    let adWidth =
      view.frame.width > 0
      ? view.frame.width
      : (view.window?.windowScene?.screen.bounds.width ?? 375)
    banner.adSize = largeAnchoredAdaptiveBanner(width: adWidth)

    view.addSubview(banner)
    NSLayoutConstraint.activate([
      banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      banner.topAnchor.constraint(equalTo: view.topAnchor),
      banner.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    print("[AdMob] Loading banner ad with unit ID: \(adUnitID ?? "nil")")
    banner.load(Request())
    bannerView = banner
  }
}

// MARK: - BannerViewDelegate

extension BannerAdViewController: BannerViewDelegate {
  func bannerViewDidReceiveAd(_ bannerView: BannerView) {
    print("[AdMob] Banner loaded successfully")
  }

  func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
    let nsError = error as NSError
    print(
      "[AdMob] Banner failed – code: \(nsError.code), domain: \(nsError.domain), message: \(nsError.localizedDescription)"
    )
  }
}

// MARK: - BannerAdContainer

struct BannerAdContainer: View {
  var body: some View {
    BannerAdView()
      .frame(maxWidth: .infinity)
      .frame(height: 50)
  }
}
