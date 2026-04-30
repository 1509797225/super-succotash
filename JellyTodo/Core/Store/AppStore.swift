import Combine
import SwiftUI

extension Notification.Name {
    static let todayCheckInMockActivated = Notification.Name("todayCheckInMockActivated")
}

@MainActor
final class AppStore: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var planTasks: [PlanTask] = []
    @Published var pomodoroSessions: [PomodoroSession] = []
    @Published var checkInRecords: [DailyCheckInRecord] = []
    @Published var presentedCheckInDate: Date?
    @Published var profile: UserProfile = .default
    @Published var settings: AppSettings = .default
    @Published var entitlement: EntitlementState = .default
    @Published var cloudIdentity: CloudIdentity?
    @Published var accountState: AccountState = .signedOut
    @Published var storeKitEntitlement: StoreKitEntitlementSnapshot = .idle
    @Published var syncHistory: [SyncHistoryEntry] = []
    @Published var localBackups: [LocalBackupSnapshot] = []
    @Published var cloudBackups: [CloudBackupSnapshot] = []
    @Published var pendingUploadCount: Int = 0
    @Published var timerState = PomodoroTimerState()
#if DEBUG
    @Published var cloudDebugState = CloudDebugState.idle
#endif

    private let storage: StorageClient
    private let database: DatabaseClient
    private let cloudAPI: CloudAPIClient
    private let storeKitClient: StoreKitClient
    private let keychain: KeychainClient
    private var timerCancellable: AnyCancellable?
    private var hasLoadedInitialState = false
    private var isCloudSyncInFlight = false
    private let foregroundAutoSyncCooldown: TimeInterval = 15 * 60

    init(
        storage: StorageClient = StorageClient(),
        database: DatabaseClient = DatabaseClient(),
        cloudAPI: CloudAPIClient = CloudAPIClient(),
        storeKitClient: StoreKitClient = StoreKitClient(),
        keychain: KeychainClient = KeychainClient()
    ) {
        self.storage = storage
        self.database = database
        self.cloudAPI = cloudAPI
        self.storeKitClient = storeKitClient
        self.keychain = keychain
    }

    var preferredColorScheme: ColorScheme? {
        switch settings.themeMode {
        case .pink, .blackWhite, .blue, .green, .pinkJelly, .blackWhiteJelly, .blueJelly, .greenJelly:
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
                        .filter { $0.isPlanTemplate && $0.planTaskID == task.id }
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

    var currentCheckInStreak: Int {
        streak(endingAt: Date())
    }

    var isCheckInSheetPresented: Bool {
        presentedCheckInDate != nil
    }

    var shouldPromptTodayCheckIn: Bool {
        let summary = todayCheckInSummary()
        return summary.total > 0 && summary.completed == summary.total && !hasCheckedIn(on: Date())
    }

    var latestMakeUpCandidate: Date? {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())),
              !hasCheckedIn(on: yesterday)
        else { return nil }
        return yesterday
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
                    entitlement: database.loadEntitlement(),
                    cloudIdentity: database.loadCloudIdentity(),
                    accountState: database.loadAccountState(),
                    syncHistory: database.loadSyncHistory(),
                    localBackups: database.loadLocalBackupSnapshots(),
                    pendingUploadCount: database.pendingChangeLogCount()
                )
            }.value

            todos = appState.snapshot.todos
            planTasks = appState.snapshot.planTasks
            pomodoroSessions = appState.snapshot.pomodoroSessions
            checkInRecords = appState.snapshot.checkInRecords
            profile = appState.snapshot.profile
            settings = appState.snapshot.settings
            entitlement = appState.entitlement
            cloudIdentity = appState.cloudIdentity
            accountState = appState.accountState
            syncHistory = appState.syncHistory
            localBackups = appState.localBackups
            pendingUploadCount = appState.pendingUploadCount
            syncGoalIfNeeded()
            normalizeLegacyPlanTodayItems()
            materializeTodayOccurrencesIfNeeded()
            savePersistentState()
            await refreshStoreKitEntitlement()
        }
    }

    func addTodo(title: String, taskDate: Date = Date()) {
        let trimmed = sanitize(title)
        guard !trimmed.isEmpty else { return }

        let now = Date()
        let todo = TodoItem(
            id: UUID(),
            title: trimmed,
            isCompleted: false,
            createdAt: now,
            updatedAt: now,
            taskDate: taskDate
        )
        todos.append(todo)
        saveTodos()
        evaluateTodayCheckIn()
        logCloudChange(entityType: "todo_item", entityID: todo.id.uuidString, operation: "create", payload: todo)
    }

    func addPlanTask(title: String) {
        let trimmed = sanitize(title)
        guard !trimmed.isEmpty else { return }

        let now = Date()
        let planTask = PlanTask(
            id: UUID(),
            title: trimmed,
            createdAt: now,
            updatedAt: now,
            isCollapsed: false
        )
        planTasks.append(planTask)
        savePlanTasks()
        logCloudChange(entityType: "plan", entityID: planTask.id.uuidString, operation: "create", payload: planTask)
    }

    func addPlanItem(
        title: String,
        to planTaskID: UUID,
        scheduleMode: TodoScheduleMode = .custom,
        recurrenceValue: Int? = nil,
        scheduledDates: [Date] = [],
        dailyDurationMinutes: Int = 25,
        focusTimerDirection: FocusTimerDirection = .countDown,
        note: String = ""
    ) {
        let trimmed = sanitize(title)
        guard !trimmed.isEmpty else { return }
        guard planTasks.contains(where: { $0.id == planTaskID }) else { return }

        let now = Date()
        let todo = TodoItem(
            id: UUID(),
            planTaskID: planTaskID,
            sourceTemplateID: nil,
            isAddedToToday: false,
            title: trimmed,
            isCompleted: false,
            createdAt: now,
            updatedAt: now,
            taskDate: now,
            cycle: legacyCycle(for: scheduleMode),
            scheduleMode: scheduleMode,
            recurrenceValue: recurrenceValue,
            scheduledDates: scheduleMode == .custom ? normalizedScheduleDates(scheduledDates, fallbackDate: now) : [],
            dailyDurationMinutes: min(max(dailyDurationMinutes, 5), 480),
            focusTimerDirection: focusTimerDirection,
            note: sanitizedNote(note)
        )
        todos.append(todo)
        saveTodos()
        logCloudChange(entityType: "todo_item", entityID: todo.id.uuidString, operation: "create", payload: todo)
    }

    func togglePlanTaskCollapsed(id: UUID) {
        guard let index = planTasks.firstIndex(where: { $0.id == id }) else { return }
        planTasks[index].isCollapsed.toggle()
        planTasks[index].updatedAt = Date()
        savePlanTasks()
        logCloudChange(entityType: "plan", entityID: id.uuidString, operation: "update", payload: planTasks[index])
    }

    func addTodoToToday(id: UUID) {
        guard let template = todos.first(where: { $0.id == id }) else { return }
        let result = upsertTodayOccurrence(from: template, now: Date())
        triggerHaptic()
        saveTodos()
        logCloudChange(entityType: "todo_item", entityID: result.todo.id.uuidString, operation: result.operation, payload: result.todo)
    }

    func prepareFocusTodoID(for id: UUID) -> UUID {
        guard let todo = todos.first(where: { $0.id == id }) else { return id }
        guard todo.isPlanTemplate else { return id }
        let result = upsertTodayOccurrence(from: todo, now: Date())
        saveTodos()
        logCloudChange(entityType: "todo_item", entityID: result.todo.id.uuidString, operation: result.operation, payload: result.todo)
        return result.todo.id
    }

    func materializeTodayOccurrencesIfNeeded() {
        let now = Date()
        var generatedResults: [(todo: TodoItem, operation: String)] = []
        for template in todos.filter(\.isPlanTemplate) where shouldMaterialize(template, on: now) {
            generatedResults.append(upsertTodayOccurrence(from: template, now: now))
        }

        guard !generatedResults.isEmpty else { return }
        saveTodos()
        for result in generatedResults {
            logCloudChange(entityType: "todo_item", entityID: result.todo.id.uuidString, operation: result.operation, payload: result.todo)
        }
    }

    func updateTodo(id: UUID, title: String) {
        let trimmed = sanitize(title)
        guard !trimmed.isEmpty, let index = todos.firstIndex(where: { $0.id == id }) else { return }

        todos[index].title = trimmed
        todos[index].updatedAt = Date()
        saveTodos()
        logCloudChange(entityType: "todo_item", entityID: id.uuidString, operation: "update", payload: todos[index])
    }

    func updateTodoDetail(
        id: UUID,
        scheduleMode: TodoScheduleMode,
        recurrenceValue: Int?,
        scheduledDates: [Date],
        dailyDurationMinutes: Int,
        focusTimerDirection: FocusTimerDirection,
        note: String
    ) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }

        let normalizedDates = scheduleMode == .custom
            ? normalizedScheduleDates(scheduledDates, fallbackDate: todos[index].taskDate)
            : []
        todos[index].cycle = scheduleMode == .custom ? .manual : legacyCycle(for: scheduleMode)
        todos[index].scheduleMode = scheduleMode
        todos[index].recurrenceValue = recurrenceValue
        todos[index].scheduledDates = normalizedDates
        if let firstDate = normalizedDates.first, todos[index].isPlanTemplate, scheduleMode == .custom {
            todos[index].taskDate = firstDate
        } else if todos[index].isPlanTemplate {
            todos[index].taskDate = templateAnchorDate(for: scheduleMode, recurrenceValue: recurrenceValue, fallback: todos[index].taskDate)
        }
        todos[index].dailyDurationMinutes = min(max(dailyDurationMinutes, 5), 480)
        todos[index].focusTimerDirection = focusTimerDirection
        todos[index].note = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_000))
        todos[index].updatedAt = Date()
        saveTodos()
        evaluateTodayCheckIn()
        logCloudChange(entityType: "todo_item", entityID: id.uuidString, operation: "update", payload: todos[index])
    }

    func deleteTodo(id: UUID) {
        let payload = todos.first(where: { $0.id == id })
        todos.removeAll { $0.id == id }
        saveTodos()
        evaluateTodayCheckIn()
        if let payload {
            logCloudChange(entityType: "todo_item", entityID: id.uuidString, operation: "delete", payload: payload)
        }
    }

    func toggleTodoCompleted(id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isCompleted.toggle()
        todos[index].updatedAt = Date()
        triggerHaptic()
        saveTodos()
        evaluateTodayCheckIn()
        logCloudChange(entityType: "todo_item", entityID: id.uuidString, operation: "update", payload: todos[index])
    }

    func dismissCheckInCelebration() {
        presentedCheckInDate = nil
    }

    func makeUpLatestMissedDay() {
        guard let date = latestMakeUpCandidate else { return }
        completeCheckIn(on: date, isMakeUp: true, triggerPresentation: true)
    }

    func presentTodayCheckIn() {
        guard shouldPromptTodayCheckIn else { return }
        presentCheckInSheet(for: Date())
    }

    func presentCheckInSheet(for date: Date) {
        presentedCheckInDate = Calendar.current.startOfDay(for: date)
    }

    func completeCheckIn(on date: Date, isMakeUp: Bool = false, triggerPresentation: Bool = false) {
        createOrRefreshCheckIn(for: date, isMakeUp: isMakeUp, triggerPresentation: triggerPresentation)
    }

    func hasCheckedIn(on date: Date) -> Bool {
        let calendar = Calendar.current
        return checkInRecords.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func checkInRecord(on date: Date) -> DailyCheckInRecord? {
        let calendar = Calendar.current
        return checkInRecords.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func todayCheckInSummary(for date: Date = Date()) -> (completed: Int, total: Int, focusSeconds: Int) {
        let calendar = Calendar.current
        let dayTodos = todos.filter { $0.isAddedToToday && calendar.isDate($0.taskDate, inSameDayAs: date) }
        let completed = dayTodos.filter(\.isCompleted).count
        let focusSeconds = pomodoroSessions
            .filter { $0.type == .focus && calendar.isDate($0.endAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.durationSeconds }
        return (completed, dayTodos.count, focusSeconds)
    }

    func checkInTodos(for date: Date) -> [TodoItem] {
        let calendar = Calendar.current
        return todos
            .filter { $0.isAddedToToday && calendar.isDate($0.taskDate, inSameDayAs: date) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func monthCheckInDays(for month: Date) -> [CheckInCalendarDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale.current
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let firstWeekday = calendar.component(.weekday, from: start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let today = calendar.startOfDay(for: Date())

        var days = (0..<leading).map { CheckInCalendarDay.placeholder("leading-\($0)-\(start.timeIntervalSinceReferenceDate)") }
        for day in 1...daysInMonth {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: start) else { continue }
            let record = checkInRecord(on: date)
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let isMakeUpAvailable = latestMakeUpCandidate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
            days.append(CheckInCalendarDay(date: date, record: record, isToday: isToday, isMakeUpAvailable: isMakeUpAvailable))
        }

        while days.count % 7 != 0 {
            days.append(CheckInCalendarDay.placeholder("trailing-\(days.count)-\(start.timeIntervalSinceReferenceDate)"))
        }
        return days
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
        let sessionSnapshot = pomodoroSessionSnapshot(for: timerState.relatedTodoID)
        let session = PomodoroSession(
            id: UUID(),
            type: timerState.mode.sessionType,
            startAt: timerState.startedAt ?? now.addingTimeInterval(TimeInterval(-timerState.totalSeconds)),
            endAt: now,
            durationSeconds: max(timerState.elapsedSeconds, 1),
            relatedTodoID: timerState.relatedTodoID,
            sourceTemplateID: sessionSnapshot?.sourceTemplateID,
            planTaskID: sessionSnapshot?.planTaskID,
            planTitleSnapshot: sessionSnapshot?.planTitle ?? "",
            todoTitleSnapshot: sessionSnapshot?.todoTitle ?? ""
        )

        pomodoroSessions.append(session)
        saveSessions()
        logCloudChange(entityType: "pomodoro_session", entityID: session.id.uuidString, operation: "create", payload: session)

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
        logCloudChange(entityType: "user_profile", entityID: "current", operation: "update", payload: self.profile)
    }

    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        if profile.dailyGoal != settings.pomodoroGoalPerDay {
            profile.dailyGoal = settings.pomodoroGoalPerDay
            saveProfile()
        }
        saveSettings()
        logCloudChange(entityType: "app_settings", entityID: "current", operation: "update", payload: self.settings)
    }

    func createLocalBackup(
        reason: String = "manual",
        shouldRecordHistory: Bool = true,
        shouldHaptic: Bool = true
    ) {
        let snapshot = currentSnapshot()
        if let backup = database.createLocalBackup(snapshot: snapshot, reason: reason) {
            localBackups.insert(backup, at: 0)
            localBackups = Array(localBackups.prefix(10))
            if shouldRecordHistory {
                recordSyncHistory(
                    direction: .backup,
                    status: .success,
                    changedCount: snapshot.todos.count + snapshot.planTasks.count + snapshot.pomodoroSessions.count,
                    message: "Local backup created"
                )
            }
            if shouldHaptic {
                triggerHaptic()
            }
        } else {
            if shouldRecordHistory {
                recordSyncHistory(
                    direction: .backup,
                    status: .failed,
                    message: "Local backup failed"
                )
            }
        }
    }

    func refreshCloudBackups() async {
        guard entitlement.isCloudSyncAvailable else {
            recordSyncHistory(
                direction: .pull,
                status: .skipped,
                message: "Cloud backups require Pro"
            )
            return
        }

        do {
            let identity = try await resolveCloudIdentity()
            cloudBackups = try await cloudAPI.loadCloudBackups(userID: identity.userID)
        } catch {
            recordSyncHistory(
                direction: .pull,
                status: .failed,
                message: error.localizedDescription
            )
        }
    }

    func createCloudBackup(reason: String = "manual_cloud_backup") async {
        createLocalBackup(
            reason: "before_cloud_backup",
            shouldRecordHistory: false,
            shouldHaptic: false
        )

        guard entitlement.isCloudSyncAvailable else {
            recordSyncHistory(
                direction: .backup,
                status: .skipped,
                message: "Cloud backups require Pro"
            )
            return
        }

        do {
            let snapshot = currentSnapshot()
            let identity = try await resolveCloudIdentity()
            let backup = try await cloudAPI.createCloudBackup(
                identity: identity,
                snapshot: snapshot,
                reason: reason
            )
            cloudBackups.insert(backup, at: 0)
            cloudBackups = Array(cloudBackups.prefix(20))
            recordSyncHistory(
                direction: .backup,
                status: .success,
                changedCount: snapshot.todos.count + snapshot.planTasks.count + snapshot.pomodoroSessions.count,
                message: "Cloud backup created"
            )
            triggerHaptic()
        } catch {
            recordSyncHistory(
                direction: .backup,
                status: .failed,
                message: error.localizedDescription
            )
        }
    }

    func restoreCloudBackup(_ backup: CloudBackupSnapshot) async {
        createLocalBackup(reason: "before_cloud_restore")

        guard entitlement.isCloudSyncAvailable else {
            recordSyncHistory(
                direction: .restore,
                status: .skipped,
                message: "Cloud restore requires Pro"
            )
            return
        }

        do {
            let identity = try await resolveCloudIdentity()
            let snapshot = try await cloudAPI.restoreCloudBackup(identity: identity, snapshotID: backup.id)
            todos = snapshot.todos
            planTasks = snapshot.planTasks
            pomodoroSessions = snapshot.pomodoroSessions
            profile = snapshot.profile
            settings = snapshot.settings
            syncGoalIfNeeded()
            savePersistentState()
            database.saveCloudPullCursor(Date())

            recordSyncHistory(
                direction: .restore,
                status: .success,
                changedCount: snapshot.todos.count + snapshot.planTasks.count + snapshot.pomodoroSessions.count,
                message: "Restored cloud backup"
            )
            triggerHaptic()
        } catch {
            recordSyncHistory(
                direction: .restore,
                status: .failed,
                message: error.localizedDescription
            )
        }
    }

    func performManualSync() async {
        await performCloudSync(
            reason: "manual_sync_before_merge",
            shouldRecordBackup: true,
            shouldRecordNoop: true,
            shouldHapticOnChange: true
        )
    }

    func performForegroundAutoSyncIfNeeded() async {
        guard hasLoadedInitialState else { return }
        guard entitlement.isCloudSyncAvailable else {
            return
        }
        guard !isCloudSyncInFlight else { return }

        if let lastAutoSyncAt = database.loadLastForegroundAutoSyncAt(),
           Date().timeIntervalSince(lastAutoSyncAt) < foregroundAutoSyncCooldown {
            return
        }

        database.saveLastForegroundAutoSyncAt(Date())
        await performCloudSync(
            reason: "auto_sync_before_merge",
            shouldRecordBackup: false,
            shouldRecordNoop: false,
            shouldHapticOnChange: false
        )
    }

    private func performCloudSync(
        reason: String,
        shouldRecordBackup: Bool,
        shouldRecordNoop: Bool,
        shouldHapticOnChange: Bool
    ) async {
        guard !isCloudSyncInFlight else { return }

        createLocalBackup(
            reason: reason,
            shouldRecordHistory: shouldRecordBackup,
            shouldHaptic: shouldHapticOnChange
        )

        guard entitlement.isCloudSyncAvailable else {
            if shouldRecordNoop {
                recordSyncHistory(
                    direction: .full,
                    status: .skipped,
                    message: "Cloud sync is unavailable in Free mode"
                )
            }
            return
        }

        isCloudSyncInFlight = true
        defer { isCloudSyncInFlight = false }

        let changes = database.pendingChangeLogs()
        do {
            let identity = try await resolveCloudIdentity()
            var uploadedCount = 0
            if !changes.isEmpty {
                let pushResponse = try await cloudAPI.push(
                    changes: changes,
                    userID: identity.userID,
                    deviceID: identity.deviceID
                )
                database.markChangeLogsSynced(ids: changes.map(\.id), syncedAt: pushResponse.cursor)
                uploadedCount = pushResponse.accepted
            }

            let pullResponse = try await cloudAPI.pull(
                userID: identity.userID,
                since: database.loadCloudPullCursor()
            )
            let pulledCount = applyCloudSyncPull(pullResponse)
            database.saveCloudPullCursor(pullResponse.cursor)
            pendingUploadCount = database.pendingChangeLogCount()

            let totalChangedCount = uploadedCount + pulledCount
            if totalChangedCount > 0 || shouldRecordNoop {
                recordSyncHistory(
                    direction: .full,
                    status: totalChangedCount == 0 ? .skipped : .success,
                    changedCount: totalChangedCount,
                    message: "Uploaded \(uploadedCount), pulled \(pulledCount)"
                )
            }
            if totalChangedCount > 0, shouldHapticOnChange {
                triggerHaptic()
            }
        } catch {
            pendingUploadCount = database.pendingChangeLogCount()
            recordSyncHistory(
                direction: .full,
                status: .failed,
                changedCount: changes.count,
                message: error.localizedDescription
            )
        }
    }

    func refreshStoreKitEntitlement() async {
        storeKitEntitlement = StoreKitEntitlementSnapshot(
            state: .loading,
            availableProductIDs: storeKitEntitlement.availableProductIDs,
            activeProductID: storeKitEntitlement.activeProductID,
            message: "Checking StoreKit subscription"
        )

        let snapshot = await storeKitClient.refreshEntitlement()
        storeKitEntitlement = snapshot
        await applyStoreKitEntitlement(snapshot)
    }

    func purchaseProSubscription() async {
        storeKitEntitlement = StoreKitEntitlementSnapshot(
            state: .loading,
            availableProductIDs: storeKitEntitlement.availableProductIDs,
            activeProductID: storeKitEntitlement.activeProductID,
            message: "Opening StoreKit purchase"
        )

        let snapshot = await storeKitClient.purchaseProMonthly()
        storeKitEntitlement = snapshot
        await applyStoreKitEntitlement(snapshot)
    }

    func restoreLocalBackup(_ backup: LocalBackupSnapshot) {
        createLocalBackup(reason: "before_restore")

        guard let snapshot = database.loadBackupSnapshot(backup) else {
            recordSyncHistory(
                direction: .restore,
                status: .failed,
                message: "Could not read local backup"
            )
            return
        }

        todos = snapshot.todos
        planTasks = snapshot.planTasks
        pomodoroSessions = snapshot.pomodoroSessions
        profile = snapshot.profile
        settings = snapshot.settings
        syncGoalIfNeeded()
        savePersistentState()

        recordSyncHistory(
            direction: .restore,
            status: .success,
            changedCount: snapshot.todos.count + snapshot.planTasks.count + snapshot.pomodoroSessions.count,
            message: "Restored local backup"
        )
        triggerHaptic()
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        displayName: String?,
        email: String?
    ) async {
        accountState = AccountState(
            user: accountState.user,
            provider: .apple,
            status: .signingIn,
            message: "Signing in with Apple",
            lastMigration: accountState.lastMigration
        )

        do {
            let anonymousIdentity = try await resolveCloudIdentity()
            let response = try await cloudAPI.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                deviceID: anonymousIdentity.deviceID,
                anonymousUserID: anonymousIdentity.userID,
                displayName: displayName,
                email: email
            )

            let session = AuthSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresAt: response.expiresAt
            )
            keychain.saveSession(session)

            accountState = AccountState(
                user: response.user,
                provider: .apple,
                status: .signedIn,
                message: response.migration?.migrated == true ? "Signed in · migrated cloud data" : "Signed in",
                lastMigration: response.migration
            )
            database.saveAccountState(accountState)

            cloudIdentity = CloudIdentity(
                userID: response.user.id,
                deviceID: anonymousIdentity.deviceID,
                createdAt: Date()
            )
            if let cloudIdentity {
                database.saveCloudIdentity(cloudIdentity)
            }

            if response.migration?.migrated == true {
                database.saveCloudPullCursor(Date(timeIntervalSince1970: 0))
            }

            recordSyncHistory(
                direction: .full,
                status: .success,
                changedCount: (response.migration?.plans ?? 0) + (response.migration?.todos ?? 0) + (response.migration?.sessions ?? 0),
                message: accountState.message
            )
            triggerHaptic()
        } catch {
            accountState = AccountState(
                user: accountState.user,
                provider: .apple,
                status: .failed,
                message: error.localizedDescription,
                lastMigration: accountState.lastMigration
            )
            database.saveAccountState(accountState)
            recordSyncHistory(
                direction: .full,
                status: .failed,
                message: "Apple sign in failed: \(error.localizedDescription)"
            )
        }
    }

    func refreshAccount() async {
        guard let session = keychain.loadSession() else {
            accountState = .signedOut
            database.saveAccountState(accountState)
            return
        }

        do {
            let response = try await cloudAPI.me(accessToken: session.accessToken)
            accountState = AccountState(
                user: response.user,
                provider: .apple,
                status: .signedIn,
                message: "Account refreshed",
                lastMigration: accountState.lastMigration
            )
            database.saveAccountState(accountState)

            entitlement = EntitlementState(
                tier: EntitlementTier(rawValue: response.entitlement.tier) ?? .free,
                cloudSyncEnabled: response.entitlement.cloudSyncEnabled,
                expiresAt: response.entitlement.expiresAt
            )
            database.saveEntitlement(entitlement)
        } catch {
            accountState = AccountState(
                user: accountState.user,
                provider: .apple,
                status: .failed,
                message: error.localizedDescription,
                lastMigration: accountState.lastMigration
            )
            database.saveAccountState(accountState)
        }
    }

    func logoutAccount() async {
        let session = keychain.loadSession()
        keychain.clearSession()
        if let session {
            _ = try? await cloudAPI.logout(
                refreshToken: session.refreshToken,
                deviceID: cloudIdentity?.deviceID
            )
        }

        accountState = .signedOut
        database.clearAccountState()
        recordSyncHistory(
            direction: .full,
            status: .success,
            message: "Signed out · local data kept"
        )
        triggerHaptic()
    }

#if DEBUG
    func mockStagingAccountLogin(
        nickname: String,
        email: String,
        debugSecret: String
    ) async {
        let trimmedSecret = debugSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSecret.isEmpty else {
            accountState = AccountState(
                user: accountState.user,
                provider: .apple,
                status: .failed,
                message: "Debug secret is required",
                lastMigration: accountState.lastMigration
            )
            database.saveAccountState(accountState)
            return
        }

        accountState = AccountState(
            user: accountState.user,
            provider: .apple,
            status: .signingIn,
            message: "Signing in with mock staging account",
            lastMigration: accountState.lastMigration
        )

        do {
            let anonymousIdentity = try await resolveCloudIdentity()
            let response = try await cloudAPI.mockStagingLogin(
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Jelly Dev" : nickname,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "dev@jellytodo.local" : email,
                deviceID: anonymousIdentity.deviceID,
                anonymousUserID: anonymousIdentity.userID,
                debugSecret: trimmedSecret
            )

            let session = AuthSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresAt: response.expiresAt
            )
            keychain.saveSession(session)

            accountState = AccountState(
                user: response.user,
                provider: .apple,
                status: .signedIn,
                message: response.migration?.migrated == true ? "Mock signed in · migrated cloud data" : "Mock signed in",
                lastMigration: response.migration
            )
            database.saveAccountState(accountState)

            cloudIdentity = CloudIdentity(
                userID: response.user.id,
                deviceID: anonymousIdentity.deviceID,
                createdAt: Date()
            )
            if let cloudIdentity {
                database.saveCloudIdentity(cloudIdentity)
            }

            recordSyncHistory(
                direction: .full,
                status: .success,
                changedCount: (response.migration?.plans ?? 0) + (response.migration?.todos ?? 0) + (response.migration?.sessions ?? 0),
                message: accountState.message
            )
            triggerHaptic()
        } catch {
            accountState = AccountState(
                user: accountState.user,
                provider: .apple,
                status: .failed,
                message: error.localizedDescription,
                lastMigration: accountState.lastMigration
            )
            database.saveAccountState(accountState)
            recordSyncHistory(
                direction: .full,
                status: .failed,
                message: "Mock staging login failed: \(error.localizedDescription)"
            )
        }
    }
#endif

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
        let focusSessions = sessions(in: range).filter { $0.type == .focus }
        let grouped = Dictionary(grouping: focusSessions) { session -> UUID in
            if let planTaskID = session.planTaskID {
                return planTaskID
            }

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
            let title = sessions.first(where: { !$0.planTitleSnapshot.isEmpty })?.planTitleSnapshot
                ?? planTasks.first(where: { $0.id == key })?.title
                ?? sessions.first(where: { !$0.todoTitleSnapshot.isEmpty })?.todoTitleSnapshot
                ?? relatedTodos.first?.title
                ?? "Focus"
            let itemCount = max(Set(sessions.compactMap(\.sourceTemplateID)).count, Set(relatedTodos.map(\.id)).count)

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
        let templateID = todos.first(where: { $0.id == todoID })?.isPlanTemplate == true ? todoID : nil
        return pomodoroSessions
            .filter {
                $0.type == .focus
                    && ($0.relatedTodoID == todoID || (templateID != nil && $0.sourceTemplateID == templateID))
            }
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
                    scheduledDates: isToday ? [calendar.startOfDay(for: now)] : [calendar.startOfDay(for: taskDate)],
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

    var debugCheckInSeedSummary: (records: Int, streak: Int, latestDate: Date?) {
        let debugRecords = checkInRecords.filter { $0.sourceTag == Self.debugCheckInSeedMarker }
        return (
            records: debugRecords.count,
            streak: debugRecords.isEmpty ? 0 : streak(endingAt: Date()),
            latestDate: debugRecords.map(\.date).max()
        )
    }

    func seedCheckInThirtyDayDebugData() {
        seedCheckInDebugData(totalDays: 30, pattern: .continuous)
    }

    func seedCheckInHundredDayDebugData() {
        seedCheckInDebugData(totalDays: 100, pattern: .continuous)
    }

    func seedCheckInMixedYearDebugData() {
        seedCheckInDebugData(totalDays: 180, pattern: .mixed)
    }

    func seedCheckInSparseYearDebugData() {
        seedCheckInDebugData(totalDays: 365, pattern: .sparse)
    }

    func clearCheckInDebugData() {
        checkInRecords.removeAll { $0.sourceTag == Self.debugCheckInSeedMarker }
        saveCheckIns()
        triggerHaptic()
    }

    func seedTodayCheckInPromptDebugState() {
        clearTodayCheckInMockState()

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        checkInRecords.removeAll { calendar.isDate($0.date, inSameDayAs: today) }
        let titles = ["考研数学收尾", "英语阅读复盘", "专业课错题整理"]
        let mockTodos = titles.enumerated().map { offset, title in
            TodoItem(
                id: UUID(),
                isAddedToToday: true,
                title: title,
                isCompleted: true,
                createdAt: calendar.date(byAdding: .minute, value: -(titles.count - offset) * 12, to: now) ?? now,
                updatedAt: now,
                taskDate: now,
                cycle: .daily,
                scheduleMode: .custom,
                scheduledDates: [calendar.startOfDay(for: now)],
                dailyDurationMinutes: 45 + offset * 10,
                focusTimerDirection: .countDown,
                note: Self.debugTodayCheckInMarker
            )
        }

        todos.append(contentsOf: mockTodos)
        saveTodos()
        saveCheckIns()
        evaluateTodayCheckIn()
        NotificationCenter.default.post(name: .todayCheckInMockActivated, object: nil)
        triggerHaptic()
    }

    func seedTodayCheckedInDebugState() {
        seedTodayCheckInPromptDebugState()

        let day = Calendar.current.startOfDay(for: Date())
        let summary = todayCheckInSummary(for: day)
        let record = DailyCheckInRecord(
            date: day,
            createdAt: Date(),
            completedTodoCount: summary.completed,
            totalTodoCount: summary.total,
            focusSeconds: summary.focusSeconds,
            isMakeUp: false,
            sourceTag: Self.debugTodayCheckInMarker
        )

        checkInRecords.removeAll {
            $0.sourceTag == Self.debugTodayCheckInMarker && Calendar.current.isDate($0.date, inSameDayAs: day)
        }
        checkInRecords.append(record)
        checkInRecords.sort { $0.date < $1.date }
        saveCheckIns()
        NotificationCenter.default.post(name: .todayCheckInMockActivated, object: nil)
        triggerHaptic()
    }

    func clearTodayCheckInMockState() {
        let today = Calendar.current.startOfDay(for: Date())
        todos.removeAll { $0.note == Self.debugTodayCheckInMarker }
        checkInRecords.removeAll {
            $0.sourceTag == Self.debugTodayCheckInMarker && Calendar.current.isDate($0.date, inSameDayAs: today)
        }
        presentedCheckInDate = nil
        saveTodos()
        saveCheckIns()
        triggerHaptic()
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
	                    sourceTemplateID: $0.sourceTemplateID,
	                    isAddedToToday: $0.isAddedToToday,
                    title: $0.title,
                    isCompleted: $0.isCompleted,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    taskDate: $0.taskDate,
                    cycle: $0.cycle,
                    scheduleMode: $0.scheduleMode,
                    recurrenceValue: $0.recurrenceValue,
                    scheduledDates: $0.scheduledDates,
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
	                    relatedTodoID: $0.todoID,
	                    sourceTemplateID: $0.sourceTemplateID,
	                    planTaskID: $0.planID,
	                    planTitleSnapshot: $0.planTitleSnapshot ?? "",
	                    todoTitleSnapshot: $0.todoTitleSnapshot ?? ""
	                )
            }

        planTasks.append(contentsOf: cloudPlans)
        todos.append(contentsOf: cloudTodos)
        pomodoroSessions.append(contentsOf: cloudSessions)

        savePlanTasks()
        saveTodos()
        saveSessions()
    }

    private func applyCloudSyncPull(_ response: CloudSyncPullResponse) -> Int {
        var changedCount = 0

        for cloudPlan in response.plans {
            if cloudPlan.deletedAt != nil {
                let beforeCount = planTasks.count
                planTasks.removeAll { $0.id == cloudPlan.id }
                if planTasks.count != beforeCount { changedCount += 1 }
                continue
            }

            let merged = PlanTask(
                id: cloudPlan.id,
                title: cloudPlan.title,
                createdAt: cloudPlan.createdAt,
                updatedAt: cloudPlan.updatedAt,
                isCollapsed: cloudPlan.isCollapsed
            )

            if let index = planTasks.firstIndex(where: { $0.id == cloudPlan.id }) {
                guard cloudPlan.updatedAt >= planTasks[index].updatedAt else { continue }
                if planTasks[index] != merged {
                    planTasks[index] = merged
                    changedCount += 1
                }
            } else {
                planTasks.append(merged)
                changedCount += 1
            }
        }

        for cloudTodo in response.todoItems {
            if cloudTodo.deletedAt != nil {
                let beforeCount = todos.count
                todos.removeAll { $0.id == cloudTodo.id }
                if todos.count != beforeCount { changedCount += 1 }
                continue
            }

            let merged = TodoItem(
	                id: cloudTodo.id,
	                planTaskID: cloudTodo.planID,
	                sourceTemplateID: cloudTodo.sourceTemplateID,
	                isAddedToToday: cloudTodo.isAddedToToday,
                title: cloudTodo.title,
                isCompleted: cloudTodo.isCompleted,
                createdAt: cloudTodo.createdAt,
                updatedAt: cloudTodo.updatedAt,
                taskDate: cloudTodo.taskDate,
                cycle: cloudTodo.cycle,
                scheduleMode: cloudTodo.scheduleMode,
                recurrenceValue: cloudTodo.recurrenceValue,
                scheduledDates: cloudTodo.scheduledDates,
                dailyDurationMinutes: cloudTodo.dailyDurationMinutes,
                focusTimerDirection: cloudTodo.focusTimerDirection,
                note: cloudTodo.note
            )

            if let index = todos.firstIndex(where: { $0.id == cloudTodo.id }) {
                guard cloudTodo.updatedAt >= todos[index].updatedAt else { continue }
                if todos[index] != merged {
                    todos[index] = merged
                    changedCount += 1
                }
            } else {
                todos.append(merged)
                changedCount += 1
            }
        }

        for cloudSession in response.pomodoroSessions {
            if cloudSession.deletedAt != nil {
                let beforeCount = pomodoroSessions.count
                pomodoroSessions.removeAll { $0.id == cloudSession.id }
                if pomodoroSessions.count != beforeCount { changedCount += 1 }
                continue
            }

            let merged = PomodoroSession(
                id: cloudSession.id,
                type: cloudSession.type,
                startAt: cloudSession.startAt,
	                endAt: cloudSession.endAt,
	                durationSeconds: cloudSession.durationSeconds,
	                relatedTodoID: cloudSession.todoID,
	                sourceTemplateID: cloudSession.sourceTemplateID,
	                planTaskID: cloudSession.planID,
	                planTitleSnapshot: cloudSession.planTitleSnapshot ?? "",
	                todoTitleSnapshot: cloudSession.todoTitleSnapshot ?? ""
	            )

            if !pomodoroSessions.contains(where: { $0.id == cloudSession.id }) {
                pomodoroSessions.append(merged)
                changedCount += 1
            }
        }

        if let cloudSettings = response.appSettings.max(by: { $0.updatedAt < $1.updatedAt }) {
            let merged = AppSettings(
                themeMode: cloudSettings.themeMode,
                hapticsEnabled: cloudSettings.hapticsEnabled,
                pomodoroGoalPerDay: cloudSettings.pomodoroGoalPerDay,
                textScale: cloudSettings.textScale ?? settings.textScale,
                language: cloudSettings.language,
                checkInIconSelection: cloudSettings.checkInIconSelection ?? settings.checkInIconSelection
            )
            if settings != merged {
                settings = merged
                syncGoalIfNeeded()
                changedCount += 1
            }
        }

        if changedCount > 0 {
            savePersistentState()
        }

        return changedCount
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

    private enum DebugCheckInPattern {
        case continuous
        case mixed
        case sparse
    }

    private static let debugPomodoroSeedMarker = "debug-pomodoro-chart-seed"
    private static let debugCheckInSeedMarker = "debug-checkin-seed"
    private static let debugTodayCheckInMarker = "debug-today-checkin-seed"
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

    private func normalizeLegacyPlanTodayItems() {
        var createdTemplates: [TodoItem] = []
        for index in todos.indices {
            guard todos[index].planTaskID != nil,
                  todos[index].sourceTemplateID == nil,
                  todos[index].isAddedToToday
            else { continue }

            let occurrence = todos[index]
            let template = TodoItem(
                id: UUID(),
                planTaskID: occurrence.planTaskID,
                sourceTemplateID: nil,
                isAddedToToday: false,
                title: occurrence.title,
                isCompleted: false,
                createdAt: occurrence.createdAt,
                updatedAt: Date(),
                taskDate: occurrence.taskDate,
                cycle: occurrence.cycle,
                scheduleMode: occurrence.scheduleMode,
                recurrenceValue: occurrence.recurrenceValue,
                scheduledDates: occurrence.scheduledDates,
                dailyDurationMinutes: occurrence.dailyDurationMinutes,
                focusTimerDirection: occurrence.focusTimerDirection,
                note: occurrence.note
            )
            createdTemplates.append(template)
            todos[index].sourceTemplateID = template.id
            todos[index].updatedAt = Date()
        }

        if !createdTemplates.isEmpty {
            todos.append(contentsOf: createdTemplates)
        }
    }

    private func shouldMaterialize(_ template: TodoItem, on date: Date) -> Bool {
        guard template.isPlanTemplate else { return false }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let hasOccurrenceToday = todos.contains {
            $0.sourceTemplateID == template.id && calendar.isDate($0.taskDate, inSameDayAs: day)
        }
        guard !hasOccurrenceToday else { return false }

        if template.hasExplicitSchedule {
            return template.normalizedScheduledDates().contains { calendar.isDate($0, inSameDayAs: day) }
        }

        switch template.scheduleMode {
        case .custom:
            switch template.cycle {
            case .manual:
                return false
            case .once:
                return !todos.contains { $0.sourceTemplateID == template.id }
            case .daily:
                return template.taskDate <= date
            case .weekly:
                return template.taskDate <= date
                    && calendar.component(.weekday, from: template.taskDate) == calendar.component(.weekday, from: date)
            case .monthly:
                return template.taskDate <= date && isMonthlyDue(template.taskDate, on: date)
            }
        case .daily:
            return true
        case .weekly:
            let weekday = template.recurrenceValue ?? calendar.component(.weekday, from: template.taskDate)
            return weekday == calendar.component(.weekday, from: day)
        case .monthly:
            let anchorDay = template.recurrenceValue ?? calendar.component(.day, from: template.taskDate)
            return isMonthlyDue(day: anchorDay, on: day)
        }
    }

    private func isMonthlyDue(_ templateDate: Date, on date: Date) -> Bool {
        let calendar = Calendar.current
        let templateDay = calendar.component(.day, from: templateDate)
        return isMonthlyDue(day: templateDay, on: date)
    }

    private func isMonthlyDue(day templateDay: Int, on date: Date) -> Bool {
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: date)
        let lastDay = calendar.range(of: .day, in: .month, for: date)?.upperBound.advanced(by: -1) ?? currentDay
        return currentDay == min(templateDay, lastDay)
    }

    private func upsertTodayOccurrence(
        from template: TodoItem,
        now: Date
    ) -> (todo: TodoItem, operation: String) {
        let calendar = Calendar.current
        if let existingIndex = todos.firstIndex(where: {
            $0.sourceTemplateID == template.id && calendar.isDateInToday($0.taskDate)
        }) {
            todos[existingIndex].title = template.title
            todos[existingIndex].cycle = template.cycle
            todos[existingIndex].scheduleMode = template.scheduleMode
            todos[existingIndex].recurrenceValue = template.recurrenceValue
            todos[existingIndex].scheduledDates = template.scheduledDates
            todos[existingIndex].dailyDurationMinutes = template.dailyDurationMinutes
            todos[existingIndex].focusTimerDirection = template.focusTimerDirection
            todos[existingIndex].note = template.note
            todos[existingIndex].planTaskID = template.planTaskID
            todos[existingIndex].isAddedToToday = true
            todos[existingIndex].updatedAt = now
            return (todos[existingIndex], "update")
        }

        let occurrence = TodoItem(
            id: UUID(),
            planTaskID: template.planTaskID,
            sourceTemplateID: template.id,
            isAddedToToday: true,
            title: template.title,
            isCompleted: false,
            createdAt: now,
            updatedAt: now,
            taskDate: calendar.startOfDay(for: now),
            cycle: template.cycle,
            scheduleMode: template.scheduleMode,
            recurrenceValue: template.recurrenceValue,
            scheduledDates: template.scheduledDates,
            dailyDurationMinutes: template.dailyDurationMinutes,
            focusTimerDirection: template.focusTimerDirection,
            note: template.note
        )
        todos.append(occurrence)
        return (occurrence, "create")
    }

    private func sanitizedNote(_ note: String) -> String {
        String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_000))
    }

    private func normalizedScheduleDates(_ dates: [Date], fallbackDate: Date) -> [Date] {
        let calendar = Calendar.current
        let normalized = dates.map { calendar.startOfDay(for: $0) }
        let unique = Set(normalized.map(\.timeIntervalSinceReferenceDate))
            .map(Date.init(timeIntervalSinceReferenceDate:))
            .sorted()
        return unique.isEmpty ? [calendar.startOfDay(for: fallbackDate)] : unique
    }

    private func legacyCycle(for mode: TodoScheduleMode) -> TodoTaskCycle {
        switch mode {
        case .custom:
            return .manual
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        }
    }

    private func templateAnchorDate(for mode: TodoScheduleMode, recurrenceValue: Int?, fallback: Date) -> Date {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())

        switch mode {
        case .custom:
            return fallback
        case .daily:
            return now
        case .weekly:
            let weekday = recurrenceValue ?? calendar.component(.weekday, from: fallback)
            return nextWeekdayDate(weekday: weekday, from: now) ?? fallback
        case .monthly:
            let day = recurrenceValue ?? calendar.component(.day, from: fallback)
            return nextMonthlyDate(day: day, from: now) ?? fallback
        }
    }

    private func nextWeekdayDate(weekday: Int, from start: Date) -> Date? {
        let calendar = Calendar.current
        var cursor = start
        for _ in 0..<7 {
            if calendar.component(.weekday, from: cursor) == weekday {
                return cursor
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return nil
    }

    private func nextMonthlyDate(day: Int, from start: Date) -> Date? {
        let calendar = Calendar.current
        for offset in 0..<2 {
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: start),
                  let monthRange = calendar.range(of: .day, in: .month, for: monthDate),
                  let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))
            else { continue }

            let targetDay = min(day, monthRange.count)
            if let targetDate = calendar.date(byAdding: .day, value: targetDay - 1, to: monthStart), targetDate >= start {
                return targetDate
            }
        }
        return nil
    }

    private func pomodoroSessionSnapshot(for todoID: UUID?) -> (sourceTemplateID: UUID?, planTaskID: UUID?, planTitle: String, todoTitle: String)? {
        guard let todoID, let todo = todos.first(where: { $0.id == todoID }) else { return nil }
        let plan = todo.planTaskID.flatMap { planID in planTasks.first(where: { $0.id == planID }) }
        let template = todo.sourceTemplateID.flatMap { templateID in todos.first(where: { $0.id == templateID }) }
        return (
            sourceTemplateID: todo.sourceTemplateID,
            planTaskID: todo.planTaskID,
            planTitle: plan?.title ?? "",
            todoTitle: template?.title ?? todo.title
        )
    }

    private func sanitize(_ title: String) -> String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
    }

    private func savePersistentState() {
        database.saveSnapshot(currentSnapshot())
        database.saveEntitlement(entitlement)
        storage.save(todos, for: .todos)
        storage.save(planTasks, for: .planTasks)
        storage.save(pomodoroSessions, for: .pomodoroSessions)
        storage.save(checkInRecords, for: .checkInRecords)
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

    private func saveCheckIns() {
        database.saveSnapshot(currentSnapshot())
        storage.save(checkInRecords, for: .checkInRecords)
    }

    private func saveProfile() {
        database.saveProfile(profile)
        storage.save(profile, for: .userProfile)
    }

    private func saveSettings() {
        database.saveSettings(settings)
        storage.save(settings, for: .appSettings)
    }

    private func currentSnapshot() -> StorageSnapshot {
        StorageSnapshot(
            todos: todos,
            planTasks: planTasks,
            pomodoroSessions: pomodoroSessions,
            checkInRecords: checkInRecords,
            profile: profile,
            settings: settings
        )
    }

    private func evaluateTodayCheckIn() {
        let summary = todayCheckInSummary()
        guard summary.total > 0 else { return }
        if hasCheckedIn(on: Date()) {
            createOrRefreshCheckIn(for: Date(), isMakeUp: checkInRecord(on: Date())?.isMakeUp == true, triggerPresentation: false)
        }
    }

    private func createOrRefreshCheckIn(for date: Date, isMakeUp: Bool, triggerPresentation: Bool) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let summary = todayCheckInSummary(for: day)
        let record = DailyCheckInRecord(
            id: checkInRecord(on: day)?.id ?? UUID(),
            date: day,
            createdAt: Date(),
            completedTodoCount: max(summary.completed, 0),
            totalTodoCount: max(summary.total, summary.completed),
            focusSeconds: summary.focusSeconds,
            isMakeUp: isMakeUp,
            sourceTag: checkInRecord(on: day)?.sourceTag
        )

        if let index = checkInRecords.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            checkInRecords[index] = record
        } else {
            checkInRecords.append(record)
            checkInRecords.sort { $0.date < $1.date }
        }

        saveCheckIns()
        if triggerPresentation {
            presentedCheckInDate = day
        }
        triggerHaptic()
    }

    private func seedCheckInDebugData(totalDays: Int, pattern: DebugCheckInPattern) {
        clearCheckInDebugData()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var seededRecords: [DailyCheckInRecord] = []
        var cursor = 0

        while seededRecords.count < totalDays {
            guard let date = calendar.date(byAdding: .day, value: -cursor, to: today) else { break }
            let includeDay: Bool

            switch pattern {
            case .continuous:
                includeDay = true
            case .mixed:
                includeDay = (cursor % 9 != 4) && (cursor % 13 != 7)
            case .sparse:
                includeDay = cursor % 2 == 0 || cursor % 7 == 0
            }

            if includeDay, !checkInRecords.contains(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                let completed = max(1, 1 + ((cursor * 3) % 6))
                let total = max(completed, completed + (cursor % 3 == 0 ? 1 : 0))
                let focusMinutes = max(20, completed * 18 + (cursor % 5) * 12)
                seededRecords.append(
                    DailyCheckInRecord(
                        date: date,
                        createdAt: date.addingTimeInterval(21 * 60 * 60),
                        completedTodoCount: completed,
                        totalTodoCount: total,
                        focusSeconds: focusMinutes * 60,
                        isMakeUp: pattern != .continuous && cursor % 11 == 0,
                        sourceTag: Self.debugCheckInSeedMarker
                    )
                )
            }

            cursor += 1
            if cursor > totalDays * 3 { break }
        }

        checkInRecords.append(contentsOf: seededRecords)
        checkInRecords.sort { $0.date < $1.date }
        saveCheckIns()
        triggerHaptic()
    }

    private func streak(endingAt referenceDate: Date) -> Int {
        let calendar = Calendar.current
        let availableDays = Set(checkInRecords.map { calendar.startOfDay(for: $0.date).timeIntervalSinceReferenceDate })
        var streak = 0
        var cursor = calendar.startOfDay(for: referenceDate)

        if !availableDays.contains(cursor.timeIntervalSinceReferenceDate),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
           availableDays.contains(yesterday.timeIntervalSinceReferenceDate) {
            cursor = yesterday
        }

        while availableDays.contains(cursor.timeIntervalSinceReferenceDate) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private func recordSyncHistory(
        direction: SyncDirection,
        status: SyncStatus,
        changedCount: Int = 0,
        message: String
    ) {
        let entry = SyncHistoryEntry(
            id: UUID(),
            direction: direction,
            status: status,
            changedCount: changedCount,
            message: String(message.prefix(160)),
            createdAt: Date()
        )
        syncHistory.insert(entry, at: 0)
        syncHistory = Array(syncHistory.prefix(20))
        database.insertSyncHistory(entry)
    }

    private func applyStoreKitEntitlement(_ snapshot: StoreKitEntitlementSnapshot) async {
        guard snapshot.state == .active else { return }

        entitlement = EntitlementState(
            tier: .pro,
            cloudSyncEnabled: true,
            expiresAt: nil
        )
        database.saveEntitlement(entitlement)

        guard let transaction = snapshot.transaction else { return }

        do {
            let identity = try await resolveCloudIdentity()
            let response = try await cloudAPI.syncStoreKitEntitlement(
                identity: identity,
                transaction: transaction
            )
            recordSyncHistory(
                direction: .full,
                status: response.cloudSyncEnabled ? .success : .failed,
                message: "StoreKit entitlement synced: \(response.source)"
            )
        } catch {
            recordSyncHistory(
                direction: .full,
                status: .failed,
                message: "StoreKit entitlement sync failed: \(error.localizedDescription)"
            )
        }
    }

    private func resolveCloudIdentity() async throws -> CloudIdentity {
        if let cloudIdentity {
            return cloudIdentity
        }

        if let savedIdentity = database.loadCloudIdentity() {
            cloudIdentity = savedIdentity
            return savedIdentity
        }

        let newIdentity = try await cloudAPI.createAnonymousIdentity()
        cloudIdentity = newIdentity
        database.saveCloudIdentity(newIdentity)
        recordSyncHistory(
            direction: .full,
            status: .success,
            message: "Cloud identity created"
        )
        return newIdentity
    }

    private func logCloudChange<T: Codable>(
        entityType: String,
        entityID: String,
        operation: String,
        payload: T
    ) {
        guard entitlement.isCloudSyncAvailable else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload),
              let payloadString = String(data: data, encoding: .utf8)
        else { return }

        database.appendChangeLog(
            entityType: entityType,
            entityID: entityID,
            operation: operation,
            payload: payloadString
        )
        pendingUploadCount = database.pendingChangeLogCount()
    }

    private func triggerHaptic() {
#if canImport(UIKit)
        guard settings.hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
#endif
    }
}

struct CheckInCalendarDay: Identifiable, Equatable {
    let id: String
    let date: Date?
    let record: DailyCheckInRecord?
    let isToday: Bool
    let isMakeUpAvailable: Bool

    init(
        id: String? = nil,
        date: Date?,
        record: DailyCheckInRecord?,
        isToday: Bool,
        isMakeUpAvailable: Bool
    ) {
        self.id = id ?? date.map { "date-\(Int($0.timeIntervalSince1970))" } ?? UUID().uuidString
        self.date = date
        self.record = record
        self.isToday = isToday
        self.isMakeUpAvailable = isMakeUpAvailable
    }

    static func placeholder(_ id: String) -> CheckInCalendarDay {
        CheckInCalendarDay(id: id, date: nil, record: nil, isToday: false, isMakeUpAvailable: false)
    }
}
