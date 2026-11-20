import Foundation

final class RemoteInboxService: InboxService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func notices(page: Int, size: Int) async throws -> Page<Notice> {
        try await api.send(
            .get("users/me/notices", query: paging(page: page, size: size)),
            as: Page<Notice>.self
        )
    }

    func markNoticeRead(id: String) async throws {
        try await api.sendVoid(.post("users/me/notices/\(encoded(id))/read"))
    }

    func unreadNoticeCount() async throws -> Int {
        let response: UnreadCount = try await api.send(
            .get("users/me/notices/unread-count"),
            as: UnreadCount.self
        )
        return response.unreadCount
    }

    func messages(page: Int, size: Int) async throws -> Page<InboxMessage> {
        try await api.send(
            .get("users/me/messages", query: paging(page: page, size: size)),
            as: Page<InboxMessage>.self
        )
    }

    func markMessageRead(id: String) async throws {
        try await api.sendVoid(.post("users/me/messages/\(encoded(id))/read"))
    }

    func markAllMessagesRead() async throws {
        try await api.sendVoid(.post("users/me/messages/read-all"))
    }

    func unreadMessageCount() async throws -> Int {
        let response: UnreadCount = try await api.send(
            .get("users/me/messages/unread-count"),
            as: UnreadCount.self
        )
        return response.unreadCount
    }

    private func paging(page: Int, size: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
