import Foundation

struct Review: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let dishId: String
    let userId: String
    let userDisplayName: String
    let rating: Int
    let content: String
    let createdAt: Date?
    let updatedAt: Date?
    let dishName: String
    let stallId: String
    let stallName: String
    let diningHallId: String
    let diningHallName: String
    let likeCount: Int
    let replyCount: Int
    let likedByMe: Bool
    let counterVersion: Int
}

struct ReviewSubmission: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let dishId: String
    let dishName: String
    let stallId: String
    let stallName: String
    let diningHallId: String
    let diningHallName: String
    let rating: Int
    let content: String
    let status: String
    let submittedAt: Date?
    let reviewedAt: Date?
    let reviewReason: String?
    let updatedAt: Date?

    var statusLabel: String {
        switch status {
        case "pending": return "待审核"
        case "approved": return "已通过"
        case "rejected": return "已驳回"
        default: return "状态更新中"
        }
    }
}

struct ReviewCreatedReceipt: Codable, Equatable, Sendable {
    let id: String
    let dishId: String
    let rating: Int
    let content: String
    let status: String
    let submittedAt: Date?
}

struct ReviewLikeState: Codable, Equatable, Sendable {
    let likedByMe: Bool
    let likeCount: Int
    let counterVersion: Int
}
