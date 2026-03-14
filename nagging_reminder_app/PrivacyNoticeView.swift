import SwiftUI

struct PrivacyNoticeView: View {
  @Environment(AppSettings.self) private var settings

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          VStack(alignment: .leading, spacing: 8) {
            Text("プライバシーポリシー")
              .font(.largeTitle.bold())
            Text("このアプリをご利用いただく前に、以下のプライバシーに関する事項をお読みください。")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Divider()

          privacyItem(
            symbol: "iphone",
            title: "データの保存場所",
            body: "タスクや履歴データはお使いの端末内にのみ保存されます。外部サーバーへの送信は行いません。"
          )

          privacyItem(
            symbol: "network.slash",
            title: "外部への送信",
            body: "個人を特定できる情報を収集・送信することはありません。"
          )

          privacyItem(
            symbol: "bell.badge",
            title: "通知",
            body: "タスクのリマインダーとして、設定した日時に通知を送信します。通知の許可はいつでもシステム設定から変更できます。"
          )

          privacyItem(
            symbol: "dollarsign.circle",
            title: "広告",
            body:
              "このアプリはGoogle AdMobを使用して広告を表示することがあります。AdMobは端末の広告IDを使用する場合があります。詳細はGoogleのプライバシーポリシーをご参照ください。"
          )

          privacyItem(
            symbol: "trash",
            title: "データの削除",
            body: "設定画面から、アプリに保存されているすべてのデータをいつでも削除できます。"
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
          Text("同意して始める")
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

  private func privacyItem(symbol: String, title: String, body: String) -> some View {
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
