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

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
