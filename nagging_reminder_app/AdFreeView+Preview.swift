import SwiftUI

#if DEBUG

  // MARK: - Preview Tests

  #Preview("Purchased State") {
    @Previewable @State var purchaseManager = PurchaseManager()
    let _ = purchaseManager.configureForPreview(isAdFree: true)

    AdFreeView()
      .environment(purchaseManager)
      .environment(AppSettings())
  }

  #Preview("Loading State - Product Not Loaded") {
    @Previewable @State var purchaseManager = PurchaseManager()
    let _ = purchaseManager.configureForPreview(isAdFree: false)

    AdFreeView()
      .environment(purchaseManager)
      .environment(AppSettings())
  }

  #Preview("Storefront - Product Available") {
    @Previewable @State var purchaseManager = PurchaseManager()
    // NOTE: Product initializer is private; the view displays the product when loaded on device/simulator
    // Loading state is identical here (product fetching is asynchronous)

    AdFreeView()
      .environment(purchaseManager)
      .environment(AppSettings())
  }

  #Preview("Purchasing - In Progress") {
    @Previewable @State var purchaseManager = PurchaseManager()
    let _ = purchaseManager.configureForPreview(isPurchasing: true)

    AdFreeView()
      .environment(purchaseManager)
      .environment(AppSettings())
  }

  #Preview("Error State - Purchase Failed") {
    @Previewable @State var purchaseManager = PurchaseManager()
    let _ = purchaseManager.configureForPreview(
      currentError: .purchaseFailed(reason: "Network connection failed"))

    AdFreeView()
      .environment(purchaseManager)
      .environment(AppSettings())
  }

  #Preview("Error State - Invalid Product ID") {
    @Previewable @State var purchaseManager = PurchaseManager()
    let _ = purchaseManager.configureForPreview(currentError: .invalidProductID)

    AdFreeView()
      .environment(purchaseManager)
      .environment(AppSettings())
  }

  #Preview("Error State - Verification Failed") {
    @Previewable @State var purchaseManager = PurchaseManager()
    let _ = purchaseManager.configureForPreview(currentError: .verificationFailed)

    AdFreeView()
      .environment(purchaseManager)
      .environment(AppSettings())
  }

  #Preview("Error State - Family Sharing Pending") {
    @Previewable @State var purchaseManager = PurchaseManager()
    let _ = purchaseManager.configureForPreview(currentError: .purchasePending)

    AdFreeView()
      .environment(purchaseManager)
      .environment(AppSettings())
  }

  #Preview("Dark Mode - Purchased") {
    @Previewable @State var purchaseManager = PurchaseManager()
    @Previewable @State var settings = AppSettings()
    let _ = purchaseManager.configureForPreview(isAdFree: true)

    AdFreeView()
      .environment(purchaseManager)
      .environment(settings)
      .preferredColorScheme(.dark)
  }

#endif
