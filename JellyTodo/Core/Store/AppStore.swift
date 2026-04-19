import Combine
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var planTasks: [PlanTask] = []
    @Published var pomodoroSessions: [PomodoroSession] = []
    @Published var profile: UserProfile = .default
    @Published var settings: AppSettings = .default
    @Published var entitlement: EntitlementState = .default
    @Published var timerState = PomodoroTimerState()
#if DEBUG
    @Published var cloudDebugState = CloudDebugState.idle
#endif

    private let storage: StorageClient
    private let database: DatabaseClient
    private let cloudAPI: CloudAPIClient
    private var timerCancellable: AnyCancellable?
    private var hasLoadedInitialState = false

    init(
        storage: StorageClient = StorageClient(),
        database: DatabaseClient = DatabaseClient(),
        cloudAPI: CloudAPIClient = CloudAPIClient()
    ) {
        self.storage = storage
        self.database = database
        self.cloudAPI = cloudAPI
    }

    var preferredColorScheme: ColorScheme? {
        switch settings.themeMode {
        case .pink, .blackWhite, .blue, .green, .rainbow:
            return .light
        }
    }

    var todayTodos: [TodoItem] {
        todos
            .filter { $0.isAddedToToday && Calendar.current.isDateInToday($0.taskDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var monthSections: [TodoDaySection] {
        monthSections(for: Date(), compact: false)
    }

    func monthSections(for month: Date = Date(), compact: Bool = false) -> [TodoDaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: todos.filter {
            $0.isAddedToToday && calendar.isDate($0.taskDate, equalTo: month, toGranularity: .month)
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

    var planSections: [PlanTaskSection] {
        planTasks
            .sorted { $0.createdAt < $1.createdAt }
            .map { task in
                PlanTaskSection(
                    task: task,
                    items: todos
                        .filter { $0.planTaskID == task.id }
                        .sorted { $0.createdAt < $1.createdAt }
                )
            }
    }

    var totalCompletedCount: Int {
        todos.filter(\.isCompleted).count
    }

    var totalPendingCount: Int {
        todos.filter { !$0.isCompleted }.count
    }

    func loadInitialState() {
        guard !hasLoadedInitialState else { return }
        hasLoadedInitialState = true

        Task {
            let appState = await Task.detached(priority: .userInitiated) {
                let storage = StorageClient()
                let database = DatabaseClient()
                return (
                    snapshot: database.loadSnapshot(legacySnapshot: storage.loadSnapshot()),
                    entitlement: database.loadEntitlement()
                )
            }.value

            todos = appState.snapshot.todos
            planTasks = appState.snapshot.planTasks
            pomodoroSessions = appState.snapshot.pomodoroSessions
            profile = appState.snapshot.profile
            settings = appState.snapshot.settings
            entitlement = appState.entitlement
            syncGoalIfNeeded()
            savePersistentState()
        }
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

    func addPlanTask(title: String) {
        let trimmed = sanitize(title)
        guard !trimmed.isEmpty else { return }

        let now = Date()
        planTasks.append(
            PlanTask(
                id: UUID(),
                title: trimmed,
                createdAt: now,
                updatedAt: now,
                isCollapsed: false
            )
        )
        savePlanTasks()
    }

    func addPlanItem(
        title: String,
        to planTaskID: UUID,
        cycle: TodoTaskCycle = .daily,
        dailyDurationMinutes: Int = 25,
        focusTimerDirection: FocusTimerDirection = .countDown
    ) {
        let trimmed = sanitize(title)
        guard !trimmed.isEmpty else { return }
        guard planTasks.contains(where: { $0.id == planTaskID }) else { return }

        let now = Date()
        todos.append(
            TodoItem(
                id: UUID(),
                planTaskID: planTaskID,
                isAddedToToday: false,
                title: trimmed,
                isCompleted: false,
                createdAt: now,
                updatedAt: now,
                taskDate: now,
                cycle: cycle,
                dailyDurationMinutes: min(max(dailyDurationMinutes, 5), 480),
                focusTimerDirection: focusTimerDirection
            )
        )
        saveTodos()
    }

    func togglePlanTaskCollapsed(id: UUID) {
        guard let index = planTasks.firstIndex(where: { $0.id == id }) else { return }
        planTasks[index].isCollapsed.toggle()
        planTasks[index].updatedAt = Date()
        savePlanTasks()
    }

    func addTodoToToday(id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isAddedToToday = true
        todos[index].taskDate = Date()
        todos[index].updatedAt = Date()
        triggerHaptic()
        saveTodos()
    }

    func updateTodo(id: UUID, title: String) {
        let trimmed = sanitize(title)
        guard !trimmed.isEmpty, let index = todos.firstIndex(where: { $0.id == id }) else { return }

        todos[index].title = trimmed
        todos[index].updatedAt = Date()
        saveTodos()
    }

    func updateTodoDetail(
        id: UUID,
        cycle: TodoTaskCycle,
        dailyDurationMinutes: Int,
        focusTimerDirection: FocusTimerDirection,
        note: String
    ) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }

        todos[index].cycle = cycle
        todos[index].dailyDurationMinutes = min(max(dailyDurationMinutes, 5), 480)
        todos[index].focusTimerDirection = focusTimerDirection
        todos[index].note = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_000))
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

    func startPomodoro(
        mode: PomodoroTimerMode,
        relatedTodoID: UUID? = nil,
        durationSeconds: Int? = nil,
        direction: FocusTimerDirection = .countDown
    ) {
        timerCancellable?.cancel()
        let linkedDurationSeconds = relatedTodoID
            .flatMap { id in todos.first(where: { $0.id == id })?.dailyDurationMinutes }
            .map { max($0, 1) * 60 }
        let totalSeconds = max(durationSeconds ?? linkedDurationSeconds ?? timerState.totalSeconds, 1)
        timerState.mode = mode
        timerState.direction = direction
        timerState.totalSeconds = totalSeconds
        timerState.remainingSeconds = direction == .countDown ? totalSeconds : 0
        timerState.elapsedSeconds = direction == .countUp ? 0 : 0
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
        }
        resetTimer(for: .focus)

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
        let completedPomodoros = sessions.filter { $0.type == .focus }.count
        let goal = max(settings.pomodoroGoalPerDay, 1)
        let goalRate = min(Double(completedPomodoros) / Double(goal), 1)

        return PomodoroStats(
            focusSeconds: focusSeconds,
            completedPomodoros: completedPomodoros,
            goalRate: goalRate
        )
    }

    func chartSegments(for range: PomodoroStatsRange) -> [DonutChartSegment] {
        focusSegments(for: range).enumerated().map { index, segment in
            DonutChartSegment(
                value: Double(segment.seconds),
                label: segment.title,
                opacity: max(1.0 - Double(index) * 0.14, 0.32)
            )
        }
    }

    func focusSegments(for range: PomodoroStatsRange) -> [PlanFocusSegment] {
        let focusSessions = sessions(in: range).filter { $0.type == .focus && $0.relatedTodoID != nil }
        let grouped = Dictionary(grouping: focusSessions) { session -> UUID in
            guard let todoID = session.relatedTodoID,
                  let todo = todos.first(where: { $0.id == todoID })
            else { return UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }

            return todo.planTaskID ?? todo.id
        }

        return grouped.compactMap { key, sessions in
            let seconds = sessions.reduce(0) { $0 + $1.durationSeconds }
            guard seconds > 0 else { return nil }

            let relatedTodos = sessions.compactMap { session in
                session.relatedTodoID.flatMap { id in todos.first(where: { $0.id == id }) }
            }
            let title = planTasks.first(where: { $0.id == key })?.title
                ?? relatedTodos.first?.title
                ?? "Focus"
            let itemCount = Set(relatedTodos.map(\.id)).count

            return PlanFocusSegment(id: key, title: title, seconds: seconds, itemCount: itemCount)
        }
        .sorted { $0.seconds > $1.seconds }
    }

    func focusTimeBuckets(for range: PomodoroStatsRange) -> [FocusTimeBucket] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let now = Date()
        let focusSessions = sessions(in: range).filter { $0.type == .focus }

        switch range {
        case .today:
            return (0..<24).map { hour in
                let seconds = focusSessions
                    .filter { calendar.component(.hour, from: $0.endAt) == hour }
                    .reduce(0) { $0 + $1.durationSeconds }
                return FocusTimeBucket(id: "hour-\(hour)", label: "\(hour)", seconds: seconds)
            }

        case .week:
            guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
            let symbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            return (0..<7).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: dayOffset, to: week.start) ?? week.start
                let seconds = focusSessions
                    .filter { calendar.isDate($0.endAt, inSameDayAs: date) }
                    .reduce(0) { $0 + $1.durationSeconds }
                return FocusTimeBucket(id: "weekday-\(dayOffset)", label: symbols[dayOffset], seconds: seconds)
            }

        case .month:
            guard let days = calendar.range(of: .day, in: .month, for: now) else { return [] }
            return days.map { day in
                let seconds = focusSessions
                    .filter { calendar.component(.day, from: $0.endAt) == day }
                    .reduce(0) { $0 + $1.durationSeconds }
                return FocusTimeBucket(id: "month-day-\(day)", label: "\(day)", seconds: seconds)
            }

        case .year:
            return (1...12).map { month in
                let seconds = focusSessions
                    .filter { calendar.component(.month, from: $0.endAt) == month }
                    .reduce(0) { $0 + $1.durationSeconds }
                return FocusTimeBucket(id: "year-month-\(month)", label: "\(month)", seconds: seconds)
            }
        }
    }

    func focusedSeconds(for todoID: UUID) -> Int {
        pomodoroSessions
            .filter { $0.type == .focus && $0.relatedTodoID == todoID }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    func todayTaskFocusSummaries() -> [TaskFocusSummary] {
        let todayFocusSessions = pomodoroSessions.filter {
            $0.type == .focus && $0.relatedTodoID != nil && Calendar.current.isDateInToday($0.endAt)
        }
        let grouped = Dictionary(grouping: todayFocusSessions) { $0.relatedTodoID }

        return grouped.compactMap { key, sessions in
            guard let todoID = key else { return nil }
            guard let todo = todos.first(where: { $0.id == todoID }) else { return nil }
            let seconds = sessions.reduce(0) { $0 + $1.durationSeconds }
            return TaskFocusSummary(id: todoID, title: todo.title, seconds: seconds)
        }
        .filter { $0.seconds > 0 }
        .sorted { $0.seconds > $1.seconds }
    }

#if DEBUG
    var databaseDebugSummary: DatabaseDebugSummary {
        DatabaseDebugSummary(
            plans: planTasks.count,
            todos: todos.count,
            todayTodos: todayTodos.count,
            sessions: pomodoroSessions.count,
            entitlement: entitlement
        )
    }

    func mockEntitlement(_ tier: EntitlementTier) {
        entitlement = EntitlementState(
            tier: tier,
            cloudSyncEnabled: tier == .pro,
            expiresAt: tier == .pro ? Calendar.current.date(byAdding: .month, value: 1, to: Date()) : nil
        )
        database.saveEntitlement(entitlement)
        triggerHaptic()
    }

    func checkCloudHealth() async {
        cloudDebugState = .loading("Checking cloud...")

        do {
            let health = try await cloudAPI.health()
            cloudDebugState = .success("Cloud OK · \(health.environment)")
            triggerHaptic()
        } catch {
            cloudDebugState = .failure(error.localizedDescription)
        }
    }

    func importCloudStagingData() async {
        cloudDebugState = .loading("Pulling staging data...")

        do {
            let response = try await cloudAPI.pull()
            replaceCloudStagingData(with: response)
            cloudDebugState = .success("Pulled \(response.plans.count) plans · \(response.todoItems.count) todos · \(response.pomodoroSessions.count) sessions")
            triggerHaptic()
        } catch {
            cloudDebugState = .failure(error.localizedDescription)
        }
    }

    func seedPomodoroChartDebugData() {
        seedDebugData(planCount: 6, itemsPerPlan: 4, sessionsPerTodo: 2, todayItemsPerPlan: 3)
    }

    func seedPomodoroChartPressureDebugData() {
        seedDebugData(planCount: 10, itemsPerPlan: 5, sessionsPerTodo: 1, todayItemsPerPlan: 4)
    }

    func seedPlanTodayMediumPressureDebugData() {
        seedDebugData(planCount: 12, itemsPerPlan: 10, sessionsPerTodo: 2, todayItemsPerPlan: 5)
    }

    func seedPlanTodayHeavyPressureDebugData() {
        seedDebugData(planCount: 20, itemsPerPlan: 15, sessionsPerTodo: 2, todayItemsPerPlan: 6)
    }

    private func seedDebugData(
        planCount: Int,
        itemsPerPlan: Int,
        sessionsPerTodo: Int,
        todayItemsPerPlan: Int
    ) {
        clearPomodoroChartDebugData()

        let now = Date()
        let calendar = Calendar.current
        let planTitles = [
            "考研数学", "考研英语", "考研政治", "专业课一", "专业课二",
            "产品设计", "SwiftUI 项目", "阅读计划", "健身恢复", "生活整理",
            "算法训练", "写作输出", "英语听力", "财务复盘", "睡眠管理",
            "摄影练习", "面试准备", "论文阅读", "副业计划", "周末清单"
        ]
        let taskTitles = [
            "高数极限", "线代矩阵", "概率分布", "阅读精翻", "核心词汇",
            "马原框架", "专业课真题", "数据结构", "操作系统", "UI 走查",
            "交互复盘", "组件封装", "跑步训练", "力量拉伸", "房间整理",
            "读书笔记", "文章草稿", "算法错题", "听力影子跟读", "预算记录",
            "睡前复盘", "照片整理", "面试八股", "论文摘要", "周计划拆解"
        ]
        let cycles = TodoTaskCycle.allCases

        var createdPlans: [PlanTask] = []
        var createdTodos: [TodoItem] = []
        var createdSessions: [PomodoroSession] = []

        for planIndex in 0..<planCount {
            let planTask = PlanTask(
                id: UUID(),
                title: planTitles[planIndex % planTitles.count],
                createdAt: calendar.date(byAdding: .day, value: -planIndex, to: now) ?? now,
                updatedAt: now,
                isCollapsed: planIndex % 5 == 4
            )
            createdPlans.append(planTask)

            for itemIndex in 0..<itemsPerPlan {
                let globalIndex = planIndex * itemsPerPlan + itemIndex
                let isToday = itemIndex < todayItemsPerPlan
                let durationMinutes = 12 + ((globalIndex * 7 + planIndex * 5) % 72)
                let taskDate = isToday ? now : (calendar.date(byAdding: .day, value: -(globalIndex % 28), to: now) ?? now)
                let todo = TodoItem(
                    id: UUID(),
                    planTaskID: planTask.id,
                    isAddedToToday: isToday,
                    title: "\(taskTitles[globalIndex % taskTitles.count]) \(itemIndex + 1)",
                    isCompleted: globalIndex % 6 == 0,
                    createdAt: calendar.date(byAdding: .day, value: -globalIndex % 18, to: now) ?? now,
                    updatedAt: now,
                    taskDate: taskDate,
                    cycle: cycles[globalIndex % cycles.count],
                    dailyDurationMinutes: durationMinutes,
                    focusTimerDirection: globalIndex % 3 == 0 ? .countUp : .countDown,
                    note: Self.debugPomodoroSeedMarker
                )
                createdTodos.append(todo)

                for sessionIndex in 0..<sessionsPerTodo {
                    let dayOffset: Int
                    if sessionIndex == 0, isToday {
                        dayOffset = 0
                    } else {
                        dayOffset = -((globalIndex + sessionIndex * 5) % 30)
                    }
                    let hourOffset = -((globalIndex * 3 + sessionIndex * 7) % 20)
                    let endAt = calendar.date(byAdding: .hour, value: hourOffset, to: calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now) ?? now
                    let sessionMinutes = max(8, durationMinutes - sessionIndex * 5 + planIndex % 9)
                    createdSessions.append(
                        PomodoroSession(
                            id: UUID(),
                            type: .focus,
                            startAt: endAt.addingTimeInterval(TimeInterval(-sessionMinutes * 60)),
                            endAt: endAt,
                            durationSeconds: sessionMinutes * 60,
                            relatedTodoID: todo.id
                        )
                    )
                }
            }
        }

        planTasks.append(contentsOf: createdPlans)
        todos.append(contentsOf: createdTodos)
        pomodoroSessions.append(contentsOf: createdSessions)

        savePlanTasks()
        saveTodos()
        saveSessions()
        triggerHaptic()
    }

    func clearPomodoroChartDebugData() {
        let debugTodoIDs = Set(todos.filter { Self.isDebugSeedTodo($0) }.map(\.id))
        let debugPlanIDs = Set(todos.filter { Self.isDebugSeedTodo($0) }.compactMap(\.planTaskID))

        pomodoroSessions.removeAll { session in
            session.relatedTodoID.map { debugTodoIDs.contains($0) } ?? false
        }
        todos.removeAll { Self.isDebugSeedTodo($0) }
        planTasks.removeAll { debugPlanIDs.contains($0.id) }

        saveSessions()
        saveTodos()
        savePlanTasks()
        triggerHaptic()
    }

    var debugPomodoroSeedSummary: (plans: Int, todos: Int, todayTodos: Int, sessions: Int, todaySeconds: Int) {
        let debugTodoIDs = Set(todos.filter { Self.isDebugSeedTodo($0) }.map(\.id))
        let debugTodayTodos = todos.filter {
            Self.isDebugSeedTodo($0)
                && $0.isAddedToToday
                && Calendar.current.isDateInToday($0.taskDate)
        }.count
        let sessions = pomodoroSessions.filter { session in
            session.relatedTodoID.map { debugTodoIDs.contains($0) } ?? false
        }
        let todaySeconds = sessions
            .filter { Calendar.current.isDateInToday($0.endAt) }
            .reduce(0) { $0 + $1.durationSeconds }

        return (
            plans: Set(todos.filter { Self.isDebugSeedTodo($0) }.compactMap(\.planTaskID)).count,
            todos: debugTodoIDs.count,
            todayTodos: debugTodayTodos,
            sessions: sessions.count,
            todaySeconds: todaySeconds
        )
    }

    private func replaceCloudStagingData(with response: CloudSyncPullResponse) {
        clearCloudStagingData()

        let cloudPlans = response.plans
            .filter { $0.deletedAt == nil }
            .map {
                PlanTask(
                    id: $0.id,
                    title: $0.title,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    isCollapsed: $0.isCollapsed
                )
            }

        let cloudTodos = response.todoItems
            .filter { $0.deletedAt == nil }
            .map {
                TodoItem(
                    id: $0.id,
                    planTaskID: $0.planID,
                    isAddedToToday: $0.isAddedToToday,
                    title: $0.title,
                    isCompleted: $0.isCompleted,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    taskDate: $0.taskDate,
                    cycle: $0.cycle,
                    dailyDurationMinutes: $0.dailyDurationMinutes,
                    focusTimerDirection: $0.focusTimerDirection,
                    note: "\(Self.cloudStagingSeedMarker)\n\($0.note)"
                )
            }

        let availableTodoIDs = Set(cloudTodos.map(\.id))
        let cloudSessions = response.pomodoroSessions
            .filter { session in
                session.deletedAt == nil
                    && session.todoID.map { availableTodoIDs.contains($0) } == true
            }
            .map {
                PomodoroSession(
                    id: $0.id,
                    type: $0.type,
                    startAt: $0.startAt,
                    endAt: $0.endAt,
                    durationSeconds: $0.durationSeconds,
                    relatedTodoID: $0.todoID
                )
            }

        planTasks.append(contentsOf: cloudPlans)
        todos.append(contentsOf: cloudTodos)
        pomodoroSessions.append(contentsOf: cloudSessions)

        savePlanTasks()
        saveTodos()
        saveSessions()
    }

    private func clearCloudStagingData() {
        let cloudTodoIDs = Set(todos.filter { Self.isCloudStagingTodo($0) }.map(\.id))
        let cloudPlanIDs = Set(todos.filter { Self.isCloudStagingTodo($0) }.compactMap(\.planTaskID))

        pomodoroSessions.removeAll { session in
            session.relatedTodoID.map { cloudTodoIDs.contains($0) } ?? false
        }
        todos.removeAll { Self.isCloudStagingTodo($0) }
        planTasks.removeAll { cloudPlanIDs.contains($0.id) }
    }

    private static func isDebugSeedTodo(_ todo: TodoItem) -> Bool {
        todo.note == debugPomodoroSeedMarker || isCloudStagingTodo(todo)
    }

    private static func isCloudStagingTodo(_ todo: TodoItem) -> Bool {
        todo.note.hasPrefix(cloudStagingSeedMarker)
    }

    private static let debugPomodoroSeedMarker = "debug-pomodoro-chart-seed"
    private static let cloudStagingSeedMarker = "debug-cloud-staging-seed"
#endif

    private func beginTicking() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.timerState.isRunning else { return }

                switch self.timerState.direction {
                case .countDown:
                    if self.timerState.remainingSeconds > 0 {
                        self.timerState.remainingSeconds -= 1
                        self.timerState.elapsedSeconds = self.timerState.totalSeconds - self.timerState.remainingSeconds
                    }
                case .countUp:
                    if self.timerState.elapsedSeconds < self.timerState.totalSeconds {
                        self.timerState.elapsedSeconds += 1
                        self.timerState.remainingSeconds = max(self.timerState.totalSeconds - self.timerState.elapsedSeconds, 0)
                    }
                }

                if self.timerState.direction == .countDown, self.timerState.remainingSeconds <= 0 {
                    self.completePomodoro()
                } else if self.timerState.direction == .countUp, self.timerState.elapsedSeconds >= self.timerState.totalSeconds {
                    self.completePomodoro()
                }
            }
    }

    private func resetTimer(for mode: PomodoroTimerMode) {
        timerCancellable?.cancel()
        let totalSeconds = max(timerState.totalSeconds, 0)
        timerState.mode = mode
        timerState.direction = .countDown
        timerState.totalSeconds = totalSeconds
        timerState.remainingSeconds = totalSeconds
        timerState.elapsedSeconds = 0
        timerState.isRunning = false
        timerState.isPaused = false
        timerState.startedAt = nil
        timerState.relatedTodoID = nil
    }

    private func sessions(in range: PomodoroStatsRange) -> [PomodoroSession] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let now = Date()

        return pomodoroSessions.filter { session in
            switch range {
            case .today:
                return calendar.isDateInToday(session.endAt)
            case .week:
                return calendar.isDate(session.endAt, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(session.endAt, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(session.endAt, equalTo: now, toGranularity: .year)
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
        let snapshot = StorageSnapshot(
            todos: todos,
            planTasks: planTasks,
            pomodoroSessions: pomodoroSessions,
            profile: profile,
            settings: settings
        )
        database.saveSnapshot(snapshot)
        database.saveEntitlement(entitlement)
        storage.save(todos, for: .todos)
        storage.save(planTasks, for: .planTasks)
        storage.save(pomodoroSessions, for: .pomodoroSessions)
        storage.save(profile, for: .userProfile)
        storage.save(settings, for: .appSettings)
    }

    private func saveTodos() {
        database.saveTodos(todos)
        storage.save(todos, for: .todos)
    }

    private func savePlanTasks() {
        database.savePlanTasks(planTasks)
        storage.save(planTasks, for: .planTasks)
    }

    private func saveSessions() {
        database.saveSessions(pomodoroSessions)
        storage.save(pomodoroSessions, for: .pomodoroSessions)
    }

    private func saveProfile() {
        database.saveProfile(profile)
        storage.save(profile, for: .userProfile)
    }

    private func saveSettings() {
        database.saveSettings(settings)
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
