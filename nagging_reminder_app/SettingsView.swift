import SwiftUI

struct SettingsView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(TaskManager.self) private var taskManager
  @Environment(\.dismiss) private var dismiss

  @State private var showDeleteConfirm = false
  @State private var showDeleteDone = false

  var body: some View {
    @Bindable var s = settings
    NavigationStack {
      Form {
        Section("Appearance") {
          Picker("Theme", selection: $s.theme) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
              Text(theme.displayName).tag(theme)
            }
          }
          .pickerStyle(.segmented)
        }

        Section("Calendar") {
          Picker("Week starts", selection: $s.weekStart) {
            ForEach(WeekStart.allCases, id: \.self) { ws in
              Text(ws.displayName).tag(ws)
            }
          }
        }

        Section("Data") {
          NavigationLink {
            HistoryView()
              .environment(taskManager)
          } label: {
            HStack {
              Text("History")
              Spacer()
              if !taskManager.history.isEmpty {
                Text("\(taskManager.history.count)")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
            }
          }

          Button(role: .destructive) {
            showDeleteConfirm = true
          } label: {
            Text("全データを削除する")
              .frame(maxWidth: .infinity, alignment: .center)
          }
          .alert("全データを削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除する", role: .destructive) {
              taskManager.deleteAllData()
              showDeleteDone = true
            }
            Button("キャンセル", role: .cancel) {}
          } message: {
            Text("タスクと履歴がすべて削除されます。この操作は取り消せません。")
          }
          .alert("削除しました", isPresented: $showDeleteDone) {
            Button("OK") {}
          } message: {
            Text("すべてのデータを削除しました。")
          }
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .preferredColorScheme(settings.theme.colorScheme)
  }
}
