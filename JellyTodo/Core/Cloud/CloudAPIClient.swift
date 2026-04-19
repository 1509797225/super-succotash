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

struct CloudSyncPullResponse: Decodable, Equatable {
    let cursor: Date
    let plans: [CloudPlan]
    let todoItems: [CloudTodoItem]
    let pomodoroSessions: [CloudPomodoroSession]
}

struct CloudPlan: Decodable, Equatable {
    let id: UUID
    let title: String
    let isCollapsed: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isCollapsed = "is_collapsed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct CloudTodoItem: Decodable, Equatable {
    let id: UUID
    let planID: UUID?
    let title: String
    let note: String
    let isCompleted: Bool
    let isAddedToToday: Bool
    let taskDate: Date
    let cycle: TodoTaskCycle
    let dailyDurationMinutes: Int
    let focusTimerDirection: FocusTimerDirection
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case planID = "plan_id"
        case title
        case note
        case isCompleted = "is_completed"
        case isAddedToToday = "is_added_to_today"
        case taskDate = "task_date"
        case cycle
        case dailyDurationMinutes = "daily_duration_minutes"
        case focusTimerDirection = "focus_timer_direction"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct CloudPomodoroSession: Decodable, Equatable {
    let id: UUID
    let todoID: UUID?
    let type: PomodoroSessionType
    let startAt: Date
    let endAt: Date
    let durationSeconds: Int
    let deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case todoID = "todo_id"
        case type
        case startAt = "start_at"
        case endAt = "end_at"
        case durationSeconds = "duration_seconds"
        case deletedAt = "deleted_at"
    }
}

struct CloudAPIClient {
    var baseURL: URL = CloudConfig.stagingBaseURL
    var session: URLSession = .shared

    func health() async throws -> CloudHealthResponse {
        try await get(path: "health")
    }

    func pull(userID: String = CloudConfig.stagingDebugUserID) async throws -> CloudSyncPullResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("sync/pull"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userID", value: userID)]
        guard let url = components?.url else { throw CloudAPIError.invalidURL }
        return try await get(url: url)
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        try await get(url: baseURL.appendingPathComponent(path))
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CloudAPIError.badStatus(httpResponse.statusCode)
        }
        return try Self.decoder.decode(T.self, from: data)
    }

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
