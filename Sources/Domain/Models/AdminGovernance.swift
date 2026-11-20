import Foundation

/// 管理端举报队列行；后端只给 ID 与摘要，不返回举报人昵称/邮箱。
struct AdminReportRow: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let targetType: String
    let targetId: String?
    let targetUserId: String?
    let postId: String?
    let reason: String
    let excerpt: String?
    let createdAt: Date?
}

struct AdminReportDecisionReceipt: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let reportId: String
    let outcome: String
    let publicReason: String
    let internalNote: String?
    let reviewerId: String?
    let createdAt: Date?
}

struct AdminReportDecision: Codable, Identifiable, Equatable, Sendable {
    let decisionId: String
    let reportId: String
    let outcome: String
    let publicReason: String
    let targetType: String
    let targetId: String?
    let targetUserId: String?
    let createdAt: Date?

    var id: String { decisionId }
}

struct AdminReportFollowUp: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let reportId: String
    let authorRole: String
    let authorName: String
    let content: String
    let internalNote: String?
    let evidenceUrls: [String]
    let createdAt: Date?
}

struct AdminReportAction: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let decisionId: String?
    let actionType: String
    let targetType: String?
    let targetId: String?
    let performedBy: String?
    let note: String?
    let createdAt: Date?
}

struct AdminAppeal: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let decisionId: String
    let appellantId: String?
    let appellantName: String
    let side: String?
    let content: String
    let status: String
    let outcome: String?
    let publicReason: String?
    let internalNote: String?
    let revision: Int
    let createdAt: Date?
    let resolvedAt: Date?
    let evidenceUrls: [String]
}

enum AdminReportOutcome {
    static let upheld = "upheld"
    static let notUpheld = "not_upheld"

    static func label(_ value: String) -> String {
        switch value {
        case upheld: return "成立"
        case notUpheld: return "不成立"
        default: return value
        }
    }
}

enum AdminAppealStatus {
    static let submitted = "submitted"
    static let underReview = "under_review"
    static let resolved = "resolved"

    static func label(_ value: String) -> String {
        switch value {
        case submitted: return "已提交"
        case underReview: return "复核中"
        case resolved: return "已结束"
        default: return value
        }
    }
}

enum AdminReportActionType: String, CaseIterable, Identifiable {
    case removePost = "remove_post"
    case removeComment = "remove_comment"
    case disableUser = "disable_user"
    case restoreUser = "restore_user"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .removePost: return "删除食记"
        case .removeComment: return "删除评论"
        case .disableUser: return "停用账号"
        case .restoreUser: return "恢复账号"
        }
    }

    var requiresTargetID: Bool {
        switch self {
        case .removePost, .removeComment: return true
        case .disableUser, .restoreUser: return false
        }
    }
}
