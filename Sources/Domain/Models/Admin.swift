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

struct ModerationItem: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let type: String
    let targetId: String?
    let userId: String?
    let userDisplayName: String
    let name: String
    let content: String
    let price: Decimal?
    let imageUrl: String?
    let rating: Int?
    let status: String
    let reason: String?
    let createdAt: Date?
    let aiRiskLevel: String?
    let aiConfidence: Double?
    let aiLabels: [String]?
    let aiReason: String?
    let aiCheckedAt: Date?
    let userEmail: String?
    let contentRevision: Int?
}

struct ModerationResult: Codable, Equatable, Sendable {
    let id: String
    let status: String
    let approvedId: String?
}

struct ModerationLog: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let submissionId: String
    let type: String
    let moderatorId: String?
    let actor: String
    let aiModel: String?
    let action: String
    let reason: String?
    let createdAt: Date?
    let userId: String?
    let userEmail: String?
    let userDisplayName: String?
    let name: String?
    let content: String?
    let imageUrl: String?
    let submittedAt: Date?
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
