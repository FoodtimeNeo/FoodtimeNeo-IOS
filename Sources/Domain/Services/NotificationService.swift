import Foundation

/// 服务端七类提醒开关。开启某类只影响之后产生的事件；站内消息不受影响。
protocol NotificationService: AnyObject {
    func preferences() async throws -> NotificationPreferences
    func update(
        category: String,
        enabled: Bool,
        expectedRevision: Int
    ) async throws -> NotificationPreference
}
