import AppKit
import SwiftUI

struct ReadingSplitView: View {
    @ObservedObject var viewModel: ExamSessionViewModel

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.state.readingPassageTitle)
                    .font(.title2.bold())
                    .padding([.top, .horizontal], 16)
                Text("Select text, then right-click to highlight it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                HighlightablePassageView(
                    text: viewModel.state.readingPassageText,
                    highlights: viewModel.state.highlights,
                    onHighlight: { viewModel.addHighlight(location: $0.location, length: $0.length) },
                    onClear: viewModel.clearHighlights
                )
            }
            .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(viewModel.state.questions) { question in
                            QuestionCard(question: question, viewModel: viewModel)
                                .id(question.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: viewModel.state.currentQuestionIndex) { _, index in
                    guard viewModel.state.questions.indices.contains(index) else { return }
                    withAnimation {
                        proxy.scrollTo(viewModel.state.questions[index].id, anchor: .center)
                    }
                }
            }
            .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct QuestionCard: View {
    let question: ExamQuestion
    @ObservedObject var viewModel: ExamSessionViewModel

    private var answer: Binding<String> {
        Binding(
            get: { viewModel.state.questions.first(where: { $0.id == question.id })?.userAnswer ?? "" },
            set: { viewModel.setAnswer($0, for: question.id) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Question \(question.number)")
                    .font(.headline)
                Spacer()
                if question.isFlagged {
                    Label("Flagged", systemImage: "flag.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Text(question.prompt)
            if let options = question.options {
                Picker("Answer", selection: answer) {
                    Text("Choose an answer").tag("")
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.radioGroup)
            } else {
                TextField("Type or paste your answer", text: answer)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct HighlightablePassageView: NSViewRepresentable {
    struct Selection {
        let location: Int
        let length: Int
    }

    let text: String
    let highlights: [HighlightRange]
    let onHighlight: (Selection) -> Void
    let onClear: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 16)
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.string = text
        textView.delegate = context.coordinator
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              let storage = textView.textStorage else { return }
        if textView.string != text {
            textView.string = text
        }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.backgroundColor, range: fullRange)
        for highlight in highlights {
            guard highlight.rangeLocation >= 0,
                  highlight.rangeLength > 0,
                  highlight.rangeLocation + highlight.rangeLength <= storage.length else { continue }
            storage.addAttribute(
                .backgroundColor,
                value: NSColor.systemYellow.withAlphaComponent(0.45),
                range: NSRange(location: highlight.rangeLocation, length: highlight.rangeLength)
            )
        }
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightablePassageView

        init(parent: HighlightablePassageView) {
            self.parent = parent
        }

        func textView(_ textView: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            let selectedRange = textView.selectedRange()

            if selectedRange.length > 0 {
                let highlightItem = NSMenuItem(
                    title: "Highlight selection",
                    action: #selector(addHighlight(_:)),
                    keyEquivalent: ""
                )
                highlightItem.target = self
                highlightItem.representedObject = NSValue(range: selectedRange)
                menu.insertItem(highlightItem, at: 0)
            }

            if !parent.highlights.isEmpty {
                let clearItem = NSMenuItem(
                    title: "Clear highlights",
                    action: #selector(clearHighlights),
                    keyEquivalent: ""
                )
                clearItem.target = self
                menu.insertItem(clearItem, at: selectedRange.length > 0 ? 1 : 0)
            }

            if selectedRange.length > 0 || !parent.highlights.isEmpty {
                menu.insertItem(.separator(), at: selectedRange.length > 0 && !parent.highlights.isEmpty ? 2 : 1)
            }
            return menu
        }

        @objc private func addHighlight(_ sender: NSMenuItem) {
            guard let value = sender.representedObject as? NSValue else { return }
            let range = value.rangeValue
            parent.onHighlight(.init(location: range.location, length: range.length))
        }

        @objc private func clearHighlights() {
            parent.onClear()
        }
    }
}
