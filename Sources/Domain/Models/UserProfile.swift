import Foundation

struct UserProfile: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let displayName: String
    let role: String
    let avatarUrl: String?
    let followingCount: Int
    let followerCount: Int
    let schoolEmail: String?
    let schoolEmailVerified: Bool

    var asUser: User {
        User(id: id, email: email, displayName: displayName, role: role)
    }
}
