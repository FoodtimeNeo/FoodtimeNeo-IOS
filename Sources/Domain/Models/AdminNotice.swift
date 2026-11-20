import Foundation

/// 管理端公告：`content` 为 Markdown，`title` 由服务端取首个标题生成。
struct AdminNotice: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let body: String
    let publishedAt: Date?
    let content: String?
    let createdTime: Date?
    let displayStartsAt: Date?
    let displayEndsAt: Date?
    let expiresOn: String?
    let isUpdate: Bool
    let published: Bool
    let enabled: Bool
    let seq: Int
    let status: String
}

/// 登录弹窗“当前公告”设置；null 表示不弹。
struct AdminNoticeSettings: Codable, Equatable, Sendable {
    let noticeId: String?
}

/// 排期字段用 ISO8601 字符串编码，避免 JSONEncoder 默认日期策略与后端 Instant 不兼容。
struct AdminNoticeScheduleRequest: Encodable, Equatable, Sendable {
    var publishedAt: String?
    var displayStartsAt: String?
    var displayEndsAt: String?
    var expiresOn: String?
    var isUpdate: Bool
    var published: Bool
    var enabled: Bool
}

enum AdminNoticeStatusLabel {
    static func label(_ status: String) -> String {
        switch status {
        case "published": return "已发布"
        case "scheduled": return "已排期"
        case "paused": return "已停用"
        case "expired": return "已过期"
        default: return status
        }
    }
}

enum AdminNoticeDates {
    static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    static func localDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
