import Foundation

struct StorageSnapshot: Codable, Equatable {
    var todos: [TodoItem]
    var planTasks: [PlanTask]
    var pomodoroSessions: [PomodoroSession]
    var checkInRecords: [DailyCheckInRecord]
    var profile: UserProfile
    var settings: AppSettings
}

struct StorageClient {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    enum Key: String {
        case todos = "todo.items"
        case planTasks = "plan.tasks"
        case pomodoroSessions = "pomodoro.sessions"
        case checkInRecords = "checkin.records"
        case userProfile = "user.profile"
        case appSettings = "app.settings"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load<T: Codable>(_ type: T.Type, for key: Key) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Codable>(_ value: T, for key: Key) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }

    func loadSnapshot() -> StorageSnapshot {
        StorageSnapshot(
            todos: load([TodoItem].self, for: .todos) ?? [],
            planTasks: load([PlanTask].self, for: .planTasks) ?? [],
            pomodoroSessions: load([PomodoroSession].self, for: .pomodoroSessions) ?? [],
            checkInRecords: load([DailyCheckInRecord].self, for: .checkInRecords) ?? [],
            profile: load(UserProfile.self, for: .userProfile) ?? .default,
            settings: load(AppSettings.self, for: .appSettings) ?? .default
        )
    }
}
