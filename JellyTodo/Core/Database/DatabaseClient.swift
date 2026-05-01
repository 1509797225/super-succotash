import Foundation
import SQLite3

struct DatabaseClient {
    private let databaseURL: URL

    init(databaseURL: URL = Self.defaultDatabaseURL()) {
        self.databaseURL = databaseURL
    }

    func loadSnapshot(legacySnapshot: StorageSnapshot) -> StorageSnapshot {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try setupSchema(in: database)
            try migrateLegacyIfNeeded(legacySnapshot, in: database)
            return try readSnapshot(from: database)
        } catch {
            return legacySnapshot
        }
    }

    func saveTodos(_ todos: [TodoItem]) {
        write { database in
            try replaceTodos(todos, in: database)
        }
    }

    func savePlanTasks(_ planTasks: [PlanTask]) {
        write { database in
            try replacePlanTasks(planTasks, in: database)
        }
    }

    func saveSessions(_ sessions: [PomodoroSession]) {
        write { database in
            try replaceSessions(sessions, in: database)
        }
    }

    func saveProfile(_ profile: UserProfile) {
        write { database in
            try replaceProfile(profile, in: database)
        }
    }

    func saveSettings(_ settings: AppSettings) {
        write { database in
            try replaceSettings(settings, in: database)
        }
    }

    func loadEntitlement() -> EntitlementState {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try setupSchema(in: database)
            return try readEntitlement(from: database)
        } catch {
            return .default
        }
    }

    func saveEntitlement(_ entitlement: EntitlementState) {
        write { database in
            try replaceEntitlement(entitlement, in: database)
        }
    }

    func loadSyncHistory(limit: Int = 20) -> [SyncHistoryEntry] {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try setupSchema(in: database)
            return try readSyncHistory(limit: limit, from: database)
        } catch {
            return []
        }
    }

    func loadLocalBackupSnapshots(limit: Int = 10) -> [LocalBackupSnapshot] {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try setupSchema(in: database)
            return try readLocalBackupSnapshots(limit: limit, from: database)
        } catch {
            return []
        }
    }

    func createLocalBackup(snapshot: StorageSnapshot, reason: String) -> LocalBackupSnapshot? {
        do {
            let backup = try writeSnapshotFile(snapshot: snapshot, reason: reason)
            try writeThrowing { database in
                try insertLocalBackupSnapshot(backup, in: database)
            }
            return backup
        } catch {
            assertionFailure("SQLite backup failed: \(error.localizedDescription)")
            return nil
        }
    }

    func loadBackupSnapshot(_ backup: LocalBackupSnapshot) -> StorageSnapshot? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: backup.snapshotPath))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(StorageSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    func insertSyncHistory(_ entry: SyncHistoryEntry) {
        write { database in
            try insertSyncHistory(entry, in: database)
        }
    }

    func appendChangeLog(entityType: String, entityID: String, operation: String, payload: String) {
        write { database in
            try insertChangeLog(
                id: UUID(),
                entityType: entityType,
                entityID: entityID,
                operation: operation,
                payload: payload,
                createdAt: Date(),
                in: database
            )
        }
    }

    func pendingChangeLogCount() -> Int {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try setupSchema(in: database)
            return try countPendingChangeLogs(in: database)
        } catch {
            return 0
        }
    }

    func pendingChangeLogs(limit: Int = 100) -> [ChangeLogEntry] {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try setupSchema(in: database)
            return try readPendingChangeLogs(limit: limit, from: database)
        } catch {
            return []
        }
    }

    func markChangeLogsSynced(ids: [UUID], syncedAt: Date = Date()) {
        guard !ids.isEmpty else { return }
        write { database in
            for id in ids {
                try markChangeLogSynced(id: id, syncedAt: syncedAt, in: database)
            }
        }
    }

    func loadCloudPullCursor() -> Date? {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try setupSchema(in: database)
            guard let value = try metaValue(for: "cloud_pull_cursor", in: database) else { return nil }
            return Date(databaseString: value)
        } catch {
            return nil
        }
    }

    func saveCloudPullCursor(_ cursor: Date) {
        write { database in
            try setMetaValue(cursor.databaseString, for: "cloud_pull_cursor", in: database)
        }
    }

    func loadLastForegroundAutoSyncAt() -> Date? {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try setupSchema(in: database)
            guard let value = try metaValue(for: "last_foreground_auto_sync_at", in: database) else { return nil }
            return Date(databaseString: value)
        } catch {
            return nil
        }
    }

    func saveLastForegroundAutoSyncAt(_ date: Date) {
        write { database in
            try setMetaValue(date.databaseString, for: "last_foreground_auto_sync_at", in: database)
        }
    }

    func loadCloudIdentity() -> CloudIdentity? {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try setupSchema(in: database)
            guard let value = try metaValue(for: "cloud_identity", in: database),
                  let data = value.data(using: .utf8)
            else { return nil }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CloudIdentity.self, from: data)
        } catch {
            return nil
        }
    }

    func saveCloudIdentity(_ identity: CloudIdentity) {
        write { database in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(identity)
            guard let value = String(data: data, encoding: .utf8) else { return }
            try setMetaValue(value, for: "cloud_identity", in: database)
        }
    }

    func loadAccountState() -> AccountState {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try setupSchema(in: database)
            guard let value = try metaValue(for: "account_state", in: database),
                  let data = value.data(using: .utf8)
            else { return .signedOut }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AccountState.self, from: data)
        } catch {
            return .signedOut
        }
    }

    func saveAccountState(_ state: AccountState) {
        write { database in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            guard let value = String(data: data, encoding: .utf8) else { return }
            try setMetaValue(value, for: "account_state", in: database)
        }
    }

    func clearAccountState() {
        write { database in
            try run(sql: "DELETE FROM meta WHERE key = ?;", in: database) { statement in
                sqlite3_bind_text(statement, 1, "account_state", -1, SQLITE_TRANSIENT)
            }
        }
    }

    func saveSnapshot(_ snapshot: StorageSnapshot) {
        write { database in
            try replacePlanTasks(snapshot.planTasks, in: database)
            try replaceTodos(snapshot.todos, in: database)
            try replaceSessions(snapshot.pomodoroSessions, in: database)
            try replaceCheckInRecords(snapshot.checkInRecords, in: database)
            try replaceProfile(snapshot.profile, in: database)
            try replaceSettings(snapshot.settings, in: database)
        }
    }

    private func write(_ operation: (OpaquePointer) throws -> Void) {
        do {
            try writeThrowing(operation)
        } catch {
            assertionFailure("SQLite write failed: \(error.localizedDescription)")
        }
    }

    private func writeThrowing(_ operation: (OpaquePointer) throws -> Void) throws {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try setupSchema(in: database)
            try transaction(in: database) {
                try operation(database)
            }
        } catch {
            throw error
        }
    }

    private static func defaultDatabaseURL() -> URL {
        let fileManager = FileManager.default
        let directory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        return directory.appendingPathComponent("JellyTodo.sqlite")
    }

    private func backupDirectory() throws -> URL {
        let directory = databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeSnapshotFile(snapshot: StorageSnapshot, reason: String) throws -> LocalBackupSnapshot {
        let id = UUID()
        let createdAt = Date()
        let fileURL = try backupDirectory().appendingPathComponent("\(id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])

        return LocalBackupSnapshot(
            id: id,
            reason: String(reason.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)),
            snapshotPath: fileURL.path,
            plansCount: snapshot.planTasks.count,
            todosCount: snapshot.todos.count,
            sessionsCount: snapshot.pomodoroSessions.count,
            createdAt: createdAt
        )
    }

    private func openDatabase() throws -> OpaquePointer {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK, let database else {
            throw DatabaseError.openFailed(message: String(cString: sqlite3_errmsg(database)))
        }

        try execute("PRAGMA foreign_keys = ON;", in: database)
        try execute("PRAGMA journal_mode = WAL;", in: database)
        return database
    }

    private func setupSchema(in database: OpaquePointer) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS meta (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS plans (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              deleted_at TEXT,
              is_collapsed INTEGER NOT NULL DEFAULT 0,
              is_archived INTEGER NOT NULL DEFAULT 0,
              sort_order INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS todo_items (
              id TEXT PRIMARY KEY,
              plan_id TEXT,
              source_template_id TEXT,
              title TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              is_completed INTEGER NOT NULL DEFAULT 0,
              is_added_to_today INTEGER NOT NULL DEFAULT 1,
              task_date TEXT NOT NULL,
              cycle TEXT NOT NULL DEFAULT 'daily',
              schedule_mode TEXT NOT NULL DEFAULT 'custom',
              recurrence_value INTEGER,
              scheduled_dates TEXT NOT NULL DEFAULT '[]',
              daily_duration_minutes INTEGER NOT NULL DEFAULT 25,
              focus_timer_direction TEXT NOT NULL DEFAULT 'countDown',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              deleted_at TEXT,
              sort_order INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS pomodoro_sessions (
              id TEXT PRIMARY KEY,
              todo_id TEXT,
              source_template_id TEXT,
              plan_id TEXT,
              plan_title_snapshot TEXT NOT NULL DEFAULT '',
              todo_title_snapshot TEXT NOT NULL DEFAULT '',
              type TEXT NOT NULL,
              start_at TEXT NOT NULL,
              end_at TEXT NOT NULL,
              duration_seconds INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              deleted_at TEXT
            );

            CREATE TABLE IF NOT EXISTS user_profile (
              id TEXT PRIMARY KEY DEFAULT 'current',
              nickname TEXT NOT NULL DEFAULT '',
              signature TEXT NOT NULL DEFAULT '',
              daily_goal INTEGER NOT NULL DEFAULT 4,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS app_settings (
              id TEXT PRIMARY KEY DEFAULT 'current',
              theme_mode TEXT NOT NULL DEFAULT 'pureWhite',
              language TEXT NOT NULL DEFAULT 'en',
              haptics_enabled INTEGER NOT NULL DEFAULT 1,
              pomodoro_goal_per_day INTEGER NOT NULL DEFAULT 4,
              use_large_text INTEGER NOT NULL DEFAULT 1,
              text_scale TEXT NOT NULL DEFAULT 'medium',
              check_in_icon_series_id TEXT NOT NULL DEFAULT 'doodleEmoji',
              check_in_icon_pack_id TEXT NOT NULL DEFAULT 'doodle01',
              item_edge_effect_enabled INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS entitlement_state (
              id TEXT PRIMARY KEY DEFAULT 'current',
              tier TEXT NOT NULL DEFAULT 'free',
              cloud_sync_enabled INTEGER NOT NULL DEFAULT 0,
              expires_at TEXT,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS change_logs (
              id TEXT PRIMARY KEY,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              operation TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL,
              synced_at TEXT
            );

            CREATE TABLE IF NOT EXISTS sync_history (
              id TEXT PRIMARY KEY,
              direction TEXT NOT NULL,
              status TEXT NOT NULL,
              changed_count INTEGER NOT NULL DEFAULT 0,
              message TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS local_backup_snapshots (
              id TEXT PRIMARY KEY,
              reason TEXT NOT NULL,
              snapshot_path TEXT NOT NULL,
              plans_count INTEGER NOT NULL DEFAULT 0,
              todos_count INTEGER NOT NULL DEFAULT 0,
              sessions_count INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_todo_plan_id ON todo_items(plan_id);
            CREATE INDEX IF NOT EXISTS idx_todo_task_date ON todo_items(task_date);
            CREATE INDEX IF NOT EXISTS idx_session_todo_id ON pomodoro_sessions(todo_id);
            CREATE INDEX IF NOT EXISTS idx_session_end_at ON pomodoro_sessions(end_at);
            CREATE INDEX IF NOT EXISTS idx_sync_history_created_at ON sync_history(created_at);
            CREATE INDEX IF NOT EXISTS idx_backup_snapshots_created_at ON local_backup_snapshots(created_at);
            """,
            in: database
        )

        try addColumnIfMissing("source_template_id", definition: "TEXT", to: "todo_items", in: database)
        try addColumnIfMissing("schedule_mode", definition: "TEXT NOT NULL DEFAULT 'custom'", to: "todo_items", in: database)
        try addColumnIfMissing("recurrence_value", definition: "INTEGER", to: "todo_items", in: database)
        try addColumnIfMissing("scheduled_dates", definition: "TEXT NOT NULL DEFAULT '[]'", to: "todo_items", in: database)
        try addColumnIfMissing("is_archived", definition: "INTEGER NOT NULL DEFAULT 0", to: "plans", in: database)
        try addColumnIfMissing("source_template_id", definition: "TEXT", to: "pomodoro_sessions", in: database)
        try addColumnIfMissing("plan_id", definition: "TEXT", to: "pomodoro_sessions", in: database)
        try addColumnIfMissing("plan_title_snapshot", definition: "TEXT NOT NULL DEFAULT ''", to: "pomodoro_sessions", in: database)
        try addColumnIfMissing("todo_title_snapshot", definition: "TEXT NOT NULL DEFAULT ''", to: "pomodoro_sessions", in: database)
        try addColumnIfMissing("text_scale", definition: "TEXT NOT NULL DEFAULT 'medium'", to: "app_settings", in: database)
        try addColumnIfMissing("check_in_icon_series_id", definition: "TEXT NOT NULL DEFAULT 'doodleEmoji'", to: "app_settings", in: database)
        try addColumnIfMissing("check_in_icon_pack_id", definition: "TEXT NOT NULL DEFAULT 'doodle01'", to: "app_settings", in: database)
        try addColumnIfMissing("item_edge_effect_enabled", definition: "INTEGER NOT NULL DEFAULT 0", to: "app_settings", in: database)
    }

    private func migrateLegacyIfNeeded(_ legacySnapshot: StorageSnapshot, in database: OpaquePointer) throws {
        guard try metaValue(for: "legacy_migrated_v1", in: database) == nil else { return }

        if legacySnapshot.hasContent {
            try transaction(in: database) {
                try replacePlanTasks(legacySnapshot.planTasks, in: database)
                try replaceTodos(legacySnapshot.todos, in: database)
                try replaceSessions(legacySnapshot.pomodoroSessions, in: database)
                try replaceCheckInRecords(legacySnapshot.checkInRecords, in: database)
                try replaceProfile(legacySnapshot.profile, in: database)
                try replaceSettings(legacySnapshot.settings, in: database)
                try setMetaValue("true", for: "legacy_migrated_v1", in: database)
            }
        } else {
            try setMetaValue("true", for: "legacy_migrated_v1", in: database)
        }
    }

    private func readSnapshot(from database: OpaquePointer) throws -> StorageSnapshot {
        StorageSnapshot(
            todos: try readTodos(from: database),
            planTasks: try readPlanTasks(from: database),
            pomodoroSessions: try readSessions(from: database),
            checkInRecords: try readCheckInRecords(from: database),
            profile: try readProfile(from: database),
            settings: try readSettings(from: database)
        )
    }

    private func readCheckInRecords(from database: OpaquePointer) throws -> [DailyCheckInRecord] {
        guard let value = try metaValue(for: "check_in_records", in: database),
              let data = value.data(using: .utf8)
        else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([DailyCheckInRecord].self, from: data)
    }

    private func readPlanTasks(from database: OpaquePointer) throws -> [PlanTask] {
        try rows(
            sql: "SELECT id, title, created_at, updated_at, is_collapsed, is_archived FROM plans WHERE deleted_at IS NULL ORDER BY created_at ASC;",
            in: database
        ) { statement in
            PlanTask(
                id: uuid(column: 0, statement: statement),
                title: string(column: 1, statement: statement),
                createdAt: date(column: 2, statement: statement),
                updatedAt: date(column: 3, statement: statement),
                isCollapsed: bool(column: 4, statement: statement),
                isArchived: bool(column: 5, statement: statement)
            )
        }
    }

    private func readTodos(from database: OpaquePointer) throws -> [TodoItem] {
        try rows(
            sql: """
            SELECT id, plan_id, source_template_id, is_added_to_today, title, is_completed, created_at, updated_at, task_date,
                   cycle, schedule_mode, recurrence_value, scheduled_dates, daily_duration_minutes, focus_timer_direction, note
            FROM todo_items
            WHERE deleted_at IS NULL
            ORDER BY created_at ASC;
            """,
            in: database
        ) { statement in
            TodoItem(
                id: uuid(column: 0, statement: statement),
                planTaskID: optionalUUID(column: 1, statement: statement),
                sourceTemplateID: optionalUUID(column: 2, statement: statement),
                isAddedToToday: bool(column: 3, statement: statement),
                title: string(column: 4, statement: statement),
                isCompleted: bool(column: 5, statement: statement),
                createdAt: date(column: 6, statement: statement),
                updatedAt: date(column: 7, statement: statement),
                taskDate: date(column: 8, statement: statement),
                cycle: TodoTaskCycle(rawValue: string(column: 9, statement: statement)) ?? .daily,
                scheduleMode: TodoScheduleMode(rawValue: string(column: 10, statement: statement)),
                recurrenceValue: optionalInt(column: 11, statement: statement),
                scheduledDates: decodeDateArray(string(column: 12, statement: statement)),
                dailyDurationMinutes: int(column: 13, statement: statement),
                focusTimerDirection: FocusTimerDirection(rawValue: string(column: 14, statement: statement)) ?? .countDown,
                note: string(column: 15, statement: statement)
            )
        }
    }

    private func readSessions(from database: OpaquePointer) throws -> [PomodoroSession] {
        try rows(
            sql: """
            SELECT id, type, start_at, end_at, duration_seconds, todo_id,
                   source_template_id, plan_id, plan_title_snapshot, todo_title_snapshot
            FROM pomodoro_sessions
            WHERE deleted_at IS NULL
            ORDER BY end_at ASC;
            """,
            in: database
        ) { statement in
            PomodoroSession(
                id: uuid(column: 0, statement: statement),
                type: PomodoroSessionType(rawValue: string(column: 1, statement: statement)) ?? .focus,
                startAt: date(column: 2, statement: statement),
                endAt: date(column: 3, statement: statement),
                durationSeconds: int(column: 4, statement: statement),
                relatedTodoID: optionalUUID(column: 5, statement: statement),
                sourceTemplateID: optionalUUID(column: 6, statement: statement),
                planTaskID: optionalUUID(column: 7, statement: statement),
                planTitleSnapshot: string(column: 8, statement: statement),
                todoTitleSnapshot: string(column: 9, statement: statement)
            )
        }
    }

    private func readProfile(from database: OpaquePointer) throws -> UserProfile {
        let result = try rows(
            sql: "SELECT nickname, signature, daily_goal FROM user_profile WHERE id = 'current' LIMIT 1;",
            in: database
        ) { statement in
            UserProfile(
                nickname: string(column: 0, statement: statement),
                signature: string(column: 1, statement: statement),
                dailyGoal: int(column: 2, statement: statement)
            )
        }
        return result.first ?? .default
    }

    private func readSettings(from database: OpaquePointer) throws -> AppSettings {
        let result = try rows(
            sql: """
            SELECT theme_mode, haptics_enabled, pomodoro_goal_per_day, use_large_text, language, text_scale, check_in_icon_series_id, check_in_icon_pack_id, item_edge_effect_enabled
            FROM app_settings
            WHERE id = 'current'
            LIMIT 1;
            """,
            in: database
        ) { statement in
            AppSettings(
                themeMode: AppThemeMode(rawValue: string(column: 0, statement: statement)) ?? .blackWhite,
                hapticsEnabled: bool(column: 1, statement: statement),
                pomodoroGoalPerDay: int(column: 2, statement: statement),
                textScale: AppTextScale(rawValue: string(column: 5, statement: statement)) ?? (bool(column: 3, statement: statement) ? .large : .medium),
                language: AppLanguage(rawValue: string(column: 4, statement: statement)) ?? .english,
                checkInIconSelection: CheckInIconSelection(
                    seriesID: string(column: 6, statement: statement).isEmpty ? CheckInIconSelection.default.seriesID : string(column: 6, statement: statement),
                    packID: string(column: 7, statement: statement).isEmpty ? CheckInIconSelection.default.packID : string(column: 7, statement: statement)
                ),
                itemEdgeEffectEnabled: bool(column: 8, statement: statement)
            )
        }
        return result.first ?? .default
    }

    private func readEntitlement(from database: OpaquePointer) throws -> EntitlementState {
        let result = try rows(
            sql: """
            SELECT tier, cloud_sync_enabled, expires_at
            FROM entitlement_state
            WHERE id = 'current'
            LIMIT 1;
            """,
            in: database
        ) { statement in
            EntitlementState(
                tier: EntitlementTier(rawValue: string(column: 0, statement: statement)) ?? .free,
                cloudSyncEnabled: bool(column: 1, statement: statement),
                expiresAt: optionalDate(column: 2, statement: statement)
            )
        }
        return result.first ?? .default
    }

    private func readSyncHistory(limit: Int, from database: OpaquePointer) throws -> [SyncHistoryEntry] {
        try rows(
            sql: """
            SELECT id, direction, status, changed_count, message, created_at
            FROM sync_history
            ORDER BY created_at DESC
            LIMIT ?;
            """,
            in: database,
            bindings: { statement in
                bind(limit, at: 1, statement: statement)
            }
        ) { statement in
            SyncHistoryEntry(
                id: uuid(column: 0, statement: statement),
                direction: SyncDirection(rawValue: string(column: 1, statement: statement)) ?? .full,
                status: SyncStatus(rawValue: string(column: 2, statement: statement)) ?? .skipped,
                changedCount: int(column: 3, statement: statement),
                message: string(column: 4, statement: statement),
                createdAt: date(column: 5, statement: statement)
            )
        }
    }

    private func readLocalBackupSnapshots(limit: Int, from database: OpaquePointer) throws -> [LocalBackupSnapshot] {
        try rows(
            sql: """
            SELECT id, reason, snapshot_path, plans_count, todos_count, sessions_count, created_at
            FROM local_backup_snapshots
            ORDER BY created_at DESC
            LIMIT ?;
            """,
            in: database,
            bindings: { statement in
                bind(limit, at: 1, statement: statement)
            }
        ) { statement in
            LocalBackupSnapshot(
                id: uuid(column: 0, statement: statement),
                reason: string(column: 1, statement: statement),
                snapshotPath: string(column: 2, statement: statement),
                plansCount: int(column: 3, statement: statement),
                todosCount: int(column: 4, statement: statement),
                sessionsCount: int(column: 5, statement: statement),
                createdAt: date(column: 6, statement: statement)
            )
        }
    }

    private func replacePlanTasks(_ planTasks: [PlanTask], in database: OpaquePointer) throws {
        try execute("DELETE FROM plans;", in: database)
        let sql = """
        INSERT INTO plans (id, title, created_at, updated_at, deleted_at, is_collapsed, is_archived, sort_order)
        VALUES (?, ?, ?, ?, NULL, ?, ?, ?);
        """

        for (index, task) in planTasks.enumerated() {
            try run(sql: sql, in: database) { statement in
                bind(task.id.uuidString, at: 1, statement: statement)
                bind(task.title, at: 2, statement: statement)
                bind(task.createdAt.databaseString, at: 3, statement: statement)
                bind(task.updatedAt.databaseString, at: 4, statement: statement)
                bind(task.isCollapsed, at: 5, statement: statement)
                bind(task.isArchived, at: 6, statement: statement)
                bind(index, at: 7, statement: statement)
            }
        }
    }

    private func replaceTodos(_ todos: [TodoItem], in database: OpaquePointer) throws {
        try execute("DELETE FROM todo_items;", in: database)
        let sql = """
        INSERT INTO todo_items (
          id, plan_id, source_template_id, title, note, is_completed, is_added_to_today, task_date, cycle,
          schedule_mode, recurrence_value, scheduled_dates, daily_duration_minutes, focus_timer_direction, created_at, updated_at, deleted_at, sort_order
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?);
        """

        for (index, todo) in todos.enumerated() {
            try run(sql: sql, in: database) { statement in
                bind(todo.id.uuidString, at: 1, statement: statement)
                bindOptional(todo.planTaskID?.uuidString, at: 2, statement: statement)
                bindOptional(todo.sourceTemplateID?.uuidString, at: 3, statement: statement)
                bind(todo.title, at: 4, statement: statement)
                bind(todo.note, at: 5, statement: statement)
                bind(todo.isCompleted, at: 6, statement: statement)
                bind(todo.isAddedToToday, at: 7, statement: statement)
                bind(todo.taskDate.databaseString, at: 8, statement: statement)
                bind(todo.cycle.rawValue, at: 9, statement: statement)
                bind(todo.scheduleMode.rawValue, at: 10, statement: statement)
                bindOptional(todo.recurrenceValue, at: 11, statement: statement)
                bind(encodeDateArray(todo.scheduledDates), at: 12, statement: statement)
                bind(todo.dailyDurationMinutes, at: 13, statement: statement)
                bind(todo.focusTimerDirection.rawValue, at: 14, statement: statement)
                bind(todo.createdAt.databaseString, at: 15, statement: statement)
                bind(todo.updatedAt.databaseString, at: 16, statement: statement)
                bind(index, at: 17, statement: statement)
            }
        }
    }

    private func replaceSessions(_ sessions: [PomodoroSession], in database: OpaquePointer) throws {
        try execute("DELETE FROM pomodoro_sessions;", in: database)
        let sql = """
        INSERT INTO pomodoro_sessions (
          id, todo_id, source_template_id, plan_id, plan_title_snapshot, todo_title_snapshot,
          type, start_at, end_at, duration_seconds, created_at, updated_at, deleted_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL);
        """

        for session in sessions {
            try run(sql: sql, in: database) { statement in
                bind(session.id.uuidString, at: 1, statement: statement)
                bindOptional(session.relatedTodoID?.uuidString, at: 2, statement: statement)
                bindOptional(session.sourceTemplateID?.uuidString, at: 3, statement: statement)
                bindOptional(session.planTaskID?.uuidString, at: 4, statement: statement)
                bind(session.planTitleSnapshot, at: 5, statement: statement)
                bind(session.todoTitleSnapshot, at: 6, statement: statement)
                bind(session.type.rawValue, at: 7, statement: statement)
                bind(session.startAt.databaseString, at: 8, statement: statement)
                bind(session.endAt.databaseString, at: 9, statement: statement)
                bind(session.durationSeconds, at: 10, statement: statement)
                bind(session.endAt.databaseString, at: 11, statement: statement)
                bind(session.endAt.databaseString, at: 12, statement: statement)
            }
        }
    }

    private func replaceCheckInRecords(_ records: [DailyCheckInRecord], in database: OpaquePointer) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        guard let value = String(data: data, encoding: .utf8) else { return }
        try setMetaValue(value, for: "check_in_records", in: database)
    }

    private func replaceProfile(_ profile: UserProfile, in database: OpaquePointer) throws {
        try run(
            sql: """
            INSERT OR REPLACE INTO user_profile (id, nickname, signature, daily_goal, updated_at)
            VALUES ('current', ?, ?, ?, ?);
            """,
            in: database
        ) { statement in
            bind(profile.nickname, at: 1, statement: statement)
            bind(profile.signature, at: 2, statement: statement)
            bind(profile.dailyGoal, at: 3, statement: statement)
            bind(Date().databaseString, at: 4, statement: statement)
        }
    }

    private func replaceSettings(_ settings: AppSettings, in database: OpaquePointer) throws {
        try run(
            sql: """
            INSERT OR REPLACE INTO app_settings (
              id, theme_mode, language, haptics_enabled, pomodoro_goal_per_day, use_large_text, text_scale, check_in_icon_series_id, check_in_icon_pack_id, item_edge_effect_enabled, updated_at
            )
            VALUES ('current', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            in: database
        ) { statement in
            bind(settings.themeMode.rawValue, at: 1, statement: statement)
            bind(settings.language.rawValue, at: 2, statement: statement)
            bind(settings.hapticsEnabled, at: 3, statement: statement)
            bind(settings.pomodoroGoalPerDay, at: 4, statement: statement)
            bind(settings.textScale == .large, at: 5, statement: statement)
            bind(settings.textScale.rawValue, at: 6, statement: statement)
            bind(settings.checkInIconSelection.seriesID, at: 7, statement: statement)
            bind(settings.checkInIconSelection.packID, at: 8, statement: statement)
            bind(settings.itemEdgeEffectEnabled, at: 9, statement: statement)
            bind(Date().databaseString, at: 10, statement: statement)
        }
    }

    private func replaceEntitlement(_ entitlement: EntitlementState, in database: OpaquePointer) throws {
        try run(
            sql: """
            INSERT OR REPLACE INTO entitlement_state (
              id, tier, cloud_sync_enabled, expires_at, updated_at
            )
            VALUES ('current', ?, ?, ?, ?);
            """,
            in: database
        ) { statement in
            bind(entitlement.tier.rawValue, at: 1, statement: statement)
            bind(entitlement.cloudSyncEnabled, at: 2, statement: statement)
            bindOptional(entitlement.expiresAt?.databaseString, at: 3, statement: statement)
            bind(Date().databaseString, at: 4, statement: statement)
        }
    }

    private func insertSyncHistory(_ entry: SyncHistoryEntry, in database: OpaquePointer) throws {
        try run(
            sql: """
            INSERT OR REPLACE INTO sync_history (
              id, direction, status, changed_count, message, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            in: database
        ) { statement in
            bind(entry.id.uuidString, at: 1, statement: statement)
            bind(entry.direction.rawValue, at: 2, statement: statement)
            bind(entry.status.rawValue, at: 3, statement: statement)
            bind(entry.changedCount, at: 4, statement: statement)
            bind(entry.message, at: 5, statement: statement)
            bind(entry.createdAt.databaseString, at: 6, statement: statement)
        }
    }

    private func insertLocalBackupSnapshot(_ backup: LocalBackupSnapshot, in database: OpaquePointer) throws {
        try run(
            sql: """
            INSERT OR REPLACE INTO local_backup_snapshots (
              id, reason, snapshot_path, plans_count, todos_count, sessions_count, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """,
            in: database
        ) { statement in
            bind(backup.id.uuidString, at: 1, statement: statement)
            bind(backup.reason, at: 2, statement: statement)
            bind(backup.snapshotPath, at: 3, statement: statement)
            bind(backup.plansCount, at: 4, statement: statement)
            bind(backup.todosCount, at: 5, statement: statement)
            bind(backup.sessionsCount, at: 6, statement: statement)
            bind(backup.createdAt.databaseString, at: 7, statement: statement)
        }
    }

    private func insertChangeLog(
        id: UUID,
        entityType: String,
        entityID: String,
        operation: String,
        payload: String,
        createdAt: Date,
        in database: OpaquePointer
    ) throws {
        try run(
            sql: """
            INSERT INTO change_logs (
              id, entity_type, entity_id, operation, payload, created_at, synced_at
            )
            VALUES (?, ?, ?, ?, ?, ?, NULL);
            """,
            in: database
        ) { statement in
            bind(id.uuidString, at: 1, statement: statement)
            bind(entityType, at: 2, statement: statement)
            bind(entityID, at: 3, statement: statement)
            bind(operation, at: 4, statement: statement)
            bind(payload, at: 5, statement: statement)
            bind(createdAt.databaseString, at: 6, statement: statement)
        }
    }

    private func countPendingChangeLogs(in database: OpaquePointer) throws -> Int {
        try rows(
            sql: "SELECT COUNT(*) FROM change_logs WHERE synced_at IS NULL;",
            in: database
        ) { statement in
            int(column: 0, statement: statement)
        }.first ?? 0
    }

    private func readPendingChangeLogs(limit: Int, from database: OpaquePointer) throws -> [ChangeLogEntry] {
        try rows(
            sql: """
            SELECT id, entity_type, entity_id, operation, payload, created_at
            FROM change_logs
            WHERE synced_at IS NULL
            ORDER BY created_at ASC
            LIMIT ?;
            """,
            in: database,
            bindings: { statement in
                bind(limit, at: 1, statement: statement)
            }
        ) { statement in
            ChangeLogEntry(
                id: uuid(column: 0, statement: statement),
                entityType: string(column: 1, statement: statement),
                entityID: string(column: 2, statement: statement),
                operation: string(column: 3, statement: statement),
                payload: string(column: 4, statement: statement),
                createdAt: date(column: 5, statement: statement)
            )
        }
    }

    private func markChangeLogSynced(id: UUID, syncedAt: Date, in database: OpaquePointer) throws {
        try run(
            sql: "UPDATE change_logs SET synced_at = ? WHERE id = ?;",
            in: database
        ) { statement in
            bind(syncedAt.databaseString, at: 1, statement: statement)
            bind(id.uuidString, at: 2, statement: statement)
        }
    }

    private func metaValue(for key: String, in database: OpaquePointer) throws -> String? {
        try rows(sql: "SELECT value FROM meta WHERE key = ? LIMIT 1;", in: database, bindings: { statement in
            bind(key, at: 1, statement: statement)
        }) { statement in
            string(column: 0, statement: statement)
        }.first
    }

    private func setMetaValue(_ value: String, for key: String, in database: OpaquePointer) throws {
        try run(sql: "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?);", in: database) { statement in
            bind(key, at: 1, statement: statement)
            bind(value, at: 2, statement: statement)
        }
    }

    private func addColumnIfMissing(
        _ column: String,
        definition: String,
        to table: String,
        in database: OpaquePointer
    ) throws {
        let existingColumns = try rows(sql: "PRAGMA table_info(\(table));", in: database) { statement in
            string(column: 1, statement: statement)
        }
        guard !existingColumns.contains(column) else { return }
        try execute("ALTER TABLE \(table) ADD COLUMN \(column) \(definition);", in: database)
    }

    private func transaction(in database: OpaquePointer, operation: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE;", in: database)
        do {
            try operation()
            try execute("COMMIT;", in: database)
        } catch {
            try? execute("ROLLBACK;", in: database)
            throw error
        }
    }

    private func execute(_ sql: String, in database: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(errorMessage)
            throw DatabaseError.executeFailed(message: message)
        }
    }

    private func run(
        sql: String,
        in database: OpaquePointer,
        bindings: (OpaquePointer) -> Void = { _ in }
    ) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DatabaseError.prepareFailed(message: String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        bindings(statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(database)))
        }
    }

    private func rows<T>(
        sql: String,
        in database: OpaquePointer,
        bindings: (OpaquePointer) -> Void = { _ in },
        map: (OpaquePointer) -> T
    ) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DatabaseError.prepareFailed(message: String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        bindings(statement)

        var output: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            output.append(map(statement))
        }
        return output
    }
}

private enum DatabaseError: LocalizedError {
    case openFailed(message: String)
    case executeFailed(message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            return "Could not open SQLite database: \(message)"
        case .executeFailed(let message):
            return "SQLite execute failed: \(message)"
        case .prepareFailed(let message):
            return "SQLite prepare failed: \(message)"
        case .stepFailed(let message):
            return "SQLite step failed: \(message)"
        }
    }
}

private func bind(_ value: String, at index: Int32, statement: OpaquePointer) {
    sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
}

private func bindOptional(_ value: String?, at index: Int32, statement: OpaquePointer) {
    if let value {
        bind(value, at: index, statement: statement)
    } else {
        sqlite3_bind_null(statement, index)
    }
}

private func bind(_ value: Int, at index: Int32, statement: OpaquePointer) {
    sqlite3_bind_int(statement, index, Int32(value))
}

private func bindOptional(_ value: Int?, at index: Int32, statement: OpaquePointer) {
    if let value {
        bind(value, at: index, statement: statement)
    } else {
        sqlite3_bind_null(statement, index)
    }
}

private func bind(_ value: Bool, at index: Int32, statement: OpaquePointer) {
    sqlite3_bind_int(statement, index, value ? 1 : 0)
}

private func string(column: Int32, statement: OpaquePointer) -> String {
    guard let text = sqlite3_column_text(statement, column) else { return "" }
    return String(cString: text)
}

private func int(column: Int32, statement: OpaquePointer) -> Int {
    Int(sqlite3_column_int(statement, column))
}

private func optionalInt(column: Int32, statement: OpaquePointer) -> Int? {
    guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
    return int(column: column, statement: statement)
}

private func bool(column: Int32, statement: OpaquePointer) -> Bool {
    sqlite3_column_int(statement, column) != 0
}

private func uuid(column: Int32, statement: OpaquePointer) -> UUID {
    UUID(uuidString: string(column: column, statement: statement)) ?? UUID()
}

private func optionalUUID(column: Int32, statement: OpaquePointer) -> UUID? {
    guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
    return UUID(uuidString: string(column: column, statement: statement))
}

private func date(column: Int32, statement: OpaquePointer) -> Date {
    Date.databaseFormatter.date(from: string(column: column, statement: statement)) ?? Date()
}

private func optionalDate(column: Int32, statement: OpaquePointer) -> Date? {
    guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
    return Date.databaseFormatter.date(from: string(column: column, statement: statement))
}

private func encodeDateArray(_ dates: [Date]) -> String {
    let values = dates.map(\.databaseString)
    guard let data = try? JSONEncoder().encode(values),
          let json = String(data: data, encoding: .utf8) else {
        return "[]"
    }
    return json
}

private func decodeDateArray(_ stringValue: String) -> [Date] {
    guard let data = stringValue.data(using: .utf8),
          let values = try? JSONDecoder().decode([String].self, from: data) else {
        return []
    }
    return values.compactMap(Date.init(databaseString:))
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private extension Date {
    static let databaseFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    var databaseString: String {
        Self.databaseFormatter.string(from: self)
    }

    init?(databaseString: String) {
        guard let date = Self.databaseFormatter.date(from: databaseString) else { return nil }
        self = date
    }
}

private extension StorageSnapshot {
    var hasContent: Bool {
        !todos.isEmpty
            || !planTasks.isEmpty
            || !pomodoroSessions.isEmpty
            || profile != .default
            || settings != .default
    }
}
