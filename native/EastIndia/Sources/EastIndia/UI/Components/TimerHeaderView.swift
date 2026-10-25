import SwiftUI

struct TimerHeaderView: View {
    @ObservedObject var viewModel: ExamSessionViewModel
    @State private var pulseOpacity = 1.0

    private var formattedTime: String {
        let minutes = viewModel.state.remainingSeconds / 60
        let seconds = viewModel.state.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack {
            Text("East India")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(" / \(viewModel.state.phase.title)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "clock")
                Text(formattedTime)
                    .font(.system(.title3, design: .monospaced).bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(timerBackground, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(timerForeground)
            .opacity(pulseOpacity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Time remaining \(formattedTime)")

            Spacer()

            Button("Hide screen") {
                viewModel.isScreenHiddenForBreak = true
            }
            .buttonStyle(.bordered)

            Button("Submit section", action: viewModel.advanceManually)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(.bar)
        .onChange(of: viewModel.state.remainingSeconds) { _, seconds in
            if seconds == 600 || seconds == 300 {
                withAnimation(.easeInOut(duration: 0.35).repeatCount(6, autoreverses: true)) {
                    pulseOpacity = 0.25
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    pulseOpacity = 1
                }
            }
        }
    }

    private var timerBackground: Color {
        if viewModel.isTimerCriticalWarning { return .red.opacity(0.16) }
        if viewModel.isTimerFlashingWarning { return .orange.opacity(0.16) }
        return .clear
    }

    private var timerForeground: Color {
        if viewModel.isTimerCriticalWarning { return .red }
        if viewModel.isTimerFlashingWarning { return .orange }
        return .primary
    }
}
