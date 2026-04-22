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
            profile = appState.snapshot.profile
            settings = appState.snapshot.settings
            entitlement = appState.entitlement
            cloudIdentity = appState.cloudIdentity
            accountState = appState.accountState
            syncHistory = appState.syncHistory
            localBackups = appState.localBackups
            pendingUploadCount = appState.pendingUploadCount
            syncGoalIfNeeded()
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
        cycle: TodoTaskCycle = .daily,
        dailyDurationMinutes: Int = 25,
        focusTimerDirection: FocusTimerDirection = .countDown
    ) {
        let trimmed = sanitize(title)
        guard !trimmed.isEmpty else { return }
        guard planTasks.contains(where: { $0.id == planTaskID }) else { return }

        let now = Date()
        let todo = TodoItem(
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
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isAddedToToday = true
        todos[index].taskDate = Date()
        todos[index].updatedAt = Date()
        triggerHaptic()
        saveTodos()
        logCloudChange(entityType: "todo_item", entityID: id.uuidString, operation: "update", payload: todos[index])
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
        logCloudChange(entityType: "todo_item", entityID: id.uuidString, operation: "update", payload: todos[index])
    }

    func deleteTodo(id: UUID) {
        let payload = todos.first(where: { $0.id == id })
        todos.removeAll { $0.id == id }
        saveTodos()
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
        logCloudChange(entityType: "todo_item", entityID: id.uuidString, operation: "update", payload: todos[index])
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
                isAddedToToday: cloudTodo.isAddedToToday,
                title: cloudTodo.title,
                isCompleted: cloudTodo.isCompleted,
                createdAt: cloudTodo.createdAt,
                updatedAt: cloudTodo.updatedAt,
                taskDate: cloudTodo.taskDate,
                cycle: cloudTodo.cycle,
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
                relatedTodoID: cloudSession.todoID
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
                useLargeText: cloudSettings.useLargeText,
                language: cloudSettings.language
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
        database.saveSnapshot(currentSnapshot())
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

    private func currentSnapshot() -> StorageSnapshot {
        StorageSnapshot(
            todos: todos,
            planTasks: planTasks,
            pomodoroSessions: pomodoroSessions,
            profile: profile,
            settings: settings
        )
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
