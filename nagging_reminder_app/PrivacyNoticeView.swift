import SwiftUI

struct PrivacyNoticeView: View {
  @Environment(AppSettings.self) private var settings

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringResource("privacy.title"))
              .font(.largeTitle.bold())
            Text(LocalizedStringResource("privacy.description"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Divider()

          privacyItem(
            symbol: "iphone",
            title: "privacy.item.storage.title",
            body: "privacy.item.storage.body"
          )

          privacyItem(
            symbol: "network.slash",
            title: "privacy.item.external.title",
            body: "privacy.item.external.body"
          )

          privacyItem(
            symbol: "bell.badge",
            title: "privacy.item.notification.title",
            body: "privacy.item.notification.body"
          )

          privacyItem(
            symbol: "dollarsign.circle",
            title: "privacy.item.ads.title",
            body: "privacy.item.ads.body"
          )

          privacyItem(
            symbol: "trash",
            title: "privacy.item.deletion.title",
            body: "privacy.item.deletion.body"
          )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
      }

      VStack(spacing: 12) {
        Divider()
        Button {
          settings.privacyNoticeAccepted = true
        } label: {
          Text(LocalizedStringResource("privacy.agree"))
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
      }
    }
    .background(Color(.systemGroupedBackground))
  }

  private func privacyItem(
    symbol: String, title: LocalizedStringResource, body: LocalizedStringResource
  ) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: symbol)
        .font(.title2)
        .foregroundStyle(Color.accentColor)
        .frame(width: 32)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(body)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  PrivacyNoticeView()
    .environment(AppSettings())
}
