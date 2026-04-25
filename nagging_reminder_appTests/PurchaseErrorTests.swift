import Testing

@testable import nagging_reminder_app

@Suite("PurchaseError", .tags(.purchases))
struct PurchaseErrorTests {

  /// Every case must produce a non-empty localized description so the error alert
  /// never renders blank to the user. Catches missing String Catalog keys at build time.
  @Test("errorDescription is non-empty for every case", arguments: Self.allCases)
  func errorDescriptionPresent(_ error: PurchaseError) throws {
    let description = try #require(error.errorDescription)
    #expect(!description.isEmpty)
  }

  /// recoverySuggestion is nil only for the two user-driven outcomes — these don't need
  /// a "try again" hint. Keeps the alert UI honest.
  @Test("recoverySuggestion nil only for cancelled/pending", arguments: Self.allCases)
  func recoverySuggestionPresenceMatchesCase(_ error: PurchaseError) {
    switch error {
    case .purchaseCancelled, .purchasePending:
      #expect(error.recoverySuggestion == nil)
    default:
      #expect(error.recoverySuggestion != nil)
    }
  }

  // MARK: - Equatable

  @Test("Same case with same payload is equal")
  func equatableSamePayload() {
    #expect(PurchaseError.purchaseFailed(reason: "x") == .purchaseFailed(reason: "x"))
    #expect(PurchaseError.restoreFailed(reason: "y") == .restoreFailed(reason: "y"))
    #expect(PurchaseError.productNotLoaded == .productNotLoaded)
  }

  @Test("Same case with different payload is not equal")
  func equatableDifferentPayload() {
    #expect(PurchaseError.purchaseFailed(reason: "a") != .purchaseFailed(reason: "b"))
    #expect(PurchaseError.restoreFailed(reason: "a") != .restoreFailed(reason: "b"))
  }

  @Test("Different cases are not equal")
  func equatableDifferentCases() {
    #expect(PurchaseError.productNotLoaded != .invalidProductID)
    #expect(PurchaseError.purchaseCancelled != .purchasePending)
  }

  // MARK: - Fixtures

  static let allCases: [PurchaseError] = [
    .productNotLoaded,
    .invalidProductID,
    .purchaseFailed(reason: "test"),
    .purchaseCancelled,
    .purchasePending,
    .verificationFailed,
    .restoreFailed(reason: "test"),
  ]
}
