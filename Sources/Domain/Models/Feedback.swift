import Foundation

enum FeedbackType: String, CaseIterable, Identifiable, Hashable, Sendable {
    case function
    case content
    case usage
    case suggestion
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .function: return "功能反馈"
        case .content: return "内容反馈"
        case .usage: return "使用反馈"
        case .suggestion: return "改进建议"
        case .other: return "其他"
        }
    }
}

struct Feedback: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let type: String
    let content: String
    let status: String
    let createdAt: Date?
    let updatedAt: Date?
    let userDisplayName: String
    let latestReply: String?

    var typeLabel: String {
        FeedbackType(rawValue: type)?.label ?? type
    }

    var statusLabel: String {
        switch status {
        case "processing": return "处理中"
        case "completed": return "已完成"
        case "pending": return "待处理"
        default: return "状态更新中"
        }
    }
}

struct FeedbackReply: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let content: String
    let createdAt: Date?
}
