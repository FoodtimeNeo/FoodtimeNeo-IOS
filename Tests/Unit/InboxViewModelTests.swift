import XCTest
@testable import FoodtimeNeo

@MainActor
final class InboxViewModelTests: XCTestCase {
    func testLoadsNoticePageAndUnreadCounts() async {
        let inbox = FakeInboxService()
        inbox.noticesResult = .success(
            Page(items: [TestFixtures.notice], total: 1, page: 1, size: 20)
        )
        inbox.noticeUnread = 2
        inbox.messageUnread = 1
        let messages = FakeMessageService()
        messages.unread = 3
        let model = InboxViewModel(inbox: inbox, messages: messages)

        await model.loadCounts()
        await model.load()

        XCTAssertEqual(model.notices.count, 1)
        XCTAssertEqual(model.noticeTotal, 1)
        XCTAssertEqual(model.totalUnread, 6)
        XCTAssertFalse(model.canLoadMore)
    }

    func testOpeningNoticeMarksReadAndDecrementsUnread() async {
        let inbox = FakeInboxService()
        inbox.noticeUnread = 1
        let model = InboxViewModel(inbox: inbox, messages: FakeMessageService())
        await model.loadCounts()

        await model.openNotice(TestFixtures.notice)

        XCTAssertEqual(inbox.readNoticeIDs, [TestFixtures.notice.id])
        XCTAssertEqual(model.noticeUnread, 0)
    }

    func testOpeningMessageFlipsReadAndDecrementsUnread() async {
        let inbox = FakeInboxService()
        inbox.messagesResult = .success(
            Page(items: [TestFixtures.inboxMessage], total: 1, page: 1, size: 20)
        )
        inbox.messageUnread = 1
        let model = InboxViewModel(inbox: inbox, messages: FakeMessageService())
        await model.switchSegment(.messages)
        await model.loadCounts()

        await model.openMessage(TestFixtures.inboxMessage)

        XCTAssertEqual(inbox.readMessageIDs, [TestFixtures.inboxMessage.id])
        XCTAssertEqual(model.messages.first?.isRead, true)
        XCTAssertEqual(model.messageUnread, 0)
    }

    func testSwitchToChatsLoadsConversationPage() async {
        let messages = FakeMessageService()
        messages.conversationsResult = .success(
            Page(items: [TestFixtures.conversation], total: 1, page: 1, size: 20)
        )
        let model = InboxViewModel(inbox: FakeInboxService(), messages: messages)

        await model.switchSegment(.chats)

        XCTAssertEqual(model.conversations.count, 1)
        XCTAssertEqual(model.chatTotal, 1)
        XCTAssertEqual(model.segment, .chats)
    }

    func testOpeningConversationClearsUnreadLocally() async {
        let messages = FakeMessageService()
        messages.conversationsResult = .success(
            Page(items: [TestFixtures.conversation], total: 1, page: 1, size: 20)
        )
        let model = InboxViewModel(inbox: FakeInboxService(), messages: messages)
        await model.switchSegment(.chats)
        await model.loadCounts()

        model.handleConversationOpened(TestFixtures.conversation.id)

        XCTAssertEqual(model.conversations.first?.unreadCount, 0)
        XCTAssertEqual(model.chatUnread, 0)
    }

    func testMarkAllMessagesReadClearsUnread() async {
        let inbox = FakeInboxService()
        inbox.messagesResult = .success(
            Page(items: [TestFixtures.inboxMessage], total: 1, page: 1, size: 20)
        )
        inbox.messageUnread = 4
        let model = InboxViewModel(inbox: inbox, messages: FakeMessageService())
        await model.switchSegment(.messages)
        await model.loadCounts()

        await model.markAllMessagesRead()

        XCTAssertEqual(inbox.markAllCalls, 1)
        XCTAssertEqual(model.messages.first?.isRead, true)
        XCTAssertEqual(model.messageUnread, 0)
    }
}
