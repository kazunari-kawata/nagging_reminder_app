import Foundation

// MARK: - PurchaseManagerValidation

/// PurchaseManager と PurchaseError の動作検証用デバッグユーティリティ
/// デバッグビルドでのみコンパイル
#if DEBUG

  struct PurchaseManagerValidation {
    /// すべての PurchaseError タイプが localizedDescription を返すか検証
    static func validateErrorDescriptions() {
      let errors: [PurchaseError] = [
        .productNotLoaded,
        .invalidProductID,
        .purchaseFailed(reason: "Test reason"),
        .purchaseCancelled,
        .purchasePending,
        .verificationFailed,
        .restoreFailed(reason: "Test restore reason"),
      ]

      var allValid = true
      for error in errors {
        guard let description = error.errorDescription, !description.isEmpty else {
          print("❌ PurchaseError validation failed: \(error) has no localizedDescription")
          allValid = false
          continue
        }
        print("✅ PurchaseError.\(error) → \(description)")
      }

      if allValid {
        print("✅ All PurchaseError descriptions are valid")
      }
    }

    /// PurchaseError の Equatable 実装を検証
    static func validateErrorEquatable() {
      let errors1 = PurchaseError.purchaseFailed(reason: "test")
      let errors2 = PurchaseError.purchaseFailed(reason: "test")
      let errors3 = PurchaseError.purchaseFailed(reason: "different")

      assert(
        errors1 == errors2,
        "Same reason errors should be equal"
      )
      assert(
        errors1 != errors3,
        "Different reason errors should not be equal"
      )
      print("✅ PurchaseError Equatable validation passed")
    }

    /// PurchaseConfig.adFreeProductID が有効か検証
    static func validateProductID() {
      let productID = PurchaseConfig.adFreeProductID
      assert(
        !productID.isEmpty,
        "Product ID must not be empty. Please set ADFREE_PRODUCT_ID in Info.plist or environment"
      )
      print("✅ Product ID validated: \(productID)")
    }

    /// すべての検証を実行
    static func runAllValidations() {
      print("\n=== PurchaseManager Validation Suite ===\n")
      validateErrorDescriptions()
      print()
      validateErrorEquatable()
      print()
      validateProductID()
      print("\n=== Validation Complete ===\n")
    }
  }

#endif
