import SwiftUI

struct WritingSplitView: View {
    @ObservedObject var viewModel: ExamSessionViewModel

    private var response: Binding<String> {
        Binding(
            get: { viewModel.state.writingResponse },
            set: { viewModel.setWritingResponse($0) }
        )
    }

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Writing Task 2")
                        .font(.title2.bold())
                    Text("Suggested time: about 40 minutes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Divider()
                    Text(viewModel.state.writingPrompt)
                        .lineSpacing(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                TextEditor(text: response)
                    .font(.system(size: 15))
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.25), lineWidth: 1)
                    }
                HStack {
                    Text("Word count: \(viewModel.wordCount)")
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .accessibilityLabel("Current word count \(viewModel.wordCount)")
                    Spacer()
                    Text("Draft saved on this Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
