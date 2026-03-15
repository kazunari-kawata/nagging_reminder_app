import SwiftUI
import Combine
import AVFoundation

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

    func updatePreset(id: UUID, name: String, totalSeconds: Int) {
        if let index = presets.firstIndex(where: { $0.id == id }) {
            presets[index].name = name
            presets[index].totalSeconds = totalSeconds
        }
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
    @State private var showPresetSheet: Bool = false
    @State private var editingPreset: TimerPreset? = nil
    @State private var audioPlayer: AVAudioPlayer? = nil

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
                Text(String(localized: "Timers"))
                    .font(.largeTitle.bold())
                    .tracking(-0.5)
                Spacer()
                Button {
                    editingPreset = nil
                    showPresetSheet = true
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
                playAlarmSound()
            }
        }
        .sheet(isPresented: $showPresetSheet) {
            TimerPresetSheet(preset: editingPreset) { name, seconds in
                if let editing = editingPreset {
                    timerManager.updatePreset(id: editing.id, name: name, totalSeconds: seconds)
                    if activePresetID == editing.id {
                        totalSeconds = seconds
                        remainingSeconds = seconds
                        isRunning = false
                        isFinished = false
                    }
                } else {
                    timerManager.addPreset(name: name, totalSeconds: seconds)
                }
            }
        }
    }

    // MARK: - Active Timer

    private var activeTimerSection: some View {
        VStack(spacing: 20) {
            // Circular progress
            if isFinished {
                // Completed state with Stop/Repeat controls
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                            .symbolEffect(.bounce, options: .repeating, isActive: true)
                        Text(String(localized: "Done!"))
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 24)

                    HStack(spacing: 40) {
                        // Stop Button
                        Button {
                            stopAlarmSound()
                            activePresetID = nil
                            isFinished = false
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 64, height: 64)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                Text(String(localized: "Stop"))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.red)
                            }
                        }

                        // Repeat Button
                        Button {
                            stopAlarmSound()
                            remainingSeconds = totalSeconds
                            isRunning = true
                            isFinished = false
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 64, height: 64)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                Text(String(localized: "Repeat"))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.blue,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)

                    VStack(spacing: 4) {
                        Text(timeString)
                            .font(.system(size: 42, weight: .thin, design: .monospaced))
                        if let preset = timerManager.presets.first(where: { $0.id == activePresetID }) {
                            Text(preset.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 24)
        .onDisappear { stopAlarmSound() }
    }

    // MARK: - Audio Playback

    private func playAlarmSound() {
        guard let url = Bundle.main.url(forResource: "baddger-sound", withExtension: "mp3") else {
            print("Could not find baddger-sound.mp3")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Infinite loop
            audioPlayer?.play()
        } catch {
            print("Failed to play alarm sound: \(error)")
        }
    }

    private func stopAlarmSound() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Preset List

    private var presetList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                HStack {
                    Text(String(localized: "PRESETS"))
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

        return TimerPresetCardView(
            preset: preset,
            isActive: isActive,
            isRunning: isRunning,
            onPlayPause: {
                if isActive {
                    isRunning.toggle()
                } else {
                    activePresetID = preset.id
                    remainingSeconds = preset.totalSeconds
                    totalSeconds = preset.totalSeconds
                    isRunning = true
                    isFinished = false
                }
            },
            onEdit: {
                editingPreset = preset
                showPresetSheet = true
            },
            onDelete: {
                if isActive {
                    activePresetID = nil
                    isRunning = false
                    isFinished = false
                }
                if let idx = timerManager.presets.firstIndex(where: { $0.id == preset.id }) {
                    timerManager.deletePreset(at: IndexSet([idx]))
                }
            }
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(Color(.systemGray4))
            Text(String(localized: "No timers yet"))
                .font(.title3.bold())
                .foregroundStyle(.secondary)
            Text(String(localized: "Tap + to create a preset timer"))
                .font(.subheadline)
                .foregroundStyle(Color(.systemGray))
            Spacer()
        }
    }
}

// MARK: - Timer Preset Sheet

struct TimerPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let preset: TimerPreset?
    let onSave: (String, Int) -> Void

    @State private var name: String = ""
    @State private var minutes: Int = 5
    @State private var seconds: Int = 0

    private var totalSeconds: Int { minutes * 60 + seconds }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Name (e.g. Coffee, Exercise)"), text: $name)
                }

                Section(String(localized: "Duration")) {
                    Stepper("\(minutes) " + String(localized: "min"), value: $minutes, in: 0...99)
                    Stepper("\(seconds) " + String(localized: "sec"), value: $seconds, in: 0...59, step: 5)
                }

                Section {
                    HStack {
                        Text(String(localized: "Total"))
                        Spacer()
                        Text(totalSeconds >= 3600
                             ? String(format: "%d:%02d:%02d", totalSeconds/3600, (totalSeconds%3600)/60, totalSeconds%60)
                             : String(format: "%d:%02d", totalSeconds/60, totalSeconds%60))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(preset == nil ? String(localized: "New Timer") : String(localized: "Edit Timer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        onSave(name.trimmingCharacters(in: .whitespaces), totalSeconds)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || totalSeconds == 0)
                }
            }
            .onAppear {
                if let p = preset {
                    name = p.name
                    minutes = p.totalSeconds / 60
                    seconds = p.totalSeconds % 60
                }
            }
        }
    }
}

// MARK: - TimerPresetCardView

struct TimerPresetCardView: View {
    let preset: TimerPreset
    let isActive: Bool
    let isRunning: Bool
    let onPlayPause: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var cardWidth: CGFloat = 320
    @State private var triggeredLight = false
    @State private var triggeredHeavy = false

    /// 15% of card width — swipe past to edit.
    private var editThreshold: CGFloat { cardWidth * 0.15 }
    /// 70% of card width — swipe past to delete.
    private var deleteThreshold: CGFloat { cardWidth * 0.70 }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Reveal background
            if dragOffset < -(editThreshold * 0.4) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(dragOffset < -deleteThreshold ? Color.red : Color.orange)
                HStack {
                    Spacer()
                    Image(systemName: dragOffset < -deleteThreshold ? "trash" : "pencil")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.trailing, 24)
                }
            }

            cardContent
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard value.translation.width < 0 else { return }
                            dragOffset = value.translation.width

                            if dragOffset < -editThreshold && !triggeredLight {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                triggeredLight = true
                                triggeredHeavy = false
                            }
                            if dragOffset < -deleteThreshold && !triggeredHeavy {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                triggeredHeavy = true
                            }
                            if dragOffset > -editThreshold {
                                triggeredLight = false
                                triggeredHeavy = false
                            }
                        }
                        .onEnded { value in
                            let t = value.translation.width
                            if t < -deleteThreshold {
                                withAnimation(.easeOut(duration: 0.25)) { dragOffset = -500 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onDelete() }
                            } else if t < -editThreshold {
                                withAnimation(.spring()) { dragOffset = 0 }
                                onEdit()
                            } else {
                                withAnimation(.spring()) { dragOffset = 0 }
                            }
                            triggeredLight = false
                            triggeredHeavy = false
                        }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { cardWidth = geo.size.width }
            }
        )
    }

    private var cardContent: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.system(size: 16, weight: .medium))
                Text(preset.displayDuration)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onPlayPause()
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
    }
}
