import Foundation

enum VenueTargetType: String, Sendable {
    case hall
    case stall

    var path: String {
        switch self {
        case .hall: return "dining-halls"
        case .stall: return "stalls"
        }
    }

    var label: String {
        switch self {
        case .hall: return "食堂"
        case .stall: return "档口"
        }
    }
}

struct VenueRatingTarget: Codable, Equatable, Sendable {
    let type: String
    let targetId: String
    let name: String
    let diningHallId: String?
    let stallId: String?
    let averageScore: Double?
    let reviewCount: Int
}

struct VenueReview: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let reviewId: String
    let submissionId: String?
    let userId: String
    let userDisplayName: String
    let targetType: String
    let targetId: String
    let name: String
    let rating: Int
    let content: String
    let status: String
    let reviewReason: String?
    let createdAt: Date?
    let updatedAt: Date?
    let ownedByMe: Bool
    let likedByMe: Bool
    let likeCount: Int
    let counterVersion: Int
    let replyCount: Int

    var statusLabel: String {
        switch status {
        case "pending": return "待审核"
        case "approved": return "已通过"
        case "rejected": return "已驳回"
        case "invalidated": return "已失效"
        default: return "状态更新中"
        }
    }
}

struct VenueReviewPage: Codable, Equatable, Sendable {
    let items: [VenueReview]
    let total: Int
    let hasMore: Bool
    let nextCursor: String?
}

struct VenueReviewMine: Codable, Equatable, Sendable {
    let publicVersion: VenueReview?
    let privateSubmission: VenueReview?
}
