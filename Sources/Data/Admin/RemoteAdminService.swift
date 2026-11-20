import Foundation

final class RemoteAdminService: AdminService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func dashboard(days: Int) async throws -> AdminDashboard {
        try await api.send(
            .get(
                "admin/dashboard",
                query: [URLQueryItem(name: "days", value: String(min(31, max(1, days))))]
            ),
            as: AdminDashboard.self
        )
    }

    func users(query: String, page: Int, size: Int) async throws -> Page<AdminUser> {
        var items = [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "q", value: trimmed))
        }
        return try await api.send(
            .get("admin/users", query: items),
            as: Page<AdminUser>.self
        )
    }

    func updateUser(id: String, role: String, status: String) async throws {
        struct Body: Encodable {
            let role: String
            let status: String
        }
        let request = try APIRequest.json(
            .put,
            "admin/users/\(encoded(id))",
            body: Body(role: role, status: status),
            requiresAuth: true,
            requiresCSRF: true
        )
        try await api.sendVoid(request)
    }

    func moderationQueue(
        status: String,
        type: String?,
        page: Int,
        size: Int
    ) async throws -> Page<ModerationItem> {
        var query = [
            URLQueryItem(name: "status", value: status),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
        if let type, !type.isEmpty {
            query.append(URLQueryItem(name: "type", value: type))
        }
        return try await api.send(
            .get("admin/moderation", query: query),
            as: Page<ModerationItem>.self
        )
    }

    func moderate(
        type: String,
        submissionID: String,
        action: String,
        reason: String?,
        price: Decimal?,
        contentRevision: Int?
    ) async throws -> ModerationResult {
        struct Body: Encodable {
            let action: String
            let reason: String?
            let price: Decimal?
            let contentRevision: Int?
        }
        let request = try APIRequest.json(
            .post,
            "admin/moderation/\(encoded(type))/\(encoded(submissionID))",
            body: Body(
                action: action,
                reason: reason,
                price: price,
                contentRevision: contentRevision
            ),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: ModerationResult.self)
    }

    func moderationLogs(page: Int, size: Int) async throws -> Page<ModerationLog> {
        try await api.send(
            .get(
                "admin/moderation/logs",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<ModerationLog>.self
        )
    }

    func communityQueue(
        kind: String,
        status: String,
        page: Int,
        size: Int
    ) async throws -> Page<ModerationItem> {
        try await api.send(
            .get(
                "admin/community/\(encoded(kind))",
                query: [
                    URLQueryItem(name: "status", value: status),
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<ModerationItem>.self
        )
    }

    func moderateCommunity(
        kind: String,
        id: String,
        action: String,
        reason: String?,
        contentRevision: Int?
    ) async throws -> ModerationResult {
        struct Body: Encodable {
            let action: String
            let reason: String?
            let contentRevision: Int?
        }
        let request = try APIRequest.json(
            .post,
            "admin/community/\(encoded(kind))/\(encoded(id))",
            body: Body(action: action, reason: reason, contentRevision: contentRevision),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: ModerationResult.self)
    }

    func communityModerationDetail(
        kind: String,
        id: String
    ) async throws -> CommunityModerationDetail {
        try await api.send(
            .get("admin/community/\(encoded(kind))/\(encoded(id))"),
            as: CommunityModerationDetail.self
        )
    }

    func deleteCommunityContent(kind: String, id: String) async throws {
        try await api.sendVoid(
            .delete("admin/community/\(encoded(kind))/\(encoded(id))")
        )
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
