import SwiftUI

struct QuestionNavBar: View {
    @ObservedObject var viewModel: ExamSessionViewModel

    var body: some View {
        HStack(spacing: 12) {
            Text("Questions")
                .font(.subheadline.bold())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.state.questions.enumerated()), id: \.element.id) { index, question in
                        Button {
                            viewModel.selectQuestion(at: index)
                        } label: {
                            VStack(spacing: 3) {
                                Circle()
                                    .fill(question.isFlagged ? Color.orange : Color.clear)
                                    .frame(width: 6, height: 6)
                                Text("\(question.number)")
                                    .font(.system(.callout, design: .monospaced).bold())
                                    .frame(width: 34, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(index == viewModel.state.currentQuestionIndex
                                                  ? Color.accentColor
                                                  : question.userAnswer.isEmpty ? .clear : .secondary.opacity(0.2))
                                    )
                                    .foregroundStyle(index == viewModel.state.currentQuestionIndex ? .white : .primary)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(.secondary.opacity(0.35), lineWidth: 1)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "Question \(question.number), \(question.userAnswer.isEmpty ? "unanswered" : "answered")\(question.isFlagged ? ", flagged" : "")"
                        )
                    }
                }
            }

            Spacer(minLength: 8)

            if viewModel.state.questions.indices.contains(viewModel.state.currentQuestionIndex) {
                let question = viewModel.state.questions[viewModel.state.currentQuestionIndex]
                Button {
                    viewModel.toggleFlag(for: question.id)
                } label: {
                    Label(
                        question.isFlagged ? "Unflag" : "Flag for review",
                        systemImage: question.isFlagged ? "flag.fill" : "flag"
                    )
                }
                .buttonStyle(.bordered)
                .tint(question.isFlagged ? .orange : .primary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
