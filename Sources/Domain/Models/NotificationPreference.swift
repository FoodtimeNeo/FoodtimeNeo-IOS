import Foundation

/// 七类服务端提醒开关。站内消息始终可读，开关只影响系统提醒。
struct NotificationPreference: Codable, Identifiable, Equatable, Sendable {
    let category: String
    let enabled: Bool
    let revision: Int

    var id: String { category }

    var title: String {
        switch category {
        case "message": return "私信"
        case "interaction": return "互动"
        case "notice": return "公告"
        case "feedback": return "反馈"
        case "correction": return "纠错"
        case "report": return "举报"
        case "appeal": return "申诉"
        default: return category
        }
    }
}

struct NotificationPreferences: Codable, Equatable, Sendable {
    let items: [NotificationPreference]
}
