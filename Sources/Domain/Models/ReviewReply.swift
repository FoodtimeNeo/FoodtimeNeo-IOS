import Foundation

struct ReviewReply: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let reviewId: String
    let replyToId: String?
    let userId: String
    let userDisplayName: String
    let content: String
    let status: String
    let reviewReason: String?
    let reviewedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?
    let replyToUserId: String?
    let replyToUserDisplayName: String?
    let replyToDeleted: Bool
    let ownedByMe: Bool
    let dishId: String?
    let stallId: String?
    let diningHallId: String?
    let dishName: String
    let reviewDeleted: Bool
    let likeCount: Int
    let likedByMe: Bool
    let counterVersion: Int

    var statusLabel: String {
        switch status {
        case "pending": return "待审核"
        case "approved": return "已通过"
        case "rejected": return "已驳回"
        default: return "状态更新中"
        }
    }
}

struct ReviewReplyPage: Codable, Equatable, Sendable {
    let items: [ReviewReply]
    let total: Int
    let hasMore: Bool
    let nextCursor: String?
}

struct ReviewReplyCreatedReceipt: Codable, Equatable, Sendable {
    let id: String
    let status: String
    let createdAt: Date?
}
