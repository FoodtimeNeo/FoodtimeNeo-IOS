import Foundation

struct AdminUser: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let displayName: String
    let avatarUrl: String?
    let role: String
    let status: String
    let createdAt: Date?
    let reviewCount: Int
}

struct DashboardTrendDay: Codable, Equatable, Sendable {
    let day: String
    let totalUsers: Int
    let newUsers: Int
    let newReviews: Int
    let newReplies: Int
    let newPosts: Int
    let onlinePeak: Int
}

struct AdminDashboard: Codable, Equatable, Sendable {
    let totalUsers: Int
    let registeredUsers: Int
    let onlineUsers: Int
    let reviews: Int
    let replies: Int
    let posts: Int
    let halls: Int
    let stalls: Int
    let dishes: Int
    let generatedAt: Date?
    let trend: [DashboardTrendDay]
}
