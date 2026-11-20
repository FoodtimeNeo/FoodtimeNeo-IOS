import Foundation

/// 本人提交的举报与公开结果。
struct UserReport: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let targetType: String
    let targetId: String
    let postId: String?
    let reason: String
    let excerpt: String?
    let status: String
    let createdAt: Date?
    let decisionId: String?
    let outcome: String?
    let publicReason: String?
    let decidedAt: Date?

    var statusLabel: String {
        switch status {
        case "completed": return "已完成"
        case "legacy": return "历史记录"
        default: return "待处理"
        }
    }

    var targetLabel: String {
        switch targetType {
        case "post": return "食记"
        case "comment": return "评论"
        case "message": return "私信"
        default: return targetType
        }
    }
}

/// 本人作为举报人或被举报人收到的处理决定。被举报人投影不含举报人与内部备注。
struct ModerationDecision: Codable, Identifiable, Equatable, Sendable {
    let decisionId: String
    let reportId: String?
    let side: String
    let targetType: String
    let outcome: String
    let publicReason: String
    let deliveredAt: Date?
    let appealDeadline: Date
    let appealId: String?
    let appealStatus: String?
    let appealOutcome: String?

    var id: String { decisionId }

    var targetLabel: String {
        switch targetType {
        case "post": return "食记"
        case "comment": return "评论"
        case "message": return "私信"
        default: return targetType
        }
    }

    var outcomeLabel: String { outcome == "upheld" ? "成立" : "不成立" }

    var sideLabel: String { side == "reporter" ? "你是举报人" : "你是被举报人" }

    var appealStatusLabel: String {
        switch appealStatus ?? "" {
        case "under_review": return "复核中"
        case "resolved": return "已复核"
        case "": return ""
        default: return "已提交"
        }
    }

    var canAppeal: Bool {
        (appealStatus ?? "").isEmpty && appealDeadline > Date()
    }

    func appealOutcomeLabel() -> String {
        guard let appealOutcome, !appealOutcome.isEmpty else { return "" }
        return appealOutcome == "upheld" ? "成立" : "不成立"
    }
}

struct ReportAction: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let decisionId: String
    let actionType: String
    let targetType: String
    let targetId: String?
    let performedBy: String
    let note: String?
    let createdAt: Date?

    var label: String {
        switch actionType {
        case "remove_post": return "下架帖子"
        case "remove_comment": return "下架评论"
        case "disable_user": return "停用账号"
        case "restore_user": return "恢复账号"
        default: return actionType
        }
    }
}

/// 举报追问线程。管理员公开回复的 `internalNote` 不返回给用户端。
struct ReportFollowUp: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let reportId: String
    let authorRole: String
    let authorName: String?
    let content: String
    let internalNote: String?
    let evidenceUrls: [String]
    let createdAt: Date?

    var isStaff: Bool { authorRole == "staff" }
}

struct ReportAppeal: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let decisionId: String
    let appellantId: String
    let appellantName: String?
    let side: String
    let content: String
    let status: String
    let outcome: String?
    let publicReason: String?
    let internalNote: String?
    let revision: Int
    let createdAt: Date?
    let resolvedAt: Date?
    let evidenceUrls: [String]

    var statusLabel: String {
        switch status {
        case "under_review": return "复核中"
        case "resolved": return "已复核"
        default: return "已提交"
        }
    }

    var outcomeLabel: String {
        guard let outcome, !outcome.isEmpty else { return "" }
        return outcome == "upheld" ? "成立" : "不成立"
    }
}
