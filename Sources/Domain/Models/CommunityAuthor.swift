import Foundation

struct CommunityAuthor: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let avatarUrl: String?
}
