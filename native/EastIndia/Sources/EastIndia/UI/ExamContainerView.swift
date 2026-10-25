import Combine
import AppKit
import SwiftUI

struct ExamContainerView: View {
    @StateObject private var viewModel = ExamSessionViewModel()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                switch viewModel.state.phase {
                case .intro:
                    IntroScreenView(viewModel: viewModel)
                case .familiarisation, .finalInstructions:
                    InstructionsScreenView(viewModel: viewModel)
                case .listening, .listeningReview:
                    TimerHeaderView(viewModel: viewModel)
                    Divider()
                    ListeningView(isReview: viewModel.state.phase == .listeningReview)
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

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: viewModel.state.phase == .familiarisation ? "checklist" : "info.circle")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text(viewModel.state.phase.title)
                .font(.largeTitle.bold())
            Text(viewModel.state.phase == .familiarisation
                 ? "Your answers and writing draft are saved automatically on this Mac."
                 : "Once listening begins, the section timer continues if you hide the screen or close the app.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
            Button(viewModel.state.phase == .familiarisation ? "Continue" : "Begin listening") {
                if viewModel.state.phase == .familiarisation {
                    viewModel.startPhase(.finalInstructions)
                } else {
                    viewModel.beginListening()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct ListeningView: View {
    let isReview: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isReview ? "checkmark.circle" : "headphones")
                .font(.system(size: 46))
                .foregroundStyle(.tint)
            Text(isReview ? "Review your listening answers" : "Listening section")
                .font(.title2.bold())
            Text(isReview
                 ? "Use the remaining time to check your answers."
                 : "Audio playback will be added in the next module. This section timer and answer navigation are ready.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
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
            Text("This clears the current answers, highlights, and writing draft from this Mac.")
        }
    }
}
