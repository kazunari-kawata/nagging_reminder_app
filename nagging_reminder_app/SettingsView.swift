import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TaskManager.self) private var taskManager
    @Environment(\.dismiss) private var dismiss

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
