import Foundation

final class RemoteHistoryService: HistoryService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func settings() async throws -> BrowsingHistorySettings {
        try await api.send(
            .get("users/me/browsing-history/settings"),
            as: BrowsingHistorySettings.self
        )
    }

    func updateSettings(
        enabled: Bool,
        expectedRevision: Int
    ) async throws -> BrowsingHistorySettings {
        struct Body: Encodable {
            let enabled: Bool
            let expectedRevision: Int
        }
        let request = try APIRequest.json(
            .put,
            "users/me/browsing-history/settings",
            body: Body(enabled: enabled, expectedRevision: expectedRevision),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: BrowsingHistorySettings.self)
    }

    func list(kind: HistoryKind, page: Int, size: Int) async throws -> Page<BrowsingHistoryItem> {
        try await api.send(
            .get(
                "users/me/browsing-history",
                query: [
                    URLQueryItem(name: "kind", value: kind.rawValue),
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(50, max(1, size))))
                ]
            ),
            as: Page<BrowsingHistoryItem>.self
        )
    }

    func record(
        kind: HistoryKind,
        targetID: String,
        epoch: Int,
        visitEventID: String
    ) async throws {
        struct Body: Encodable {
            let epoch: Int
            let visitEventId: String
        }
        let request = try APIRequest.json(
            .put,
            "users/me/browsing-history/\(kind.rawValue)/\(encoded(targetID))",
            body: Body(epoch: epoch, visitEventId: visitEventID),
            requiresAuth: true,
            requiresCSRF: true
        )
        try await api.sendVoid(request)
    }

    func deleteOne(kind: HistoryKind, targetID: String) async throws {
        try await api.sendVoid(
            .delete("users/me/browsing-history/\(kind.rawValue)/\(encoded(targetID))")
        )
    }

    func clear(kind: HistoryKind) async throws {
        let request = APIRequest(
            method: .delete,
            path: "users/me/browsing-history",
            query: [URLQueryItem(name: "kind", value: kind.rawValue)],
            requiresAuth: true,
            requiresCSRF: true,
            contentType: nil
        )
        try await api.sendVoid(request)
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
