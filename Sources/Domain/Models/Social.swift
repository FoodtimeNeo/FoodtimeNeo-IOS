import Foundation

struct SocialUser: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let followedByMe: Bool
}

struct BlockedUser: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let blockedAt: Date?
}

struct FollowState: Codable, Equatable, Sendable {
    let followed: Bool
    let followerCount: Int
}

struct BlockState: Codable, Equatable, Sendable {
    let blocked: Bool
}
