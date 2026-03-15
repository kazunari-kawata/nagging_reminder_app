import StoreKit
import SwiftUI
import os

// MARK: - PurchaseConfig

/// Centralizes In-App Purchase configuration.
/// Supports environment-based and tenant-based product ID switching.
struct PurchaseConfig {
  /// Product ID for ad-free plan (non-consumable).
  /// Dynamically loaded from Info.plist or environment variables.
  static let adFreeProductID: String = {
    if let id = Bundle.main.infoDictionary?["ADFREE_PRODUCT_ID"] as? String, !id.isEmpty {
      return id
    }
    if let id = ProcessInfo.processInfo.environment["ADFREE_PRODUCT_ID"], !id.isEmpty {
      return id
    }
    // Fallback: test product ID
    return "com.kawatakazunari.naggingreminderapp.adfree"
  }()

  private init() {}  // Cannot instantiate as utility type
}

// MARK: - PurchaseError

/// In-App Purchase related errors.
/// Each case implements LocalizedError with user-friendly messages.
enum PurchaseError: LocalizedError, Equatable {
  /// Product information not yet loaded
  case productNotLoaded
  /// Invalid product ID (configuration error)
  case invalidProductID
  /// Failed to initiate purchase request from StoreKit
  case purchaseFailed(reason: String)
  /// User cancelled the purchase
  case purchaseCancelled
  /// Awaiting parental approval (Family Sharing)
  case purchasePending
  /// Failed to verify purchase state
  case verificationFailed
  /// App Store sync error
  case restoreFailed(reason: String)

  var errorDescription: String? {
    switch self {
    case .productNotLoaded:
      String(localized: "error.product.notloaded")
    case .invalidProductID:
      String(localized: "error.product.invalid")
    case .purchaseFailed(let reason):
      String(localized: "error.purchase.failed \(reason)")
    case .purchaseCancelled:
      String(localized: "error.purchase.cancelled")
    case .purchasePending:
      String(localized: "error.purchase.pending")
    case .verificationFailed:
      String(localized: "error.verification.failed")
    case .restoreFailed(let reason):
      String(localized: "error.restore.failed \(reason)")
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .productNotLoaded, .invalidProductID:
      String(localized: "error.suggestion.restart")
    case .purchaseFailed, .verificationFailed, .restoreFailed:
      String(localized: "error.suggestion.retry")
    case .purchaseCancelled, .purchasePending:
      nil
    }
  }

  static func == (lhs: PurchaseError, rhs: PurchaseError) -> Bool {
    switch (lhs, rhs) {
    case (.productNotLoaded, .productNotLoaded),
      (.invalidProductID, .invalidProductID),
      (.purchaseCancelled, .purchaseCancelled),
      (.purchasePending, .purchasePending),
      (.verificationFailed, .verificationFailed):
      return true
    case (.purchaseFailed(let lhsReason), .purchaseFailed(let rhsReason)):
      return lhsReason == rhsReason
    case (.restoreFailed(let lhsReason), .restoreFailed(let rhsReason)):
      return lhsReason == rhsReason
    default:
      return false
    }
  }
}

// MARK: - PurchaseManager

@MainActor
@Observable final class PurchaseManager: Sendable {
  private static nonisolated let logger = Logger(
    subsystem: "com.kawatakazunari.nagging-reminder", category: "PurchaseManager")

  private(set) var product: Product?
  private(set) var isAdFree: Bool = false
  private(set) var isPurchasing: Bool = false
  private(set) var currentError: PurchaseError?

  @ObservationIgnored private var _updatesTask: Task<Void, Never>?

  init() {
    setupTransactionListener()
    Task {
      await loadProduct()
      await updatePurchaseStatus()
    }
  }

  deinit {
    _updatesTask?.cancel()
    Self.logger.info("PurchaseManager deinitialized")
  }

  // MARK: - Setup

  private func setupTransactionListener() {
    _updatesTask = Task {
      for await verificationResult in Transaction.updates {
        await self.handle(verificationResult)
        await self.updatePurchaseStatus()
      }
    }
  }

  // MARK: - Load Product

  /// Fetch ad-free plan product information from App Store.
  func loadProduct() async {
    guard !PurchaseConfig.adFreeProductID.isEmpty else {
      self.currentError = .invalidProductID
      Self.logger.error("Invalid Product ID configuration")
      return
    }

    do {
      let products = try await Product.products(for: [PurchaseConfig.adFreeProductID])
      self.product = products.first
      self.currentError = nil
      Self.logger.info("Product loaded: \(products.count) product(s)")
    } catch {
      self.product = nil
      self.currentError = .purchaseFailed(reason: error.localizedDescription)
      Self.logger.error("Failed to load product: \(error.localizedDescription)")
    }
  }

  // MARK: - Purchase Status

  /// Check entitlements periodically and update isAdFree state.
  /// Conservatively preserves isAdFree on error (prevents user data loss).
  func updatePurchaseStatus() async {
    var adFree = false
    for await verificationResult in Transaction.currentEntitlements {
      if case .verified(let transaction) = verificationResult,
        transaction.productID == PurchaseConfig.adFreeProductID,
        transaction.revocationDate == nil
      {
        adFree = true
        Self.logger.info("User has active ad-free entitlement")
      }
    }
    self.isAdFree = adFree
  }

  // MARK: - Purchase

  /// Initiate ad-free plan purchase via App Store.
  func purchase() async {
    guard let product else {
      self.currentError = .productNotLoaded
      Self.logger.warning("Purchase attempted but product not loaded")
      return
    }

    self.isPurchasing = true
    self.currentError = nil
    defer { self.isPurchasing = false }

    do {
      let result = try await product.purchase()
      switch result {
      case .success(let verificationResult):
        await handle(verificationResult)
        await updatePurchaseStatus()
        Self.logger.info("Purchase succeeded")

      case .userCancelled:
        self.currentError = .purchaseCancelled
        Self.logger.info("Purchase cancelled by user")

      case .pending:
        self.currentError = .purchasePending
        Self.logger.info("Purchase pending (Family Sharing approval)")

      @unknown default:
        self.currentError = .purchaseFailed(reason: "Unknown result")
        Self.logger.warning("Purchase returned unknown result")
      }
    } catch {
      self.currentError = .purchaseFailed(reason: error.localizedDescription)
      Self.logger.error("Purchase failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Restore Purchases

  /// Restore previous purchases (e.g., when reinstalling on a new device).
  func restorePurchases() async {
    self.isPurchasing = true
    self.currentError = nil
    defer { self.isPurchasing = false }

    do {
      try await AppStore.sync()
      await updatePurchaseStatus()
      Self.logger.info("Restore purchases succeeded")
    } catch {
      self.currentError = .restoreFailed(reason: error.localizedDescription)
      Self.logger.error("Restore failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Private

  /// Verify transaction signature and call finish() on success.
  private func handle(_ verificationResult: VerificationResult<StoreKit.Transaction>) async {
    switch verificationResult {
    case .verified(let transaction):
      await transaction.finish()
      Self.logger.info("Transaction verified and finished")

    case .unverified:
      Self.logger.warning("Transaction verification failed - rejecting purchase")
      self.currentError = .verificationFailed
    }
  }

  // MARK: - Debug Helpers

  #if DEBUG
    /// Preview/test helper: Inject arbitrary state.
    func configureForPreview(
      product: Product? = nil,
      isAdFree: Bool = false,
      isPurchasing: Bool = false,
      currentError: PurchaseError? = nil
    ) {
      self.product = product
      self.isAdFree = isAdFree
      self.isPurchasing = isPurchasing
      self.currentError = currentError
    }
  #endif
}
