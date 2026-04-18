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

    func title(language: AppLanguage) -> String {
        switch language {
        case .english:
            return title
        case .chinese:
            switch self {
            case .once:
                return "一次"
            case .daily:
                return "每天"
            case .weekly:
                return "每周"
            case .monthly:
                return "每月"
            }
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

    func title(language: AppLanguage) -> String {
        switch language {
        case .english:
            return title
        case .chinese:
            switch self {
            case .countDown:
                return "倒计时"
            case .countUp:
                return "正计时"
            }
        }
    }

    func shortTitle(language: AppLanguage) -> String {
        switch language {
        case .english:
            return shortTitle
        case .chinese:
            switch self {
            case .countDown:
                return "倒"
            case .countUp:
                return "正"
            }
        }
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var planTaskID: UUID?
    var isAddedToToday: Bool
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
        planTaskID: UUID? = nil,
        isAddedToToday: Bool = true,
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
        self.planTaskID = planTaskID
        self.isAddedToToday = isAddedToToday
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
        case planTaskID
        case isAddedToToday
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
        planTaskID = try container.decodeIfPresent(UUID.self, forKey: .planTaskID)
        isAddedToToday = try container.decodeIfPresent(Bool.self, forKey: .isAddedToToday) ?? true
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

struct PlanTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var isCollapsed: Bool
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

    func title(language: AppLanguage) -> String {
        switch language {
        case .english:
            return title
        case .chinese:
            switch self {
            case .focus:
                return "专注"
            case .shortBreak:
                return "短休息"
            case .longBreak:
                return "长休息"
            }
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

    func title(language: AppLanguage) -> String {
        switch language {
        case .english:
            return title
        case .chinese:
            switch self {
            case .pink:
                return "粉色"
            case .blackWhite:
                return "黑白"
            case .blue:
                return "蓝色"
            case .green:
                return "绿色"
            case .rainbow:
                return "彩虹"
            }
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

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "简体中文"
        }
    }

    var localeIdentifier: String { rawValue }
}

struct AppSettings: Codable, Equatable {
    var themeMode: AppThemeMode
    var hapticsEnabled: Bool
    var pomodoroGoalPerDay: Int
    var useLargeText: Bool
    var language: AppLanguage

    static let `default` = AppSettings(
        themeMode: .blackWhite,
        hapticsEnabled: true,
        pomodoroGoalPerDay: 4,
        useLargeText: true,
        language: .english
    )

    private enum CodingKeys: String, CodingKey {
        case themeMode
        case hapticsEnabled
        case pomodoroGoalPerDay
        case useLargeText
        case language
    }

    init(
        themeMode: AppThemeMode,
        hapticsEnabled: Bool,
        pomodoroGoalPerDay: Int,
        useLargeText: Bool,
        language: AppLanguage
    ) {
        self.themeMode = themeMode
        self.hapticsEnabled = hapticsEnabled
        self.pomodoroGoalPerDay = pomodoroGoalPerDay
        self.useLargeText = useLargeText
        self.language = language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        themeMode = try container.decodeIfPresent(AppThemeMode.self, forKey: .themeMode) ?? .blackWhite
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        pomodoroGoalPerDay = try container.decodeIfPresent(Int.self, forKey: .pomodoroGoalPerDay) ?? 4
        useLargeText = try container.decodeIfPresent(Bool.self, forKey: .useLargeText) ?? true
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
    }
}

enum PomodoroStatsRange: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    func title(language: AppLanguage) -> String {
        switch language {
        case .english:
            return title
        case .chinese:
            switch self {
            case .today:
                return "今日"
            case .week:
                return "本周"
            case .month:
                return "本月"
            }
        }
    }
}

struct TodoDaySection: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let items: [TodoItem]
}

struct PlanTaskSection: Identifiable, Equatable {
    var id: UUID { task.id }
    let task: PlanTask
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
