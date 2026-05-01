import Foundation

struct CloudConfig {
    static let stagingBaseURL = URL(string: "http://101.43.104.105")!
    static let stagingDebugUserID = "debug-user-staging"
}

struct CloudHealthResponse: Decodable, Equatable {
    let ok: Bool
    let service: String
    let environment: String
    let databaseTime: Date
}

private struct EmptyCloudRequest: Encodable {}

private struct CloudAnonymousAuthResponse: Decodable, Equatable {
    let userID: String
    let deviceID: String
}

struct AppleAuthRequest: Encodable {
    let identityToken: String
    let authorizationCode: String?
    let deviceID: String
    let anonymousUserID: String?
    let displayName: String?
    let email: String?
}

struct MockAuthRequest: Encodable {
    let nickname: String
    let email: String
    let deviceID: String
    let anonymousUserID: String?
}

struct AuthRefreshRequest: Encodable {
    let refreshToken: String
    let deviceID: String?
}

struct AuthLogoutRequest: Encodable {
    let refreshToken: String
    let deviceID: String?
}

struct AccountAuthResponse: Decodable, Equatable {
    let user: AccountUser
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let migration: AccountMigrationResult?
}

struct AccountRefreshResponse: Decodable, Equatable {
    let user: AccountUser
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct AccountMeResponse: Decodable, Equatable {
    let user: AccountUser
    let entitlement: CloudEntitlementState
}

struct CloudEntitlementState: Decodable, Equatable {
    let userID: String
    let tier: String
    let cloudSyncEnabled: Bool
    let source: String
    let expiresAt: Date?
}

struct CloudOKResponse: Decodable, Equatable {
    let ok: Bool
}

struct CloudSyncPullResponse: Decodable, Equatable {
    let cursor: Date
    let plans: [CloudPlan]
    let todoItems: [CloudTodoItem]
    let pomodoroSessions: [CloudPomodoroSession]
    let appSettings: [CloudAppSettings]
}

struct CloudSyncPushRequest: Encodable {
    let userID: String
    let deviceID: String
    let changes: [ChangeLogEntry]

    private enum CodingKeys: String, CodingKey {
        case userID = "userID"
        case deviceID = "deviceID"
        case changes
    }
}

struct CloudBackupCreateRequest: Encodable {
    let userID: String
    let deviceID: String
    let reason: String
    let snapshot: StorageSnapshot
}

struct CloudBackupRestoreRequest: Encodable {
    let userID: String
    let snapshotID: UUID
}

struct CloudBackupListResponse: Decodable, Equatable {
    let backups: [CloudBackupSnapshot]
}

struct CloudBackupCreateResponse: Decodable, Equatable {
    let backup: CloudBackupSnapshot
}

struct CloudBackupRestoreResponse: Decodable, Equatable {
    let snapshotID: UUID
    let snapshot: StorageSnapshot
}

struct CloudStoreKitEntitlementRequest: Encodable {
    let userID: String
    let deviceID: String
    let productID: String
    let transactionID: String
    let originalTransactionID: String
    let expirationDate: Date?
    let environment: String
    let signedTransactionJWS: String
}

struct CloudEntitlementSyncResponse: Decodable, Equatable {
    let ok: Bool
    let userID: String
    let tier: String
    let cloudSyncEnabled: Bool
    let source: String
    let expiresAt: Date?
}

struct CloudSyncPushResponse: Decodable, Equatable {
    let accepted: Int
    let cursor: Date
}

struct CloudPlan: Decodable, Equatable {
    let id: UUID
    let title: String
    let isCollapsed: Bool
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isCollapsed = "is_collapsed"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct CloudTodoItem: Decodable, Equatable {
    let id: UUID
    let planID: UUID?
    let sourceTemplateID: UUID?
    let title: String
    let note: String
    let isCompleted: Bool
    let isAddedToToday: Bool
    let taskDate: Date
    let cycle: TodoTaskCycle
    let scheduleMode: TodoScheduleMode
    let recurrenceValue: Int?
    let scheduledDates: [Date]
    let dailyDurationMinutes: Int
    let focusTimerDirection: FocusTimerDirection
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case planID = "plan_id"
        case sourceTemplateID = "source_template_id"
        case title
        case note
        case isCompleted = "is_completed"
        case isAddedToToday = "is_added_to_today"
        case taskDate = "task_date"
        case cycle
        case scheduleMode = "schedule_mode"
        case recurrenceValue = "recurrence_value"
        case scheduledDates = "scheduled_dates"
        case dailyDurationMinutes = "daily_duration_minutes"
        case focusTimerDirection = "focus_timer_direction"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        planID = try container.decodeIfPresent(UUID.self, forKey: .planID)
        sourceTemplateID = try container.decodeIfPresent(UUID.self, forKey: .sourceTemplateID)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        isAddedToToday = try container.decode(Bool.self, forKey: .isAddedToToday)
        taskDate = try container.decode(Date.self, forKey: .taskDate)
        cycle = try container.decodeIfPresent(TodoTaskCycle.self, forKey: .cycle) ?? .daily
        scheduleMode = try container.decodeIfPresent(TodoScheduleMode.self, forKey: .scheduleMode) ?? .custom
        recurrenceValue = try container.decodeIfPresent(Int.self, forKey: .recurrenceValue)
        scheduledDates = try container.decodeIfPresent([Date].self, forKey: .scheduledDates) ?? []
        dailyDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyDurationMinutes) ?? 25
        focusTimerDirection = try container.decodeIfPresent(FocusTimerDirection.self, forKey: .focusTimerDirection) ?? .countDown
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct CloudPomodoroSession: Decodable, Equatable {
    let id: UUID
    let planID: UUID?
    let todoID: UUID?
    let sourceTemplateID: UUID?
    let planTitleSnapshot: String?
    let todoTitleSnapshot: String?
    let type: PomodoroSessionType
    let startAt: Date
    let endAt: Date
    let durationSeconds: Int
    let deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case planID = "plan_id"
        case todoID = "todo_id"
        case sourceTemplateID = "source_template_id"
        case planTitleSnapshot = "plan_title_snapshot"
        case todoTitleSnapshot = "todo_title_snapshot"
        case type
        case startAt = "start_at"
        case endAt = "end_at"
        case durationSeconds = "duration_seconds"
        case deletedAt = "deleted_at"
    }
}

struct CloudAppSettings: Decodable, Equatable {
    let themeMode: AppThemeMode
    let language: AppLanguage
    let hapticsEnabled: Bool
    let pomodoroGoalPerDay: Int
    let textScale: AppTextScale?
    let checkInIconSelection: CheckInIconSelection?
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case themeMode = "theme_mode"
        case language
        case hapticsEnabled = "haptics_enabled"
        case pomodoroGoalPerDay = "pomodoro_goal_per_day"
        case textScale = "text_scale"
        case useLargeText = "use_large_text"
        case checkInIconSeriesID = "check_in_icon_series_id"
        case checkInIconPackID = "check_in_icon_pack_id"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        themeMode = try container.decode(AppThemeMode.self, forKey: .themeMode)
        language = try container.decode(AppLanguage.self, forKey: .language)
        hapticsEnabled = try container.decode(Bool.self, forKey: .hapticsEnabled)
        pomodoroGoalPerDay = try container.decode(Int.self, forKey: .pomodoroGoalPerDay)
        if let scale = try container.decodeIfPresent(AppTextScale.self, forKey: .textScale) {
            textScale = scale
        } else {
            let legacyLarge = try container.decodeIfPresent(Bool.self, forKey: .useLargeText) ?? false
            textScale = legacyLarge ? .large : .medium
        }
        let seriesID = try container.decodeIfPresent(String.self, forKey: .checkInIconSeriesID)
        let packID = try container.decodeIfPresent(String.self, forKey: .checkInIconPackID)
        if let seriesID, let packID {
            checkInIconSelection = CheckInIconSelection(seriesID: seriesID, packID: packID)
        } else {
            checkInIconSelection = nil
        }
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct CloudAPIClient {
    var baseURL: URL = CloudConfig.stagingBaseURL
    var session: URLSession = .shared

    func health() async throws -> CloudHealthResponse {
        try await get(path: "health")
    }

    func createAnonymousIdentity() async throws -> CloudIdentity {
        let response: CloudAnonymousAuthResponse = try await post(path: "auth/anonymous", body: EmptyCloudRequest())
        return CloudIdentity(userID: response.userID, deviceID: response.deviceID, createdAt: Date())
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        deviceID: String,
        anonymousUserID: String?,
        displayName: String?,
        email: String?
    ) async throws -> AccountAuthResponse {
        try await post(
            path: "auth/apple",
            body: AppleAuthRequest(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                deviceID: deviceID,
                anonymousUserID: anonymousUserID,
                displayName: displayName,
                email: email
            )
        )
    }

#if DEBUG
    func mockStagingLogin(
        nickname: String,
        email: String,
        deviceID: String,
        anonymousUserID: String?,
        debugSecret: String
    ) async throws -> AccountAuthResponse {
        try await post(
            path: "debug/auth/mock",
            body: MockAuthRequest(
                nickname: nickname,
                email: email,
                deviceID: deviceID,
                anonymousUserID: anonymousUserID
            ),
            headers: ["x-debug-secret": debugSecret]
        )
    }
#endif

    func refreshAuthSession(refreshToken: String, deviceID: String?) async throws -> AccountRefreshResponse {
        try await post(
            path: "auth/refresh",
            body: AuthRefreshRequest(refreshToken: refreshToken, deviceID: deviceID)
        )
    }

    func logout(refreshToken: String, deviceID: String?) async throws -> CloudOKResponse {
        try await post(
            path: "auth/logout",
            body: AuthLogoutRequest(refreshToken: refreshToken, deviceID: deviceID)
        )
    }

    func me(accessToken: String) async throws -> AccountMeResponse {
        try await get(path: "me", bearerToken: accessToken)
    }

    func pull(
        userID: String = CloudConfig.stagingDebugUserID,
        since: Date? = nil
    ) async throws -> CloudSyncPullResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("sync/pull"), resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "userID", value: userID)]
        if let since {
            queryItems.append(URLQueryItem(name: "since", value: Self.iso8601Encoder.string(from: since)))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw CloudAPIError.invalidURL }
        return try await get(url: url)
    }

    func push(
        changes: [ChangeLogEntry],
        userID: String = CloudConfig.stagingDebugUserID,
        deviceID: String = "debug-ios-device"
    ) async throws -> CloudSyncPushResponse {
        try await post(
            path: "sync/push",
            body: CloudSyncPushRequest(userID: userID, deviceID: deviceID, changes: changes)
        )
    }

    func loadCloudBackups(userID: String) async throws -> [CloudBackupSnapshot] {
        var components = URLComponents(url: baseURL.appendingPathComponent("backup/snapshots"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userID", value: userID)]
        guard let url = components?.url else { throw CloudAPIError.invalidURL }
        let response: CloudBackupListResponse = try await get(url: url)
        return response.backups
    }

    func createCloudBackup(
        identity: CloudIdentity,
        snapshot: StorageSnapshot,
        reason: String
    ) async throws -> CloudBackupSnapshot {
        let response: CloudBackupCreateResponse = try await post(
            path: "backup/snapshots",
            body: CloudBackupCreateRequest(
                userID: identity.userID,
                deviceID: identity.deviceID,
                reason: reason,
                snapshot: snapshot
            )
        )
        return response.backup
    }

    func restoreCloudBackup(identity: CloudIdentity, snapshotID: UUID) async throws -> StorageSnapshot {
        let response: CloudBackupRestoreResponse = try await post(
            path: "backup/restore",
            body: CloudBackupRestoreRequest(userID: identity.userID, snapshotID: snapshotID)
        )
        return response.snapshot
    }

    func syncStoreKitEntitlement(
        identity: CloudIdentity,
        transaction: StoreKitTransactionPayload
    ) async throws -> CloudEntitlementSyncResponse {
        try await post(
            path: "entitlements/storekit/sync",
            body: CloudStoreKitEntitlementRequest(
                userID: identity.userID,
                deviceID: identity.deviceID,
                productID: transaction.productID,
                transactionID: transaction.transactionID,
                originalTransactionID: transaction.originalTransactionID,
                expirationDate: transaction.expirationDate,
                environment: transaction.environment,
                signedTransactionJWS: transaction.signedTransactionJWS
            )
        )
    }

    private func get<T: Decodable>(path: String, bearerToken: String? = nil) async throws -> T {
        try await get(url: baseURL.appendingPathComponent(path), bearerToken: bearerToken)
    }

    private func get<T: Decodable>(url: URL, bearerToken: String? = nil) async throws -> T {
        var request = URLRequest(url: url)
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CloudAPIError.badStatus(httpResponse.statusCode)
        }
        return try Self.decoder.decode(T.self, from: data)
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        headers: [String: String] = [:]
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try Self.encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CloudAPIError.badStatus(httpResponse.statusCode)
        }
        return try Self.decoder.decode(Response.self, from: data)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let iso8601Encoder: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = DateFormatters.iso8601Fractional.date(from: value)
                ?? DateFormatters.iso8601.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }()
}

enum CloudAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid cloud URL."
        case .invalidResponse:
            return "Invalid cloud response."
        case .badStatus(let statusCode):
            return "Cloud request failed with status \(statusCode)."
        }
    }
}

private enum DateFormatters {
    static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
