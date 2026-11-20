import Foundation

@MainActor
final class InboxBadgeViewModel: ObservableObject {
    @Published private(set) var total = 0

    private let inbox: InboxService
    private let messages: MessageService

    init(inbox: InboxService, messages: MessageService) {
        self.inbox = inbox
        self.messages = messages
    }

    func load() async {
        async let noticeCount = try? await inbox.unreadNoticeCount()
        async let messageCount = try? await inbox.unreadMessageCount()
        async let chatCount = try? await messages.unreadCount()
        let values = await (noticeCount, messageCount, chatCount)
        guard values.0 != nil || values.1 != nil || values.2 != nil else { return }
        total = (values.0 ?? 0) + (values.1 ?? 0) + (values.2 ?? 0)
    }
}
