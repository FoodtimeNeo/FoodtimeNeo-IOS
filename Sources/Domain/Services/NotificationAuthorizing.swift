import Foundation

enum NotificationPermissionStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var allowsDelivery: Bool {
        self == .authorized || self == .provisional || self == .ephemeral
    }
}

/// 系统通知权限与业务开关分离：服务器开关决定是否创建提醒，
/// 系统权限决定提醒能否真正展示。两者都不影响站内消息可读。
@MainActor
protocol NotificationAuthorizing: AnyObject {
    func status() async -> NotificationPermissionStatus
    func requestAuthorization() async throws -> Bool
    func openSystemSettings()
}
