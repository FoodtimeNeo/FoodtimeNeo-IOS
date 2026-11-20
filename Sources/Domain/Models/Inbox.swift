import Foundation

/// 站内公告。列表接口返回 `publishedAt`，旧版弹窗投影返回 `createdTime`，
/// 两者在客户端归一为一个时间，不按接口版本分支。
struct Notice: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let content: String?
    let publishedAt: Date?
    let isUpdate: Bool

    init(id: String, content: String?, publishedAt: Date?, isUpdate: Bool) {
        self.id = id
        self.content = content
        self.publishedAt = publishedAt
        self.isUpdate = isUpdate
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case content
        case publishedAt
        case createdTime
        case isUpdate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
            ?? container.decodeIfPresent(Date.self, forKey: .createdTime)
        isUpdate = try container.decodeIfPresent(Bool.self, forKey: .isUpdate) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(publishedAt, forKey: .publishedAt)
        try container.encode(isUpdate, forKey: .isUpdate)
    }
}

/// 系统消息。`body` 允许为空；社区互动消息通过 `refType/refId` 指回原帖。
struct InboxMessage: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let body: String?
    let category: String?
    let refType: String?
    let refId: String?
    let refCommentId: String?
    let refRootCommentId: String?
    let actorCount: Int
    let isRead: Bool
    let createdAt: Date?

    var opensCommunityPost: Bool {
        refType == "community-post"
            && refId?.isEmpty == false
            && ["LIKE_POST", "LIKE_COMMENT", "COMMENT_POST", "REPLY_COMMENT"].contains(category ?? "")
    }
}

struct ChatParticipant: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let avatarUrl: String?
}

struct Conversation: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let other: ChatParticipant
    let lastMessage: String?
    let lastSenderId: String?
    let lastMessageAt: Date?
    let unreadCount: Int
    let updatedAt: Date?
}

struct DirectMessage: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    let createdAt: Date?
}

struct DirectMessagePage: Codable, Equatable, Sendable {
    let items: [DirectMessage]
    let hasMore: Bool
    let nextCursor: String?
}

struct UnreadCount: Codable, Equatable, Sendable {
    let unreadCount: Int
}
