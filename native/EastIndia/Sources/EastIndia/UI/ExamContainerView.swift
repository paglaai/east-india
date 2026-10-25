import Combine
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ExamContainerView: View {
    @StateObject private var viewModel = ExamSessionViewModel()
    @StateObject private var audioService = AudioService()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                switch viewModel.state.phase {
                case .intro:
                    IntroScreenView(viewModel: viewModel)
                case .familiarisation, .finalInstructions:
                    InstructionsScreenView(viewModel: viewModel, audioService: audioService)
                case .listening, .listeningReview:
                    TimerHeaderView(viewModel: viewModel)
                    Divider()
                    ListeningView(
                        isReview: viewModel.state.phase == .listeningReview,
                        viewModel: viewModel,
                        audioService: audioService
                    )
                    Divider()
                    QuestionNavBar(viewModel: viewModel)
                case .reading:
                    TimerHeaderView(viewModel: viewModel)
                    Divider()
                    ReadingSplitView(viewModel: viewModel)
                    Divider()
                    QuestionNavBar(viewModel: viewModel)
                case .writing:
                    TimerHeaderView(viewModel: viewModel)
                    Divider()
                    WritingSplitView(viewModel: viewModel)
                case .completed:
                    CompletionView(viewModel: viewModel)
                }
            }

            if viewModel.isScreenHiddenForBreak {
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 42))
                            Text("Screen hidden")
                                .font(.title.bold())
                            Text("Your test timer is still running.")
                                .foregroundStyle(.white.opacity(0.75))
                            Button("Resume practice") {
                                viewModel.isScreenHiddenForBreak = false
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                        .foregroundStyle(.white)
                    }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(clock) { viewModel.tick(now: $0) }
        .onChange(of: viewModel.state.phase) { oldPhase, newPhase in
            if oldPhase == .listening && newPhase != .listening {
                audioService.stopPlayback()
            }
            if newPhase == .intro {
                audioService.resetForNewSession()
            }
        }
        .alert(
            "Could not save session",
            isPresented: Binding(
                get: { viewModel.persistenceError != nil },
                set: { if !$0 { viewModel.dismissPersistenceError() } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.dismissPersistenceError() }
        } message: {
            Text(viewModel.persistenceError ?? "")
        }
    }
}

private struct IntroScreenView: View {
    @ObservedObject var viewModel: ExamSessionViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("East India")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("Computer-delivered English exam simulator")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                Label("Listening · 30 minutes plus a 2-minute review", systemImage: "headphones")
                Label("Reading · 60 minutes with passage highlighting", systemImage: "book.pages")
                Label("Writing · 60 minutes with a live word count", systemImage: "keyboard")
            }
            .font(.body)
            .padding(22)
            .frame(maxWidth: 470, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 12) {
                Button("Start full simulation") {
                    viewModel.startFullSimulation()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Jump to reading") {
                    viewModel.startPhase(.reading)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Text("Independent practice software. Not affiliated with or endorsed by official testing partners.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InstructionsScreenView: View {
    @ObservedObject var viewModel: ExamSessionViewModel
    @ObservedObject var audioService: AudioService

    var body: some View {
        if viewModel.state.phase == .familiarisation {
            VStack(spacing: 20) {
                Image(systemName: "checklist")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text(viewModel.state.phase.title)
                    .font(.largeTitle.bold())
                Text("Your answers and writing draft are saved automatically on this Mac.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
                Button("Continue") {
                    viewModel.startPhase(.finalInstructions)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
        } else {
            PreListeningSetupView(viewModel: viewModel, audioService: audioService)
        }
    }
}

private struct PreListeningSetupView: View {
    @ObservedObject var viewModel: ExamSessionViewModel
    @ObservedObject var audioService: AudioService
    @State private var showingAudioImporter = false
    @State private var importError: String?

    private var selectedAudioName: String? {
        viewModel.state.listeningAudioDisplayName ?? viewModel.listeningAudioURL?.lastPathComponent
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "headphones")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Sound check")
                .font(.largeTitle.bold())
            Text("Choose the listening audio, check your speakers, and set a comfortable volume before the timer starts.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button(selectedAudioName == nil ? "Choose audio file" : "Replace audio file") {
                        showingAudioImporter = true
                    }
                    .buttonStyle(.bordered)

                    if let selectedAudioName {
                        Label(selectedAudioName, systemImage: "waveform")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if !viewModel.hasValidListeningAudio {
                            Text("File missing — choose it again.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Text("No listening audio selected")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        audioService.playSoundCheck {
                            viewModel.completeSoundCheck()
                        }
                    } label: {
                        Label(
                            audioService.isSoundCheckPlaying ? "Playing test tone…" : "Play test tone",
                            systemImage: audioService.isSoundCheckPlaying ? "speaker.wave.2" : "speaker.wave.2.circle"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(audioService.isSoundCheckPlaying)

                    if viewModel.state.audioSoundCheckCompleted {
                        Label("Sound check complete", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "speaker")
                        .foregroundStyle(.secondary)
                    Slider(value: $audioService.volume, in: 0...1)
                        .accessibilityLabel("Audio volume")
                    Image(systemName: "speaker.wave.3")
                        .foregroundStyle(.secondary)
                    Text("\(Int(audioService.volume * 100))%")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 42, alignment: .trailing)
                }

                if let playbackError = audioService.playbackError {
                    Label(playbackError, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let importError {
                    Label(importError, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(maxWidth: 580, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            Text("The selected audio is copied to this Mac. Playback can be started only once and cannot be paused or rewound.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            Button("Begin listening") {
                viewModel.beginListening()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(
                !viewModel.canBeginListening
                    || audioService.isSoundCheckPlaying
            )

            Text("The 30-minute timer begins when you continue. It keeps running if you hide the screen or close the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .fileImporter(
            isPresented: $showingAudioImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedURL = try result.get().first else { return }
                try viewModel.importListeningAudio(from: selectedURL)
                importError = nil
            } catch {
                if (error as NSError).code == NSUserCancelledError {
                    return
                }
                importError = error.localizedDescription
            }
        }
    }
}

private struct ListeningView: View {
    let isReview: Bool
    @ObservedObject var viewModel: ExamSessionViewModel
    @ObservedObject var audioService: AudioService

    var body: some View {
        Group {
            if isReview {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 46))
                        .foregroundStyle(.tint)
                    Text("Review your listening answers")
                        .font(.title2.bold())
                    Text("Use the remaining time to check your answers.")
                        .foregroundStyle(.secondary)
                }
            } else {
                listeningPlayer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .onChange(of: isReview) { _, reviewStarted in
            if reviewStarted {
                audioService.stopPlayback()
            }
        }
        .onDisappear {
            audioService.stopPlayback()
        }
    }

    private var listeningPlayer: some View {
        VStack(spacing: 16) {
            Image(systemName: "headphones")
                .font(.system(size: 46))
                .foregroundStyle(.tint)
            Text("Listening section")
                .font(.title2.bold())

            if viewModel.state.listeningAudioHasStarted {
                if audioService.isListeningPlaying {
                    Text("Audio is playing once. Pause and seeking are disabled.")
                        .foregroundStyle(.secondary)
                    if audioService.duration > 0 {
                        ProgressView(value: min(audioService.currentTime, audioService.duration), total: audioService.duration)
                            .frame(maxWidth: 420)
                            .accessibilityLabel("Listening audio playback progress")
                    }
                    Text("\(timeLabel(audioService.currentTime))\(audioService.duration > 0 ? " / \(timeLabel(audioService.duration))" : "")")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Label(
                        audioService.playbackFinished
                            ? "Audio finished. Your review window is starting."
                            : "Audio has already been started and cannot be replayed.",
                        systemImage: audioService.playbackFinished ? "checkmark.circle.fill" : "lock.fill"
                    )
                    .foregroundStyle(audioService.playbackFinished ? .green : .secondary)
                    .multilineTextAlignment(.center)
                }
            } else if let audioURL = viewModel.listeningAudioURL {
                Button {
                    guard viewModel.markListeningAudioStarted() else { return }
                    audioService.playListeningAudio(from: audioURL) {
                        viewModel.beginListeningReview()
                    }
                } label: {
                    Label("Play listening audio once", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(audioService.isSoundCheckPlaying || audioService.isListeningPlaying)
            } else {
                Text("No listening audio is available for this session.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker")
                    .foregroundStyle(.secondary)
                Slider(value: $audioService.volume, in: 0...1)
                    .frame(maxWidth: 280)
                    .accessibilityLabel("Audio volume")
                Image(systemName: "speaker.wave.3")
                    .foregroundStyle(.secondary)
                Text("\(Int(audioService.volume * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 42, alignment: .trailing)
            }

            if let playbackError = audioService.playbackError {
                Label(playbackError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
        }
    }

    private func timeLabel(_ seconds: Double) -> String {
        let wholeSeconds = max(Int(seconds), 0)
        return String(format: "%02d:%02d", wholeSeconds / 60, wholeSeconds % 60)
    }
}

private struct CompletionView: View {
    @ObservedObject var viewModel: ExamSessionViewModel
    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Practice session complete")
                .font(.largeTitle.bold())
            Text("Your answers and writing draft remain saved on this Mac.")
                .foregroundStyle(.secondary)
            Button("Start over") {
                showingResetConfirmation = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Start a new practice session?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear saved session and start over", role: .destructive) {
                viewModel.startOver()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the current answers, highlights, writing draft, and copied listening audio from this Mac.")
        }
    }
}
