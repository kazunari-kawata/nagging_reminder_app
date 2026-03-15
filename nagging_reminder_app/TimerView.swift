import SwiftUI
import Combine

// MARK: - TimerPreset

struct TimerPreset: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var totalSeconds: Int

    var displayDuration: String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        if s == 0 { return "\(m) min" }
        return "\(m)m \(s)s"
    }
}

// MARK: - TimerManager

@Observable final class TimerManager {
    private static let storageKey = "timerPresets"

    var presets: [TimerPreset] = [] {
        didSet { save() }
    }

    init() { load() }

    func addPreset(name: String, totalSeconds: Int) {
        presets.append(TimerPreset(name: name, totalSeconds: totalSeconds))
    }

    func deletePreset(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([TimerPreset].self, from: data)
        else { return }
        presets = decoded
    }
}

// MARK: - TimerView

struct TimerView: View {
    @Environment(TimerManager.self) private var timerManager

    @State private var activePresetID: UUID? = nil
    @State private var remainingSeconds: Int = 0
    @State private var totalSeconds: Int = 1
    @State private var isRunning: Bool = false
    @State private var isFinished: Bool = false
    @State private var showAddSheet: Bool = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    private var timeString: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image("HeaderIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .padding(.trailing, 6)
                Text("Timers")
                    .font(.largeTitle.bold())
                    .tracking(-0.5)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Active timer display
            if activePresetID != nil {
                activeTimerSection
                    .padding(.bottom, 16)
            }

            // Preset list
            if timerManager.presets.isEmpty {
                emptyState
            } else {
                presetList
            }

            Spacer()
        }
        .onReceive(ticker) { _ in
            guard isRunning else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                isRunning = false
                isFinished = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTimerPresetSheet { name, seconds in
                timerManager.addPreset(name: name, totalSeconds: seconds)
            }
        }
    }

    // MARK: - Active Timer

    private var activeTimerSection: some View {
        VStack(spacing: 20) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: isFinished ? 1.0 : progress)
                    .stroke(
                        isFinished ? Color.green : Color.blue,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 4) {
                    if isFinished {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("Done!")
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                    } else {
                        Text(timeString)
                            .font(.system(size: 42, weight: .thin, design: .monospaced))
                        if let preset = timerManager.presets.first(where: { $0.id == activePresetID }) {
                            Text(preset.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(width: 200, height: 200)

            // Controls
            HStack(spacing: 24) {
                Button {
                    isRunning.toggle()
                } label: {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(isRunning ? Color.orange : Color.blue)
                        .clipShape(Circle())
                }

                Button {
                    guard let preset = timerManager.presets.first(where: { $0.id == activePresetID }) else { return }
                    remainingSeconds = preset.totalSeconds
                    totalSeconds = preset.totalSeconds
                    isRunning = false
                    isFinished = false
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                        .frame(width: 56, height: 56)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 24)
    }

    // MARK: - Preset List

    private var presetList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                HStack {
                    Text("PRESETS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(.systemGray))
                        .tracking(1)
                    Spacer()
                }
                .padding(.leading, 4)
                .padding(.bottom, 2)

                ForEach(timerManager.presets) { preset in
                    presetRow(preset)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private func presetRow(_ preset: TimerPreset) -> some View {
        let isActive = preset.id == activePresetID

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.system(size: 16, weight: .medium))
                Text(preset.displayDuration)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if isActive {
                    isRunning.toggle()
                } else {
                    activePresetID = preset.id
                    remainingSeconds = preset.totalSeconds
                    totalSeconds = preset.totalSeconds
                    isRunning = true
                    isFinished = false
                }
            } label: {
                Image(systemName: isActive && isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isActive ? .white : .blue)
                    .frame(width: 40, height: 40)
                    .background(isActive ? Color.blue : Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isActive ? Color.blue.opacity(0.4) : Color(.systemGray5), lineWidth: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                if isActive {
                    activePresetID = nil
                    isRunning = false
                    isFinished = false
                }
                if let idx = timerManager.presets.firstIndex(where: { $0.id == preset.id }) {
                    timerManager.deletePreset(at: IndexSet([idx]))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(Color(.systemGray4))
            Text("No timers yet")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
            Text("Tap + to create a preset timer")
                .font(.subheadline)
                .foregroundStyle(Color(.systemGray))
            Spacer()
        }
    }
}

// MARK: - Add Timer Preset Sheet

struct AddTimerPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, Int) -> Void

    @State private var name: String = ""
    @State private var minutes: Int = 5
    @State private var seconds: Int = 0

    private var totalSeconds: Int { minutes * 60 + seconds }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Coffee, Exercise)", text: $name)
                }

                Section("Duration") {
                    Stepper("\(minutes) min", value: $minutes, in: 0...99)
                    Stepper("\(seconds) sec", value: $seconds, in: 0...59, step: 5)
                }

                Section {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(totalSeconds >= 3600
                             ? String(format: "%d:%02d:%02d", totalSeconds/3600, (totalSeconds%3600)/60, totalSeconds%60)
                             : String(format: "%d:%02d", totalSeconds/60, totalSeconds%60))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(name.trimmingCharacters(in: .whitespaces), totalSeconds)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || totalSeconds == 0)
                }
            }
        }
    }
}
