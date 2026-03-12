import SwiftUI

// MARK: - HistoryItem

struct HistoryItem: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var schedule: RepeatSchedule
    var archivedDate: Date
    var reason: ArchiveReason

    enum ArchiveReason: String, Codable {
        case completed, deleted
    }
}

// MARK: - HistoryView

struct HistoryView: View {
    @Environment(TaskManager.self) private var taskManager
    @State private var showClearConfirm = false

    private var sortedHistory: [HistoryItem] {
        taskManager.history.sorted { $0.archivedDate > $1.archivedDate }
    }

    /// Groups items into (label, items) pairs by calendar day.
    private var groupedHistory: [(key: String, items: [HistoryItem])] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateStyle = .medium

        var order: [String] = []
        var map: [String: [HistoryItem]] = [:]

        for item in sortedHistory {
            let key: String
            if cal.isDateInToday(item.archivedDate)     { key = "Today" }
            else if cal.isDateInYesterday(item.archivedDate) { key = "Yesterday" }
            else { key = fmt.string(from: item.archivedDate) }

            if !order.contains(key) { order.append(key) }
            map[key, default: []].append(item)
        }

        return order.compactMap { key in
            guard let items = map[key] else { return nil }
            return (key: key, items: items)
        }
    }

    var body: some View {
        Group {
            if taskManager.history.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !taskManager.history.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear All") {
                        showClearConfirm = true
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog(
            "Clear all history?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                taskManager.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            ForEach(groupedHistory, id: \.key) { group in
                Section(group.key) {
                    ForEach(group.items) { item in
                        historyRow(item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        HStack(spacing: 12) {
            // Reason icon
            Image(systemName: item.reason == .completed ? "checkmark.circle.fill" : "trash.fill")
                .font(.system(size: 18))
                .foregroundStyle(item.reason == .completed ? Color.green : Color(.systemGray3))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))

                Text(item.schedule.detailedLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Time
            Text(item.archivedDate, style: .time)
                .font(.system(size: 12))
                .foregroundStyle(Color(.systemGray3))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(Color(.systemGray4))
            Text("No history yet")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
            Text("Completed one-time tasks and\ndeleted tasks will appear here.")
                .font(.subheadline)
                .foregroundStyle(Color(.systemGray))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
