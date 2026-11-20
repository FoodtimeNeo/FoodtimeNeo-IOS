import XCTest
@testable import FoodtimeNeo

final class RemoteMessageServiceTests: XCTestCase {
    func testConversationsDecodeAndSendPaging() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"conv-1","other":{"id":"u-2","displayName":"饭搭子","avatarUrl":null},"lastMessage":"中午吃什么","lastSenderId":"u-2","lastMessageAt":"2099-11-21T04:00:00Z","unreadCount":1,"updatedAt":"2099-11-21T04:00:00Z"}],"total":1,"page":1,"size":20}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"unreadCount":3}
            """))
        ]
        let service = RemoteMessageService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.conversations(page: 1, size: 20)
        let unread = try await service.unreadCount()

        XCTAssertEqual(page.items.first?.other.displayName, "饭搭子")
        XCTAssertEqual(page.items.first?.unreadCount, 1)
        XCTAssertEqual(unread, 3)
        let url = try XCTUnwrap(transport.requests.first?.url)
        XCTAssertEqual(url.path, "/api/v1/users/me/conversations")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "page" })?.value, "1")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "size" })?.value, "20")
    }

    func testStartConversationSendsUserIDWithCSRF() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-chat"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"conv-9","other":{"id":"u-9","displayName":"新同学","avatarUrl":null},"lastMessage":null,"lastSenderId":null,"lastMessageAt":null,"unreadCount":0,"updatedAt":"2099-11-21T04:00:00Z"}
            """))
        ]
        let service = RemoteMessageService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let conversation = try await service.startConversation(userID: "u-9")

        XCTAssertEqual(conversation.id, "conv-9")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/users/me/conversations")
        XCTAssertEqual(transport.requests[1].httpMethod, "POST")
        XCTAssertEqual(
            transport.requests[1].value(forHTTPHeaderField: "X-CSRF-TOKEN"),
            "token-chat"
        )
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["userId"] as? String, "u-9")
    }

    func testMessageCursorAndSendBody() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"dm-1","conversationId":"conv-1","senderId":"u-2","content":"中午吃什么","createdAt":"2099-11-21T04:00:00Z"}],"hasMore":true,"nextCursor":"cursor-2"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-send"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"dm-2","conversationId":"conv-1","senderId":"me","content":"吃面","createdAt":"2099-11-21T04:01:00Z"}
            """))
        ]
        let service = RemoteMessageService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.messages(conversationID: "conv-1", size: 30, cursor: "cursor-1")
        let sent = try await service.send(
            conversationID: "conv-1",
            content: "吃面",
            requestID: "request-dm-1"
        )

        XCTAssertEqual(page.items.first?.content, "中午吃什么")
        XCTAssertEqual(page.nextCursor, "cursor-2")
        XCTAssertEqual(sent.id, "dm-2")
        let listURL = try XCTUnwrap(transport.requests.first?.url)
        let components = try XCTUnwrap(URLComponents(url: listURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "cursor" })?.value, "cursor-1")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "size" })?.value, "30")
        XCTAssertEqual(
            transport.requests[2].url?.path,
            "/api/v1/users/me/conversations/conv-1/messages"
        )
        let body = try XCTUnwrap(transport.requests[2].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["content"] as? String, "吃面")
        XCTAssertEqual(json["clientRequestId"] as? String, "request-dm-1")
    }

    func testMarkReadAndHideUseExpectedMethods() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-read"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null")),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let service = RemoteMessageService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        try await service.markRead(conversationID: "conv-1")
        try await service.hide(conversationID: "conv-1")

        XCTAssertEqual(transport.requests[1].httpMethod, "POST")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/users/me/conversations/conv-1/read")
        XCTAssertEqual(transport.requests[2].httpMethod, "DELETE")
        XCTAssertEqual(transport.requests[2].url?.path, "/api/v1/users/me/conversations/conv-1")
    }
}
