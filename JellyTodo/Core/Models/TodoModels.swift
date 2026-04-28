import Foundation

enum TodoTaskCycle: String, Codable, CaseIterable, Identifiable {
    case manual
    case once
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual:
            return "Manual"
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
            case .manual:
                return "手动"
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

enum TodoScheduleMode: String, Codable, CaseIterable, Identifiable {
    case custom
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch language {
        case .english:
            switch self {
            case .custom:
                return "Custom"
            case .daily:
                return "Daily"
            case .weekly:
                return "Weekly"
            case .monthly:
                return "Monthly"
            }
        case .chinese:
            switch self {
            case .custom:
                return "自定义"
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
    var sourceTemplateID: UUID?
    var isAddedToToday: Bool
    var title: String
    var isCompleted: Bool
    let createdAt: Date
    var updatedAt: Date
    var taskDate: Date
    var cycle: TodoTaskCycle
    var scheduleMode: TodoScheduleMode
    var recurrenceValue: Int?
    var scheduledDates: [Date]
    var dailyDurationMinutes: Int
    var focusTimerDirection: FocusTimerDirection
    var note: String

    init(
        id: UUID,
        planTaskID: UUID? = nil,
        sourceTemplateID: UUID? = nil,
        isAddedToToday: Bool = true,
        title: String,
        isCompleted: Bool,
        createdAt: Date,
        updatedAt: Date,
        taskDate: Date,
        cycle: TodoTaskCycle = .daily,
        scheduleMode: TodoScheduleMode? = nil,
        recurrenceValue: Int? = nil,
        scheduledDates: [Date] = [],
        dailyDurationMinutes: Int = 25,
        focusTimerDirection: FocusTimerDirection = .countDown,
        note: String = ""
    ) {
        self.id = id
        self.planTaskID = planTaskID
        self.sourceTemplateID = sourceTemplateID
        self.isAddedToToday = isAddedToToday
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.taskDate = taskDate
        self.cycle = cycle
        let normalizedDates = Self.normalizedScheduledDates(from: scheduledDates)
        let inferredRule = Self.inferScheduleRule(from: normalizedDates, cycle: cycle, taskDate: taskDate)
        self.scheduleMode = scheduleMode ?? inferredRule.mode
        self.recurrenceValue = recurrenceValue ?? inferredRule.value
        self.scheduledDates = normalizedDates
        self.dailyDurationMinutes = dailyDurationMinutes
        self.focusTimerDirection = focusTimerDirection
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case planTaskID
        case sourceTemplateID
        case isAddedToToday
        case title
        case isCompleted
        case createdAt
        case updatedAt
        case taskDate
        case cycle
        case scheduleMode
        case recurrenceValue
        case scheduledDates
        case dailyDurationMinutes
        case focusTimerDirection
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        planTaskID = try container.decodeIfPresent(UUID.self, forKey: .planTaskID)
        sourceTemplateID = try container.decodeIfPresent(UUID.self, forKey: .sourceTemplateID)
        isAddedToToday = try container.decodeIfPresent(Bool.self, forKey: .isAddedToToday) ?? true
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        taskDate = try container.decode(Date.self, forKey: .taskDate)
        cycle = try container.decodeIfPresent(TodoTaskCycle.self, forKey: .cycle) ?? .daily
        let decodedDates = Self.normalizedScheduledDates(
            from: try container.decodeIfPresent([Date].self, forKey: .scheduledDates) ?? []
        )
        let explicitMode = try container.decodeIfPresent(TodoScheduleMode.self, forKey: .scheduleMode)
        let explicitValue = try container.decodeIfPresent(Int.self, forKey: .recurrenceValue)
        let inferredRule = Self.inferScheduleRule(from: decodedDates, cycle: cycle, taskDate: taskDate)
        scheduleMode = explicitMode ?? inferredRule.mode
        recurrenceValue = explicitValue ?? inferredRule.value
        scheduledDates = decodedDates
        dailyDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyDurationMinutes) ?? 25
        focusTimerDirection = try container.decodeIfPresent(FocusTimerDirection.self, forKey: .focusTimerDirection) ?? .countDown
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    private static func normalizedScheduledDates(from dates: [Date]) -> [Date] {
        let calendar = Calendar.current
        let normalized = dates.map { calendar.startOfDay(for: $0) }
        let unique = Set(normalized.map(\.timeIntervalSinceReferenceDate))
            .map(Date.init(timeIntervalSinceReferenceDate:))
        return unique.sorted()
    }

    private static func inferScheduleRule(from dates: [Date], cycle: TodoTaskCycle, taskDate: Date) -> (mode: TodoScheduleMode, value: Int?) {
        let calendar = Calendar.current

        if dates.isEmpty {
            switch cycle {
            case .daily:
                return (.daily, nil)
            case .weekly:
                return (.weekly, calendar.component(.weekday, from: taskDate))
            case .monthly:
                return (.monthly, calendar.component(.day, from: taskDate))
            case .manual, .once:
                return (.custom, nil)
            }
        }

        if dates.count >= 3, isDailySeries(dates) {
            return (.daily, nil)
        }

        if dates.count >= 3, let weekday = weeklySeriesWeekday(dates) {
            return (.weekly, weekday)
        }

        if dates.count >= 3, let day = monthlySeriesDay(dates) {
            return (.monthly, day)
        }

        return (.custom, nil)
    }

    private static func isDailySeries(_ dates: [Date]) -> Bool {
        let calendar = Calendar.current
        for pair in zip(dates, dates.dropFirst()) {
            guard let delta = calendar.dateComponents([.day], from: pair.0, to: pair.1).day, delta == 1 else {
                return false
            }
        }
        return true
    }

    private static func weeklySeriesWeekday(_ dates: [Date]) -> Int? {
        let calendar = Calendar.current
        guard let first = dates.first else { return nil }
        let weekday = calendar.component(.weekday, from: first)
        for pair in zip(dates, dates.dropFirst()) {
            let currentWeekday = calendar.component(.weekday, from: pair.1)
            guard currentWeekday == weekday,
                  let delta = calendar.dateComponents([.day], from: pair.0, to: pair.1).day,
                  delta == 7
            else {
                return nil
            }
        }
        return weekday
    }

    private static func monthlySeriesDay(_ dates: [Date]) -> Int? {
        let calendar = Calendar.current
        guard let first = dates.first else { return nil }
        let firstDay = calendar.component(.day, from: first)

        for pair in zip(dates, dates.dropFirst()) {
            let next = pair.1
            let range = calendar.range(of: .day, in: .month, for: next) ?? 1..<32
            let expectedDay = min(firstDay, range.upperBound - 1)
            let actualDay = calendar.component(.day, from: next)
            let monthDelta = calendar.dateComponents([.month], from: pair.0, to: next).month
            guard monthDelta == 1, actualDay == expectedDay else {
                return nil
            }
        }

        return firstDay
    }
}

extension TodoItem {
    var isPlanTemplate: Bool {
        planTaskID != nil && sourceTemplateID == nil && !isAddedToToday
    }

    var isTodayOccurrence: Bool {
        sourceTemplateID != nil && isAddedToToday
    }

    var hasExplicitSchedule: Bool {
        scheduleMode == .custom && !scheduledDates.isEmpty
    }

    func normalizedScheduledDates() -> [Date] {
        let calendar = Calendar.current
        let unique = Set(scheduledDates.map { calendar.startOfDay(for: $0).timeIntervalSinceReferenceDate })
        return unique.map(Date.init(timeIntervalSinceReferenceDate:)).sorted()
    }

    func scheduleSummary(language: AppLanguage, limit: Int = 3) -> String {
        switch scheduleMode {
        case .daily:
            return scheduleMode.title(language: language)
        case .weekly:
            return weeklySummary(language: language)
        case .monthly:
            return monthlySummary(language: language)
        case .custom:
            break
        }

        let dates = normalizedScheduledDates()
        guard !dates.isEmpty else {
            return cycle.title(language: language)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = language == .english ? "MMM d" : "M月d日"

        let titles = dates.prefix(limit).map { formatter.string(from: $0) }
        let suffixCount = dates.count - titles.count
        let joined = titles.joined(separator: language == .english ? ", " : "、")

        if suffixCount > 0 {
            return language == .english ? "\(joined) +\(suffixCount)" : "\(joined) 等\(dates.count)天"
        }
        return joined
    }

    func editorPreviewDates(from referenceDate: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)

        switch scheduleMode {
        case .daily:
            return (0..<90).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .weekly:
            guard let weekday = recurrenceValue else { return normalizedScheduledDates() }
            return nextWeeklyDates(weekday: weekday, from: start, count: 16)
        case .monthly:
            guard let day = recurrenceValue else { return normalizedScheduledDates() }
            return nextMonthlyDates(day: day, from: start, count: 12)
        case .custom:
            return normalizedScheduledDates()
        }
    }

    private func weeklySummary(language: AppLanguage) -> String {
        guard let recurrenceValue else {
            return scheduleMode.title(language: language)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        let symbols = language == .english
            ? (formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? [])
            : (formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? [])
        let index = max(min(recurrenceValue - 1, symbols.count - 1), 0)
        let day = symbols.isEmpty ? "\(recurrenceValue)" : symbols[index]
        return language == .english ? "Weekly \(day)" : "每周 \(day)"
    }

    private func monthlySummary(language: AppLanguage) -> String {
        guard let recurrenceValue else {
            return scheduleMode.title(language: language)
        }
        return language == .english ? "Monthly \(recurrenceValue)" : "每月 \(recurrenceValue)号"
    }

    private func nextWeeklyDates(weekday: Int, from start: Date, count: Int) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var cursor = start

        while dates.count < count {
            if calendar.component(.weekday, from: cursor) == weekday {
                dates.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
    }

    private func nextMonthlyDates(day: Int, from start: Date, count: Int) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []

        for offset in 0..<count {
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: start),
                  let monthRange = calendar.range(of: .day, in: .month, for: monthDate),
                  let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))
            else { continue }

            let targetDay = min(day, monthRange.count)
            if let targetDate = calendar.date(byAdding: .day, value: targetDay - 1, to: monthStart), targetDate >= start {
                dates.append(targetDate)
            }
        }

        return dates
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
    let sourceTemplateID: UUID?
    let planTaskID: UUID?
    let planTitleSnapshot: String
    let todoTitleSnapshot: String

    init(
        id: UUID,
        type: PomodoroSessionType,
        startAt: Date,
        endAt: Date,
        durationSeconds: Int,
        relatedTodoID: UUID?,
        sourceTemplateID: UUID? = nil,
        planTaskID: UUID? = nil,
        planTitleSnapshot: String = "",
        todoTitleSnapshot: String = ""
    ) {
        self.id = id
        self.type = type
        self.startAt = startAt
        self.endAt = endAt
        self.durationSeconds = durationSeconds
        self.relatedTodoID = relatedTodoID
        self.sourceTemplateID = sourceTemplateID
        self.planTaskID = planTaskID
        self.planTitleSnapshot = planTitleSnapshot
        self.todoTitleSnapshot = todoTitleSnapshot
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case startAt
        case endAt
        case durationSeconds
        case relatedTodoID
        case sourceTemplateID
        case planTaskID
        case planTitleSnapshot
        case todoTitleSnapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(PomodoroSessionType.self, forKey: .type)
        startAt = try container.decode(Date.self, forKey: .startAt)
        endAt = try container.decode(Date.self, forKey: .endAt)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        relatedTodoID = try container.decodeIfPresent(UUID.self, forKey: .relatedTodoID)
        sourceTemplateID = try container.decodeIfPresent(UUID.self, forKey: .sourceTemplateID)
        planTaskID = try container.decodeIfPresent(UUID.self, forKey: .planTaskID)
        planTitleSnapshot = try container.decodeIfPresent(String.self, forKey: .planTitleSnapshot) ?? ""
        todoTitleSnapshot = try container.decodeIfPresent(String.self, forKey: .todoTitleSnapshot) ?? ""
    }
}

struct UserProfile: Codable, Equatable {
    var nickname: String
    var signature: String
    var dailyGoal: Int

    static let `default` = UserProfile(nickname: "", signature: "", dailyGoal: 4)
}

enum AppThemeColor: String, Codable, CaseIterable, Identifiable {
    case pink
    case blackWhite = "pureWhite"
    case blue
    case green

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
            }
        }
    }
}

enum AppThemeStyle: String, Codable, CaseIterable, Identifiable {
    case solid
    case jelly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid:
            return "Solid"
        case .jelly:
            return "Jelly"
        }
    }

    func title(language: AppLanguage) -> String {
        switch language {
        case .english:
            return title
        case .chinese:
            switch self {
            case .solid:
                return "素色"
            case .jelly:
                return "果冻"
            }
        }
    }
}

enum AppThemeMode: String, Codable, CaseIterable, Identifiable {
    case pink
    case blackWhite = "pureWhite"
    case blue
    case green
    case pinkJelly
    case blackWhiteJelly
    case blueJelly
    case greenJelly

    var id: String { rawValue }

    var title: String {
        "\(color.title) \(style.title)"
    }

    func title(language: AppLanguage) -> String {
        "\(color.title(language: language)) · \(style.title(language: language))"
    }

    var color: AppThemeColor {
        switch self {
        case .pink, .pinkJelly:
            return .pink
        case .blackWhite, .blackWhiteJelly:
            return .blackWhite
        case .blue, .blueJelly:
            return .blue
        case .green, .greenJelly:
            return .green
        }
    }

    var style: AppThemeStyle {
        switch self {
        case .pink, .blackWhite, .blue, .green:
            return .solid
        case .pinkJelly, .blackWhiteJelly, .blueJelly, .greenJelly:
            return .jelly
        }
    }

    var isJelly: Bool {
        style == .jelly
    }

    static func make(color: AppThemeColor, style: AppThemeStyle) -> AppThemeMode {
        switch (color, style) {
        case (.pink, .solid):
            return .pink
        case (.pink, .jelly):
            return .pinkJelly
        case (.blackWhite, .solid):
            return .blackWhite
        case (.blackWhite, .jelly):
            return .blackWhiteJelly
        case (.blue, .solid):
            return .blue
        case (.blue, .jelly):
            return .blueJelly
        case (.green, .solid):
            return .green
        case (.green, .jelly):
            return .greenJelly
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
        case Self.pinkJelly.rawValue:
            self = .pinkJelly
        case Self.blackWhiteJelly.rawValue:
            self = .blackWhiteJelly
        case Self.blueJelly.rawValue:
            self = .blueJelly
        case Self.greenJelly.rawValue:
            self = .greenJelly
        case Self.blackWhite.rawValue, "softGray", "followSystem":
            self = .blackWhite
        case "rainbow":
            self = .pink
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

enum AppTextScale: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        }
    }

    func title(language: AppLanguage) -> String {
        switch language {
        case .english:
            return title
        case .chinese:
            switch self {
            case .small:
                return "小"
            case .medium:
                return "中"
            case .large:
                return "大"
            }
        }
    }

    var typographyScale: CGFloat {
        switch self {
        case .small:
            return 0.9
        case .medium:
            return 1.0
        case .large:
            return 1.12
        }
    }

    var layoutScale: CGFloat {
        switch self {
        case .small:
            return 0.94
        case .medium:
            return 1.0
        case .large:
            return 1.1
        }
    }
}

struct AppSettings: Codable, Equatable {
    var themeMode: AppThemeMode
    var hapticsEnabled: Bool
    var pomodoroGoalPerDay: Int
    var textScale: AppTextScale
    var language: AppLanguage

    static let `default` = AppSettings(
        themeMode: .blackWhite,
        hapticsEnabled: true,
        pomodoroGoalPerDay: 4,
        textScale: .medium,
        language: .english
    )

    private enum CodingKeys: String, CodingKey {
        case themeMode
        case hapticsEnabled
        case pomodoroGoalPerDay
        case textScale
        case useLargeText
        case language
    }

    init(
        themeMode: AppThemeMode,
        hapticsEnabled: Bool,
        pomodoroGoalPerDay: Int,
        textScale: AppTextScale,
        language: AppLanguage
    ) {
        self.themeMode = themeMode
        self.hapticsEnabled = hapticsEnabled
        self.pomodoroGoalPerDay = pomodoroGoalPerDay
        self.textScale = textScale
        self.language = language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        themeMode = try container.decodeIfPresent(AppThemeMode.self, forKey: .themeMode) ?? .blackWhite
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        pomodoroGoalPerDay = try container.decodeIfPresent(Int.self, forKey: .pomodoroGoalPerDay) ?? 4
        if let decodedScale = try container.decodeIfPresent(AppTextScale.self, forKey: .textScale) {
            textScale = decodedScale
        } else {
            let legacyLarge = try container.decodeIfPresent(Bool.self, forKey: .useLargeText) ?? true
            textScale = legacyLarge ? .large : .medium
        }
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(themeMode, forKey: .themeMode)
        try container.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try container.encode(pomodoroGoalPerDay, forKey: .pomodoroGoalPerDay)
        try container.encode(textScale, forKey: .textScale)
        try container.encode(textScale == .large, forKey: .useLargeText)
        try container.encode(language, forKey: .language)
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

struct PlanItemTodayState: Equatable {
    let occurrence: TodoItem?
    let isCompleted: Bool
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
