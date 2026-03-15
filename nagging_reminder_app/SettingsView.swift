import SwiftUI

struct SettingsView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(TaskManager.self) private var taskManager
  @Environment(PurchaseManager.self) private var purchaseManager
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

        Section("Upgrade") {
          NavigationLink {
            AdFreeView()
              .environment(purchaseManager)
              .environment(settings)
          } label: {
            HStack {
              Label(String(localized: "ad.remove"), systemImage: "xmark.shield.fill")
              Spacer()
              if purchaseManager.isAdFree {
                Text(LocalizedStringResource("settings.purchased"))
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }

        Section("Data") {
          NavigationLink {
            HistoryView()
              .environment(taskManager)
          } label: {
            HStack {
              Text(LocalizedStringResource("settings.history"))
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
            Text(LocalizedStringResource("settings.delete.all"))
              .frame(maxWidth: .infinity, alignment: .center)
          }
          .alert(LocalizedStringResource("settings.delete.all"), isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
              taskManager.deleteAllData()
              showDeleteDone = true
            }
            Button("Cancel", role: .cancel) {}
          } message: {
            Text(LocalizedStringResource("settings.delete.warning"))
          }
          .alert("Deleted", isPresented: $showDeleteDone) {
            Button("OK") {}
          } message: {
            Text(LocalizedStringResource("settings.delete.confirmed"))
          }
        }
      }
      .navigationTitle(LocalizedStringResource("settings.title"))
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
