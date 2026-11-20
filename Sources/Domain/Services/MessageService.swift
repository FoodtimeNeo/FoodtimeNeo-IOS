import Foundation

/// 一对一私信会话。开始对话幂等；发送用 clientRequestId 保证重复提交只落一条。
protocol MessageService: AnyObject {
    func conversations(page: Int, size: Int) async throws -> Page<Conversation>
    func unreadCount() async throws -> Int
    func conversation(id: String) async throws -> Conversation
    func startConversation(userID: String) async throws -> Conversation
    func messages(
        conversationID: String,
        size: Int,
        cursor: String?
    ) async throws -> DirectMessagePage
    func send(conversationID: String, content: String, requestID: String) async throws -> DirectMessage
    func markRead(conversationID: String) async throws
    func hide(conversationID: String) async throws
}
