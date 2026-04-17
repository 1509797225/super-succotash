import Foundation

enum TodoTaskCycle: String, Codable, CaseIterable, Identifiable {
    case once
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .once:
            return "Once"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        }
    }
}

enum FocusTimerDirection: String, Codable, CaseIterable, Identifiable {
    case countDown
    case countUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .countDown:
            return "Count Down"
        case .countUp:
            return "Count Up"
        }
    }

    var shortTitle: String {
        switch self {
        case .countDown:
            return "Down"
        case .countUp:
            return "Up"
        }
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    let createdAt: Date
    var updatedAt: Date
    var taskDate: Date
    var cycle: TodoTaskCycle
    var dailyDurationMinutes: Int
    var focusTimerDirection: FocusTimerDirection
    var note: String

    init(
        id: UUID,
        title: String,
        isCompleted: Bool,
        createdAt: Date,
        updatedAt: Date,
        taskDate: Date,
        cycle: TodoTaskCycle = .daily,
        dailyDurationMinutes: Int = 25,
        focusTimerDirection: FocusTimerDirection = .countDown,
        note: String = ""
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.taskDate = taskDate
        self.cycle = cycle
        self.dailyDurationMinutes = dailyDurationMinutes
        self.focusTimerDirection = focusTimerDirection
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isCompleted
        case createdAt
        case updatedAt
        case taskDate
        case cycle
        case dailyDurationMinutes
        case focusTimerDirection
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        taskDate = try container.decode(Date.self, forKey: .taskDate)
        cycle = try container.decodeIfPresent(TodoTaskCycle.self, forKey: .cycle) ?? .daily
        dailyDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyDurationMinutes) ?? 25
        focusTimerDirection = try container.decodeIfPresent(FocusTimerDirection.self, forKey: .focusTimerDirection) ?? .countDown
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

enum PomodoroSessionType: String, Codable, CaseIterable {
    case focus
    case shortBreak
    case longBreak
}

enum PomodoroTimerMode: String, Codable, CaseIterable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            return "Focus"
        case .shortBreak:
            return "Short Break"
        case .longBreak:
            return "Long Break"
        }
    }

    var defaultDuration: Int {
        switch self {
        case .focus:
            return 25 * 60
        case .shortBreak:
            return 5 * 60
        case .longBreak:
            return 15 * 60
        }
    }

    var sessionType: PomodoroSessionType {
        switch self {
        case .focus:
            return .focus
        case .shortBreak:
            return .shortBreak
        case .longBreak:
            return .longBreak
        }
    }
}

struct PomodoroSession: Identifiable, Codable, Equatable {
    let id: UUID
    let type: PomodoroSessionType
    let startAt: Date
    let endAt: Date
    let durationSeconds: Int
    let relatedTodoID: UUID?
}

struct UserProfile: Codable, Equatable {
    var nickname: String
    var signature: String
    var dailyGoal: Int

    static let `default` = UserProfile(nickname: "", signature: "", dailyGoal: 4)
}

enum AppThemeMode: String, Codable, CaseIterable, Identifiable {
    case pink
    case blackWhite = "pureWhite"
    case blue
    case green
    case rainbow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pink:
            return "Pink"
        case .blackWhite:
            return "Black White"
        case .blue:
            return "Blue"
        case .green:
            return "Green"
        case .rainbow:
            return "Rainbow"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.pink.rawValue:
            self = .pink
        case Self.blue.rawValue:
            self = .blue
        case Self.green.rawValue:
            self = .green
        case Self.rainbow.rawValue:
            self = .rainbow
        case Self.blackWhite.rawValue, "softGray", "followSystem":
            self = .blackWhite
        default:
            self = .blackWhite
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct AppSettings: Codable, Equatable {
    var themeMode: AppThemeMode
    var hapticsEnabled: Bool
    var pomodoroGoalPerDay: Int
    var useLargeText: Bool

    static let `default` = AppSettings(
        themeMode: .blackWhite,
        hapticsEnabled: true,
        pomodoroGoalPerDay: 4,
        useLargeText: true
    )
}

enum PomodoroStatsRange: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

struct TodoDaySection: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let items: [TodoItem]
}

struct PomodoroTimerState: Equatable {
    var mode: PomodoroTimerMode = .focus
    var direction: FocusTimerDirection = .countDown
    var totalSeconds: Int = PomodoroTimerMode.focus.defaultDuration
    var remainingSeconds: Int = PomodoroTimerMode.focus.defaultDuration
    var elapsedSeconds: Int = 0
    var isRunning = false
    var isPaused = false
    var startedAt: Date?
    var relatedTodoID: UUID?
    var completedFocusCount = 0

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        switch direction {
        case .countDown:
            return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
        case .countUp:
            return Double(elapsedSeconds) / Double(totalSeconds)
        }
    }

    var displaySeconds: Int {
        switch direction {
        case .countDown:
            return remainingSeconds
        case .countUp:
            return elapsedSeconds
        }
    }
}

struct PomodoroStats: Equatable {
    let focusSeconds: Int
    let breakSeconds: Int
    let completedPomodoros: Int
    let goalRate: Double

    static let empty = PomodoroStats(
        focusSeconds: 0,
        breakSeconds: 0,
        completedPomodoros: 0,
        goalRate: 0
    )
}

struct DonutChartSegment: Identifiable, Equatable {
    let id = UUID()
    let value: Double
    let label: String
    let opacity: Double
}

struct TaskFocusSummary: Identifiable, Equatable {
    let id: UUID
    let title: String
    let seconds: Int
}
