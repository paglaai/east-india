import Foundation

struct SessionStore {
    private let defaults: UserDefaults
    private let storageKey = "east-india.exam-session.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> ExamSessionState? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try JSONDecoder().decode(ExamSessionState.self, from: data)
    }

    func save(_ state: ExamSessionState) throws {
        let data = try JSONEncoder().encode(state)
        defaults.set(data, forKey: storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}
