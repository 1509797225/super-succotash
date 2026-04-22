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

enum EntitlementTier: String, Codable, CaseIterable, Identifiable {
    case free
    case pro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        }
    }
}

struct EntitlementState: Codable, Equatable {
    var tier: EntitlementTier
    var cloudSyncEnabled: Bool
    var expiresAt: Date?

    var isCloudSyncAvailable: Bool {
        tier == .pro && cloudSyncEnabled
    }

    static let `default` = EntitlementState(
        tier: .free,
        cloudSyncEnabled: false,
        expiresAt: nil
    )
}

struct CloudIdentity: Codable, Equatable {
    let userID: String
    let deviceID: String
    let createdAt: Date

    var shortUserID: String {
        String(userID.prefix(8))
    }
}

enum AuthProvider: String, Codable, Equatable {
    case apple
}

enum AccountStatus: String, Codable, Equatable {
    case signedOut
    case signingIn
    case signedIn
    case failed
}

struct AccountUser: Codable, Equatable {
    let id: String
    var email: String?
    var nickname: String

    var shortID: String {
        String(id.prefix(8))
    }
}

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct AccountMigrationResult: Codable, Equatable {
    let anonymousUserID: String?
    let migrated: Bool
    let plans: Int
    let todos: Int
    let sessions: Int
    let backups: Int
}

struct AccountState: Codable, Equatable {
    var user: AccountUser?
    var provider: AuthProvider?
    var status: AccountStatus
    var message: String
    var lastMigration: AccountMigrationResult?

    var isSignedIn: Bool {
        user != nil && status == .signedIn
    }

    static let signedOut = AccountState(
        user: nil,
        provider: nil,
        status: .signedOut,
        message: "Not signed in",
        lastMigration: nil
    )
}

enum StoreKitSubscriptionState: String, Codable, CaseIterable {
    case idle
    case loading
    case active
    case notSubscribed
    case productsUnavailable
    case pending
    case failed

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .loading:
            return "Loading"
        case .active:
            return "Active"
        case .notSubscribed:
            return "Not Subscribed"
        case .productsUnavailable:
            return "Products Unavailable"
        case .pending:
            return "Pending"
        case .failed:
            return "Failed"
        }
    }
}

struct StoreKitEntitlementSnapshot: Codable, Equatable {
    let state: StoreKitSubscriptionState
    let availableProductIDs: [String]
    let activeProductID: String?
    let transaction: StoreKitTransactionPayload?
    let message: String

    init(
        state: StoreKitSubscriptionState,
        availableProductIDs: [String],
        activeProductID: String?,
        transaction: StoreKitTransactionPayload? = nil,
        message: String
    ) {
        self.state = state
        self.availableProductIDs = availableProductIDs
        self.activeProductID = activeProductID
        self.transaction = transaction
        self.message = message
    }

    static let idle = StoreKitEntitlementSnapshot(
        state: .idle,
        availableProductIDs: [],
        activeProductID: nil,
        message: "StoreKit has not loaded yet"
    )
}

struct StoreKitTransactionPayload: Codable, Equatable {
    let productID: String
    let transactionID: String
    let originalTransactionID: String
    let expirationDate: Date?
    let environment: String
    let signedTransactionJWS: String
}

enum SyncDirection: String, Codable, CaseIterable {
    case push
    case pull
    case full
    case restore
    case backup

    var title: String {
        switch self {
        case .push:
            return "Push"
        case .pull:
            return "Pull"
        case .full:
            return "Full"
        case .restore:
            return "Restore"
        case .backup:
            return "Backup"
        }
    }
}

enum SyncStatus: String, Codable, CaseIterable {
    case success
    case failed
    case skipped

    var title: String {
        switch self {
        case .success:
            return "Success"
        case .failed:
            return "Failed"
        case .skipped:
            return "Skipped"
        }
    }
}

struct SyncHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let direction: SyncDirection
    let status: SyncStatus
    let changedCount: Int
    let message: String
    let createdAt: Date
}

struct LocalBackupSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    let reason: String
    let snapshotPath: String
    let plansCount: Int
    let todosCount: Int
    let sessionsCount: Int
    let createdAt: Date
}

struct CloudBackupSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    let reason: String
    let plansCount: Int
    let todosCount: Int
    let sessionsCount: Int
    let createdAt: Date
}

struct ChangeLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let entityType: String
    let entityID: String
    let operation: String
    let payload: String
    let createdAt: Date
}

enum PomodoroStatsRange: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case year

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
            case .year:
                return "今年"
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
    var totalSeconds: Int = 0
    var remainingSeconds: Int = 0
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
    let completedPomodoros: Int
    let goalRate: Double

    static let empty = PomodoroStats(
        focusSeconds: 0,
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

struct PlanFocusSegment: Identifiable, Equatable {
    let id: UUID
    let title: String
    let seconds: Int
    let itemCount: Int
}

struct FocusTimeBucket: Identifiable, Equatable {
    let id: String
    let label: String
    let seconds: Int
}

struct TaskFocusSummary: Identifiable, Equatable {
    let id: UUID
    let title: String
    let seconds: Int
}

#if DEBUG
struct DatabaseDebugSummary: Equatable {
    let plans: Int
    let todos: Int
    let todayTodos: Int
    let sessions: Int
    let entitlement: EntitlementState
}

enum CloudDebugState: Equatable {
    case idle
    case loading(String)
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .idle:
            return "Cloud staging is ready for API checks and pull tests."
        case .loading(let message), .success(let message), .failure(let message):
            return message
        }
    }
}
#endif
