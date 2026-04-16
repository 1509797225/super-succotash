import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    let createdAt: Date
    var updatedAt: Date
    var taskDate: Date
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
    case pureWhite
    case softGray
    case followSystem

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pureWhite:
            return "Pure White"
        case .softGray:
            return "Soft Gray"
        case .followSystem:
            return "Follow System"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var themeMode: AppThemeMode
    var hapticsEnabled: Bool
    var pomodoroGoalPerDay: Int
    var useLargeText: Bool

    static let `default` = AppSettings(
        themeMode: .pureWhite,
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
    var totalSeconds: Int = PomodoroTimerMode.focus.defaultDuration
    var remainingSeconds: Int = PomodoroTimerMode.focus.defaultDuration
    var isRunning = false
    var isPaused = false
    var startedAt: Date?
    var relatedTodoID: UUID?
    var completedFocusCount = 0

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
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
