import XCTest
@testable import FoodtimeNeo

final class RemoteInboxServiceTests: XCTestCase {
    func testNoticesDecodePublishedAtAndPaging() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"n-1","content":"# 假期安排","publishedAt":"2099-11-21T04:00:00Z","isUpdate":true}],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteInboxService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.notices(page: 1, size: 20)

        XCTAssertEqual(page.items.first?.id, "n-1")
        XCTAssertEqual(page.items.first?.isUpdate, true)
        XCTAssertNotNil(page.items.first?.publishedAt)
        let url = try XCTUnwrap(transport.requests.first?.url)
        XCTAssertEqual(url.path, "/api/v1/users/me/notices")
    }

    func testNoticeFallsBackToCreatedTime() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"n-2","content":"旧版投影","createdTime":"2099-11-21T04:00:00Z"}],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteInboxService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.notices(page: 1, size: 20)

        XCTAssertNotNil(page.items.first?.publishedAt)
        XCTAssertEqual(page.items.first?.isUpdate, false)
    }

    func testMarkNoticeReadPostsWithCSRF() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-notice"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let service = RemoteInboxService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        try await service.markNoticeRead(id: "n-1")

        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/users/me/notices/n-1/read")
        XCTAssertEqual(
            transport.requests[1].value(forHTTPHeaderField: "X-CSRF-TOKEN"),
            "token-notice"
        )
    }

    func testMessageListDecodesReadFlagAndCounts() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"m-1","title":"有人赞了你","body":"去看看吧","category":"LIKE_POST","refType":"community-post","refId":"post-1","refCommentId":null,"refRootCommentId":null,"actorCount":2,"isRead":false,"createdAt":"2099-11-21T04:00:00Z"}],"total":1,"page":1,"size":20}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"unreadCount":4}
            """))
        ]
        let service = RemoteInboxService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.messages(page: 1, size: 20)
        let unread = try await service.unreadMessageCount()

        XCTAssertEqual(page.items.first?.isRead, false)
        XCTAssertEqual(page.items.first?.actorCount, 2)
        XCTAssertTrue(page.items.first?.opensCommunityPost == true)
        XCTAssertEqual(unread, 4)
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/users/me/messages")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/users/me/messages/unread-count")
    }

    func testMarkAllMessagesReadPostsOnce() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-all"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let service = RemoteInboxService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        try await service.markAllMessagesRead()

        XCTAssertEqual(transport.requests[1].httpMethod, "POST")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/users/me/messages/read-all")
    }
}
