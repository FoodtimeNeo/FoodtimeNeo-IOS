import Foundation

/// 服务端提醒事件；`eventId` 去重，`seq` 是游标。站内消息与系统投递分离。
struct NotificationEvent: Codable, Identifiable, Equatable, Sendable {
    let eventId: String
    let seq: Int64
    let category: String
    let title: String
    let body: String?
    let refType: String?
    let refId: String?
    let refCommentId: String?
    let refRootCommentId: String?
    let createdAt: Date?
    let deliveryStatus: String?

    var id: String { eventId }
}

struct NotificationEventPage: Codable, Equatable, Sendable {
    let items: [NotificationEvent]
    let nextSeq: Int64
}
