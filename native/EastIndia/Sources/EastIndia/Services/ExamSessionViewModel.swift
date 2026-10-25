import Combine
import Foundation

@MainActor
final class ExamSessionViewModel: ObservableObject {
    @Published private(set) var state: ExamSessionState
    @Published private(set) var persistenceError: String?
    @Published var isScreenHiddenForBreak = false

    private let store: SessionStore
    private var lastAutosaveAt = Date.distantPast

    init(store: SessionStore = SessionStore()) {
        self.store = store

        do {
            if var restored = try store.load() {
                if restored.phase.isTimed {
                    if let deadline = restored.deadline {
                        restored.remainingSeconds = max(Int(ceil(deadline.timeIntervalSinceNow)), 0)
                    } else {
                        restored.deadline = Date().addingTimeInterval(TimeInterval(max(restored.remainingSeconds, 0)))
                    }
                }
                state = restored
                settleExpiredTimer()
            } else {
                state = ExamSessionState()
            }
        } catch {
            state = ExamSessionState()
            persistenceError = "The saved practice session could not be opened: \(error.localizedDescription)"
        }
    }

    var wordCount: Int {
        state.writingResponse.split { $0.isWhitespace || $0.isNewline }.count
    }

    var isTimerFlashingWarning: Bool {
        [.reading, .writing].contains(state.phase) && state.remainingSeconds <= 600 && state.remainingSeconds > 0
    }

    var isTimerCriticalWarning: Bool {
        [.reading, .writing].contains(state.phase) && state.remainingSeconds <= 300 && state.remainingSeconds > 0
    }

    func startFullSimulation() {
        startPhase(.familiarisation)
    }

    func beginListening() {
        startPhase(.listening)
    }

    func startPhase(_ phase: ExamPhase) {
        var next = state
        next.phase = phase
        next.currentQuestionIndex = 0
        next.remainingSeconds = duration(for: phase)
        next.deadline = phase.isTimed ? Date().addingTimeInterval(TimeInterval(next.remainingSeconds)) : nil
        update(next)
    }

    func advanceManually() {
        switch state.phase {
        case .listening, .listeningReview:
            startPhase(.reading)
        case .reading:
            startPhase(.writing)
        case .writing:
            startPhase(.completed)
        default:
            break
        }
    }

    func dismissPersistenceError() {
        persistenceError = nil
    }

    func tick(now: Date = Date()) {
        guard state.phase.isTimed, let deadline = state.deadline else { return }
        let remaining = max(Int(ceil(deadline.timeIntervalSince(now))), 0)
        guard remaining != state.remainingSeconds else { return }

        var next = state
        next.remainingSeconds = remaining
        if remaining == 0 {
            advanceExpiredSections(in: &next, now: now)
        }

        state = next
        if now.timeIntervalSince(lastAutosaveAt) >= 5 || remaining == 0 {
            persist()
            lastAutosaveAt = now
        }
    }

    func selectQuestion(at index: Int) {
        guard state.questions.indices.contains(index) else { return }
        var next = state
        next.currentQuestionIndex = index
        update(next)
    }

    func setAnswer(_ answer: String, for questionID: Int) {
        guard let index = state.questions.firstIndex(where: { $0.id == questionID }) else { return }
        var next = state
        next.questions[index].userAnswer = answer
        update(next)
    }

    func toggleFlag(for questionID: Int) {
        guard let index = state.questions.firstIndex(where: { $0.id == questionID }) else { return }
        var next = state
        next.questions[index].isFlagged.toggle()
        update(next)
    }

    func setWritingResponse(_ response: String) {
        var next = state
        next.writingResponse = response
        update(next)
    }

    func addHighlight(location: Int, length: Int) {
        guard location >= 0, length > 0 else { return }
        let end = location.addingReportingOverflow(length)
        guard !end.overflow, end.partialValue <= (state.readingPassageText as NSString).length else { return }
        var next = state
        next.highlights.append(HighlightRange(rangeLocation: location, rangeLength: length))
        update(next)
    }

    func clearHighlights() {
        var next = state
        next.highlights.removeAll()
        update(next)
    }

    func startOver() {
        store.clear()
        persistenceError = nil
        isScreenHiddenForBreak = false
        state = ExamSessionState()
        persist()
    }

    private func update(_ newState: ExamSessionState) {
        var updated = newState
        updated.updatedAt = Date()
        state = updated
        persist()
    }

    private func persist() {
        do {
            try store.save(state)
            persistenceError = nil
        } catch {
            persistenceError = "Your latest changes could not be saved locally: \(error.localizedDescription)"
        }
    }

    private func settleExpiredTimer() {
        guard state.phase.isTimed,
              let deadline = state.deadline,
              deadline <= Date() else { return }
        var next = state
        advanceExpiredSections(in: &next, now: Date())
        state = next
        persist()
    }

    private func advanceExpiredSections(in next: inout ExamSessionState, now: Date) {
        guard var deadline = next.deadline else { return }
        while next.phase.isTimed && deadline <= now {
            next.phase = nextPhase(after: next.phase)
            next.currentQuestionIndex = 0
            guard next.phase.isTimed else {
                next.remainingSeconds = 0
                next.deadline = nil
                return
            }
            deadline = deadline.addingTimeInterval(TimeInterval(duration(for: next.phase)))
            next.deadline = deadline
        }
        next.remainingSeconds = max(Int(ceil(deadline.timeIntervalSince(now))), 0)
    }

    private func duration(for phase: ExamPhase) -> Int {
        switch phase {
        case .listening: 30 * 60
        case .listeningReview: 2 * 60
        case .reading, .writing: 60 * 60
        default: 0
        }
    }

    private func nextPhase(after phase: ExamPhase) -> ExamPhase {
        switch phase {
        case .listening: .listeningReview
        case .listeningReview: .reading
        case .reading: .writing
        case .writing: .completed
        default: .completed
        }
    }
}
