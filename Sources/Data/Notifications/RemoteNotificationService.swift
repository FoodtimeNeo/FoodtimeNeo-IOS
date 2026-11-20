import Foundation

final class RemoteNotificationService: NotificationService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func preferences() async throws -> NotificationPreferences {
        try await api.send(
            .get("users/me/notification-preferences"),
            as: NotificationPreferences.self
        )
    }

    func update(
        category: String,
        enabled: Bool,
        expectedRevision: Int
    ) async throws -> NotificationPreference {
        struct Body: Encodable {
            let enabled: Bool
            let expectedRevision: Int
        }
        let request = try APIRequest.json(
            .put,
            "users/me/notification-preferences/\(encoded(category))",
            body: Body(enabled: enabled, expectedRevision: expectedRevision)
        )
        let saved = try await api.send(request, as: NotificationPreference.self)
        guard saved.category == category else {
            throw AppError.invalidResponse(message: "提醒开关响应与请求不一致")
        }
        return saved
    }

    func events(afterSeq: Int64, limit: Int) async throws -> NotificationEventPage {
        try await api.send(
            .get(
                "users/me/notification-events",
                query: [
                    URLQueryItem(name: "afterSeq", value: String(max(0, afterSeq))),
                    URLQueryItem(name: "limit", value: String(min(100, max(1, limit))))
                ]
            ),
            as: NotificationEventPage.self
        )
    }

    func markDelivered(eventID: String) async throws {
        try await api.sendVoid(
            .post("users/me/notification-events/\(encoded(eventID))/delivered")
        )
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
