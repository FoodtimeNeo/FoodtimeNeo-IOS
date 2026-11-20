import Foundation

struct CommunityImage: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let url: String
    let width: Int?
    let height: Int?
    let sortOrder: Int
}

struct RepostPreview: Codable, Equatable, Sendable {
    let id: String
    let userDisplayName: String
    let content: String
}

struct LinkedDish: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let stallId: String
    let diningHallId: String
}

struct CommunityPost: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let userId: String
    let userDisplayName: String
    let title: String
    let content: String
    let imageUrls: [String]
    let images: [CommunityImage]
    let likeCount: Int
    let commentCount: Int
    let repostCount: Int
    let repostOfId: String?
    let repost: RepostPreview?
    let likedByMe: Bool
    let favoritedByMe: Bool
    let favoriteCount: Int
    let status: String
    let reviewReason: String?
    let createdAt: Date?
    let editedAt: Date?
    let viewCount: Int
    let contentRevision: Int
    let userAvatarUrl: String?
    let linkedDish: LinkedDish?
}

struct CommunityPostReceipt: Codable, Equatable, Sendable {
    let id: String
}

struct CommunityEditReceipt: Codable, Equatable, Sendable {
    let id: String
    let revision: Int
    let changed: Bool
}

struct CommunityPinEntry: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let userDisplayName: String
    let status: String
    let position: Int
}

struct CommunityPinSnapshot: Codable, Equatable, Sendable {
    let revision: Int
    let items: [CommunityPinEntry]
    let canManage: Bool
}

struct CommunityFeedPage: Codable, Equatable, Sendable {
    let items: [CommunityPost]
    let total: Int
    let hasMore: Bool
    let nextCursor: String?
    let pins: CommunityPinSnapshot?
}

struct CommunityComment: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let postId: String
    let userId: String
    let userDisplayName: String
    let content: String
    let likeCount: Int
    let status: String
    let createdAt: Date?
    let rootCommentId: String?
    let replyToCommentId: String?
    let replyToUserId: String?
    let replyToDisplayName: String?
    let replyCount: Int
    let likedByMe: Bool
    let deleted: Bool
    let userAvatarUrl: String?
}

struct CommunityCommentPage: Codable, Equatable, Sendable {
    let items: [CommunityComment]
    let total: Int
    let hasMore: Bool
    let nextCursor: String?
}

struct CommunityLikeState: Codable, Equatable, Sendable {
    let liked: Bool?
    let likedByMe: Bool?
    let likeCount: Int?
    let favorited: Bool?
    let favoritedByMe: Bool?
    let favoriteCount: Int?
    let counterVersion: Int?
}
