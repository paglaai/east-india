import Foundation

enum ExamPhase: String, Codable, CaseIterable {
    case intro
    case familiarisation
    case finalInstructions
    case listening
    case listeningReview
    case reading
    case writing
    case completed

    var title: String {
        switch self {
        case .intro: "Welcome"
        case .familiarisation: "Get familiar with the test"
        case .finalInstructions: "Final instructions"
        case .listening: "Listening"
        case .listeningReview: "Listening review"
        case .reading: "Reading"
        case .writing: "Writing"
        case .completed: "Practice complete"
        }
    }

    var isTimed: Bool {
        switch self {
        case .listening, .listeningReview, .reading, .writing: true
        default: false
        }
    }
}

struct HighlightRange: Identifiable, Codable, Equatable {
    var id = UUID()
    let rangeLocation: Int
    let rangeLength: Int
}

struct ExamQuestion: Identifiable, Codable, Equatable {
    let id: Int
    let number: Int
    let prompt: String
    let options: [String]?
    var userAnswer = ""
    var isFlagged = false
}

struct ExamSessionState: Codable {
    var phase: ExamPhase = .intro
    var remainingSeconds = 0
    var deadline: Date?
    var currentQuestionIndex = 0
    var questions = ExamSessionState.sampleQuestions
    var readingPassageTitle = "The History of Maritime Navigation"
    var readingPassageText = """
    For centuries, mariners relied on celestial navigation and coastal landmarks to traverse the world's oceans. While determining latitude was relatively straightforward by measuring the angle of the sun or pole star above the horizon, calculating longitude remained one of the greatest scientific challenges of the 18th century.

    Without a reliable method to track time at sea, ships frequently lost their bearings, leading to catastrophic shipwrecks and disrupted trade routes. It was not until the invention of the marine chronometer that navigators could accurately compare local solar time with the time at a known reference point, thereby solving the longitude problem.
    """
    var highlights: [HighlightRange] = []
    var writingPrompt = """
    Some people believe that technological tools in education reduce face-to-face human interaction, while others argue they make learning far more accessible.

    Discuss both views and give your own opinion. Write at least 250 words.
    """
    var writingResponse = ""
    var updatedAt = Date()

    static let sampleQuestions: [ExamQuestion] = [
        ExamQuestion(
            id: 1,
            number: 1,
            prompt: "Determining latitude required measuring the angle of celestial bodies above the _________.",
            options: nil
        ),
        ExamQuestion(
            id: 2,
            number: 2,
            prompt: "Which invention finally resolved the longitude problem?",
            options: ["The astrolabe", "The marine chronometer", "The magnetic compass", "Celestial charts"]
        ),
        ExamQuestion(
            id: 3,
            number: 3,
            prompt: "Calculating longitude was easier than calculating latitude in the 18th century.",
            options: ["TRUE", "FALSE", "NOT GIVEN"]
        )
    ]
}
