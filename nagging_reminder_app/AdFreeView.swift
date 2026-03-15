import StoreKit
import SwiftUI

// MARK: - AdFreeView

struct AdFreeView: View {
  @Environment(PurchaseManager.self) private var purchaseManager
  @Environment(AppSettings.self) private var settings
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Group {
        if purchaseManager.isAdFree {
          purchasedView
        } else {
          storeFrontView
        }
      }
      .navigationTitle(LocalizedStringResource("ad.free.plan"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .preferredColorScheme(settings.theme.colorScheme)
  }

  // MARK: - Purchased State

  private var purchasedView: some View {
    VStack(spacing: 24) {
      Spacer()
      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 64))
        .foregroundStyle(.green)
      Text(LocalizedStringResource("ad.free.plan.purchased"))
        .font(.title2.bold())
        .multilineTextAlignment(.center)
      Text(LocalizedStringResource("ad.free.all.hidden"))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      Spacer()
    }
  }

  // MARK: - Store Front

  private var storeFrontView: some View {
    VStack(spacing: 0) {
      Spacer()

      VStack(spacing: 16) {
        Image(systemName: "xmark.shield.fill")
          .font(.system(size: 64))
          .foregroundStyle(.orange)

        Text(LocalizedStringResource("ad.remove"))
          .font(.title2.bold())

        Text(LocalizedStringResource("ad.remove.description"))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
      }

      Spacer()

      VStack(spacing: 12) {
        // Error message area (always reserve space to prevent content jumping)
        if let error = purchaseManager.currentError {
          HStack {
            Image(systemName: "exclamationmark.circle.fill")
              .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 4) {
              Text(error.localizedDescription)
                .font(.caption)
              if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
            Spacer()
          }
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(Color.red.opacity(0.1))
          .cornerRadius(8)
          .transition(.opacity.combined(with: .scale(scale: 0.95)))
          .padding(.horizontal, 24)
        } else {
          // Preserve space to prevent content jumping
          Color.clear
            .frame(height: 44)
            .padding(.horizontal, 24)
        }

        Button {
          Task { await purchaseManager.purchase() }
        } label: {
          Group {
            if purchaseManager.isPurchasing {
              HStack(spacing: 8) {
                ProgressView()
                  .tint(.white)
                Text(LocalizedStringResource("purchase.in.progress"))
                  .font(.headline)
              }
            } else if let product = purchaseManager.product {
              Text(String(localized: "purchase.button") + "  \(product.displayPrice)")
                .font(.headline)
            } else {
              Text(LocalizedStringResource("purchase.loading"))
                .font(.headline)
            }
          }
          .frame(maxWidth: .infinity)
          .frame(minHeight: 48)  // touch target minimum 44x44
          .padding()
          .background(
            purchaseManager.product != nil && !purchaseManager.isPurchasing
              ? Color.blue : Color(.systemGray3)
          )
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 14))
          .animation(.easeInOut(duration: 0.2), value: purchaseManager.isPurchasing)
        }
        .disabled(purchaseManager.product == nil || purchaseManager.isPurchasing)
        .padding(.horizontal, 24)

        Button {
          Task { await purchaseManager.restorePurchases() }
        } label: {
          Text(LocalizedStringResource("purchase.restore"))
            .font(.subheadline)
            .frame(minHeight: 44)  // touch target minimum
            .frame(maxWidth: .infinity)
            .foregroundStyle(.blue)
        }
        .disabled(purchaseManager.isPurchasing)
        .animation(.easeInOut(duration: 0.2), value: purchaseManager.isPurchasing)
      }

      Spacer().frame(height: 48)
    }
    .task {
      if purchaseManager.product == nil {
        await purchaseManager.loadProduct()
      }
    }
  }
}
