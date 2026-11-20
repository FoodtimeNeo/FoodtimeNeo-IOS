import Foundation

/// 通知信箱：公告与系统消息共用未读入口，但读取与已读是两套独立接口。
protocol InboxService: AnyObject {
    func notices(page: Int, size: Int) async throws -> Page<Notice>
    func markNoticeRead(id: String) async throws
    func unreadNoticeCount() async throws -> Int

    func messages(page: Int, size: Int) async throws -> Page<InboxMessage>
    func markMessageRead(id: String) async throws
    func markAllMessagesRead() async throws
    func unreadMessageCount() async throws -> Int
}
