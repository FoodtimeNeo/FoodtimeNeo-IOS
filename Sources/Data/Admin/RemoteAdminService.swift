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

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
