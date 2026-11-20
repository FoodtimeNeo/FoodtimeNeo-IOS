import Foundation

final class RemoteMessageService: MessageService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func conversations(page: Int, size: Int) async throws -> Page<Conversation> {
        try await api.send(
            .get(
                "users/me/conversations",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<Conversation>.self
        )
    }

    func unreadCount() async throws -> Int {
        let response: UnreadCount = try await api.send(
            .get("users/me/conversations/unread-count"),
            as: UnreadCount.self
        )
        return response.unreadCount
    }

    func conversation(id: String) async throws -> Conversation {
        try await api.send(
            .get("users/me/conversations/\(encoded(id))"),
            as: Conversation.self
        )
    }

    func startConversation(userID: String) async throws -> Conversation {
        struct Body: Encodable {
            let userId: String
        }
        let request = try APIRequest.json(
            .post,
            "users/me/conversations",
            body: Body(userId: userID)
        )
        return try await api.send(request, as: Conversation.self)
    }

    func messages(
        conversationID: String,
        size: Int,
        cursor: String?
    ) async throws -> DirectMessagePage {
        var query = [URLQueryItem(name: "size", value: String(min(100, max(1, size))))]
        if let cursor, !cursor.isEmpty {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await api.send(
            .get("users/me/conversations/\(encoded(conversationID))/messages", query: query),
            as: DirectMessagePage.self
        )
    }

    func send(
        conversationID: String,
        content: String,
        requestID: String
    ) async throws -> DirectMessage {
        struct Body: Encodable {
            let content: String
            let clientRequestId: String
        }
        let request = try APIRequest.json(
            .post,
            "users/me/conversations/\(encoded(conversationID))/messages",
            body: Body(content: content, clientRequestId: requestID)
        )
        return try await api.send(request, as: DirectMessage.self)
    }

    func markRead(conversationID: String) async throws {
        try await api.sendVoid(.post("users/me/conversations/\(encoded(conversationID))/read"))
    }

    func hide(conversationID: String) async throws {
        try await api.sendVoid(.delete("users/me/conversations/\(encoded(conversationID))"))
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
