import XCTest
@testable import FoodtimeNeo

@MainActor
final class ChatViewModelTests: XCTestCase {
    func testSendRejectsBlankAndTooLong() async {
        let model = makeModel()

        model.draft = "   "
        await model.send()
        XCTAssertEqual(model.errorMessage, "消息不能为空")

        model.draft = String(repeating: "好", count: 1001)
        await model.send()
        XCTAssertEqual(model.errorMessage, "消息不能超过1000字")
    }

    func testSendTrimsAndReusesRequestIDAfterFailure() async {
        let service = FakeMessageService()
        var attempts = 0
        service.sendHandler = { conversationID, content, requestID in
            attempts += 1
            if attempts == 1 {
                throw AppError.network(message: "offline")
            }
            return DirectMessage(
                id: "dm-2",
                conversationId: conversationID,
                senderId: TestFixtures.user.id,
                content: content,
                createdAt: Date()
            )
        }
        let model = ChatViewModel(
            conversationID: TestFixtures.conversation.id,
            service: service,
            social: FakeSocialService(),
            currentUserID: TestFixtures.user.id
        )

        model.draft = "  你好  "
        await model.send()

        XCTAssertEqual(model.draft, "  你好  ")
        XCTAssertNotNil(model.errorMessage)

        await model.send()

        XCTAssertEqual(model.draft, "")
        XCTAssertEqual(service.sent.count, 2)
        XCTAssertEqual(service.sent[0].content, "你好")
        XCTAssertEqual(service.sent[0].requestID, service.sent[1].requestID)
        XCTAssertEqual(model.messages.count, 1)
    }

    func testLoadReadsConversationMessagesAndBlockState() async {
        let service = FakeMessageService()
        service.conversationResult = .success(TestFixtures.conversation)
        service.messagePageResult = .success(
            DirectMessagePage(
                items: [TestFixtures.directMessage],
                hasMore: false,
                nextCursor: nil
            )
        )
        let social = FakeSocialService()
        social.blockStateResult = BlockState(blocked: true)
        let model = ChatViewModel(
            conversationID: TestFixtures.conversation.id,
            service: service,
            social: social,
            currentUserID: TestFixtures.user.id
        )

        await model.load()

        XCTAssertEqual(model.messages.count, 1)
        XCTAssertTrue(model.blockedByMe)
        XCTAssertEqual(service.readConversationIDs, [TestFixtures.conversation.id])
        XCTAssertEqual(social.blockStateCalls, [TestFixtures.conversation.other.id])
        XCTAssertTrue(model.isMine(model.messages[0]) == false)
    }

    func testToggleBlockUnblocksWhenAlreadyBlocked() async {
        let service = FakeMessageService()
        service.conversationResult = .success(TestFixtures.conversation)
        let social = FakeSocialService()
        social.blockStateResult = BlockState(blocked: true)
        social.unblockResult = BlockState(blocked: false)
        let model = ChatViewModel(
            conversationID: TestFixtures.conversation.id,
            service: service,
            social: social,
            currentUserID: TestFixtures.user.id
        )
        await model.load()

        await model.toggleBlock()

        XCTAssertFalse(model.blockedByMe)
        XCTAssertEqual(social.unblockCalls, [TestFixtures.conversation.other.id])
        XCTAssertNotNil(model.infoMessage)
    }

    func testHideConversationCallsService() async {
        let service = FakeMessageService()
        let model = ChatViewModel(
            conversationID: TestFixtures.conversation.id,
            service: service,
            social: FakeSocialService(),
            currentUserID: TestFixtures.user.id
        )

        let hidden = await model.hideConversation()

        XCTAssertTrue(hidden)
        XCTAssertEqual(service.hiddenConversationIDs, [TestFixtures.conversation.id])
    }

    private func makeModel() -> ChatViewModel {
        ChatViewModel(
            conversationID: TestFixtures.conversation.id,
            service: FakeMessageService(),
            social: FakeSocialService(),
            currentUserID: TestFixtures.user.id
        )
    }
}
