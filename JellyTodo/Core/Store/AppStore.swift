import Combine
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var pomodoroSessions: [PomodoroSession] = []
    @Published var profile: UserProfile = .default
    @Published var settings: AppSettings = .default
    @Published var timerState = PomodoroTimerState()

    private let storage: StorageClient
    private var timerCancellable: AnyCancellable?

    init(storage: StorageClient = StorageClient()) {
        self.storage = storage
        loadInitialState()
    }

    var preferredColorScheme: ColorScheme? {
        switch settings.themeMode {
        case .pureWhite, .softGray:
            return .light
        case .followSystem:
            return .light
        }
    }

    var todayTodos: [TodoItem] {
        todos
            .filter { Calendar.current.isDateInToday($0.taskDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var monthSections: [TodoDaySection] {
        let now = Date()
        let grouped = Dictionary(grouping: todos.filter {
            Calendar.current.isDate($0.taskDate, equalTo: now, toGranularity: .month)
        }) { item in
            Calendar.current.startOfDay(for: item.taskDate)
        }

        return grouped
            .map { key, value in
                TodoDaySection(
                    date: key,
                    items: value.sorted { $0.createdAt < $1.createdAt }
                )
            }
            .sorted { $0.date < $1.date }
    }

    var totalCompletedCount: Int {
        todos.filter(\.isCompleted).count
    }

    var totalPendingCount: Int {
        todos.filter { !$0.isCompleted }.count
    }

    func loadInitialState() {
        todos = storage.load([TodoItem].self, for: .todos) ?? []
        pomodoroSessions = storage.load([PomodoroSession].self, for: .pomodoroSessions) ?? []
        profile = storage.load(UserProfile.self, for: .userProfile) ?? .default
        settings = storage.load(AppSettings.self, for: .appSettings) ?? .default
        syncGoalIfNeeded()
        savePersistentState()
    }

    func addTodo(title: String, taskDate: Date = Date()) {
        let trimmed = sanitize(title)
        guard !trimmed.isEmpty else { return }

        let now = Date()
        todos.append(
            TodoItem(
                id: UUID(),
                title: trimmed,
                isCompleted: false,
                createdAt: now,
                updatedAt: now,
                taskDate: taskDate
            )
        )
        saveTodos()
    }

    func updateTodo(id: UUID, title: String) {
        let trimmed = sanitize(title)
        guard !trimmed.isEmpty, let index = todos.firstIndex(where: { $0.id == id }) else { return }

        todos[index].title = trimmed
        todos[index].updatedAt = Date()
        saveTodos()
    }

    func deleteTodo(id: UUID) {
        todos.removeAll { $0.id == id }
        saveTodos()
    }

    func toggleTodoCompleted(id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isCompleted.toggle()
        todos[index].updatedAt = Date()
        triggerHaptic()
        saveTodos()
    }

    func startPomodoro(mode: PomodoroTimerMode, relatedTodoID: UUID? = nil) {
        timerCancellable?.cancel()
        timerState.mode = mode
        timerState.totalSeconds = mode.defaultDuration
        timerState.remainingSeconds = mode.defaultDuration
        timerState.isRunning = true
        timerState.isPaused = false
        timerState.startedAt = Date()
        timerState.relatedTodoID = relatedTodoID
        beginTicking()
        triggerHaptic()
    }

    func pausePomodoro() {
        guard timerState.isRunning else { return }
        timerCancellable?.cancel()
        timerState.isRunning = false
        timerState.isPaused = true
        triggerHaptic()
    }

    func resumePomodoro() {
        guard timerState.isPaused else { return }
        timerState.isRunning = true
        timerState.isPaused = false
        beginTicking()
        triggerHaptic()
    }

    func stopPomodoro(discard: Bool) {
        timerCancellable?.cancel()
        if discard {
            resetTimer(for: timerState.mode)
        } else {
            completePomodoro()
        }
        triggerHaptic()
    }

    func completePomodoro() {
        timerCancellable?.cancel()

        let now = Date()
        let session = PomodoroSession(
            id: UUID(),
            type: timerState.mode.sessionType,
            startAt: timerState.startedAt ?? now.addingTimeInterval(TimeInterval(-timerState.totalSeconds)),
            endAt: now,
            durationSeconds: timerState.totalSeconds,
            relatedTodoID: timerState.relatedTodoID
        )

        pomodoroSessions.append(session)
        saveSessions()

        if timerState.mode == .focus {
            timerState.completedFocusCount += 1
            let nextMode: PomodoroTimerMode = timerState.completedFocusCount.isMultiple(of: 4) ? .longBreak : .shortBreak
            resetTimer(for: nextMode)
        } else {
            resetTimer(for: .focus)
        }

        triggerHaptic()
    }

    func updateProfile(_ profile: UserProfile) {
        self.profile = profile
        if settings.pomodoroGoalPerDay != profile.dailyGoal {
            settings.pomodoroGoalPerDay = profile.dailyGoal
            saveSettings()
        }
        saveProfile()
    }

    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        if profile.dailyGoal != settings.pomodoroGoalPerDay {
            profile.dailyGoal = settings.pomodoroGoalPerDay
            saveProfile()
        }
        saveSettings()
    }

    func stats(for range: PomodoroStatsRange) -> PomodoroStats {
        let sessions = sessions(in: range)
        guard !sessions.isEmpty else { return .empty }

        let focusSeconds = sessions
            .filter { $0.type == .focus }
            .reduce(0) { $0 + $1.durationSeconds }
        let breakSeconds = sessions
            .filter { $0.type != .focus }
            .reduce(0) { $0 + $1.durationSeconds }
        let completedPomodoros = sessions.filter { $0.type == .focus }.count
        let goal = max(settings.pomodoroGoalPerDay, 1)
        let goalRate = min(Double(completedPomodoros) / Double(goal), 1)

        return PomodoroStats(
            focusSeconds: focusSeconds,
            breakSeconds: breakSeconds,
            completedPomodoros: completedPomodoros,
            goalRate: goalRate
        )
    }

    func chartSegments(for range: PomodoroStatsRange) -> [DonutChartSegment] {
        let sessions = sessions(in: range)
        let focusValue = sessions.filter { $0.type == .focus }.reduce(0) { $0 + $1.durationSeconds }
        let shortBreakValue = sessions.filter { $0.type == .shortBreak }.reduce(0) { $0 + $1.durationSeconds }
        let longBreakValue = sessions.filter { $0.type == .longBreak }.reduce(0) { $0 + $1.durationSeconds }

        let total = focusValue + shortBreakValue + longBreakValue
        guard total > 0 else { return [] }

        return [
            DonutChartSegment(value: Double(focusValue), label: "Focus", opacity: 1.0),
            DonutChartSegment(value: Double(shortBreakValue), label: "Short Break", opacity: 0.72),
            DonutChartSegment(value: Double(longBreakValue), label: "Long Break", opacity: 0.44)
        ].filter { $0.value > 0 }
    }

    private func beginTicking() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.timerState.isRunning else { return }

                if self.timerState.remainingSeconds > 0 {
                    self.timerState.remainingSeconds -= 1
                }

                if self.timerState.remainingSeconds <= 0 {
                    self.completePomodoro()
                }
            }
    }

    private func resetTimer(for mode: PomodoroTimerMode) {
        timerCancellable?.cancel()
        timerState.mode = mode
        timerState.totalSeconds = mode.defaultDuration
        timerState.remainingSeconds = mode.defaultDuration
        timerState.isRunning = false
        timerState.isPaused = false
        timerState.startedAt = nil
        timerState.relatedTodoID = nil
    }

    private func sessions(in range: PomodoroStatsRange) -> [PomodoroSession] {
        let calendar = Calendar.current
        let now = Date()

        return pomodoroSessions.filter { session in
            switch range {
            case .today:
                return calendar.isDateInToday(session.endAt)
            case .week:
                return calendar.isDate(session.endAt, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(session.endAt, equalTo: now, toGranularity: .month)
            }
        }
    }

    private func syncGoalIfNeeded() {
        if profile.dailyGoal != settings.pomodoroGoalPerDay {
            profile.dailyGoal = settings.pomodoroGoalPerDay
        }
    }

    private func sanitize(_ title: String) -> String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
    }

    private func savePersistentState() {
        saveTodos()
        saveSessions()
        saveProfile()
        saveSettings()
    }

    private func saveTodos() {
        storage.save(todos, for: .todos)
    }

    private func saveSessions() {
        storage.save(pomodoroSessions, for: .pomodoroSessions)
    }

    private func saveProfile() {
        storage.save(profile, for: .userProfile)
    }

    private func saveSettings() {
        storage.save(settings, for: .appSettings)
    }

    private func triggerHaptic() {
#if canImport(UIKit)
        guard settings.hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
#endif
    }
}
