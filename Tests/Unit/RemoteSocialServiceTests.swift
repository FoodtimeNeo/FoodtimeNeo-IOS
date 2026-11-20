import XCTest
@testable import FoodtimeNeo

final class RemoteSocialServiceTests: XCTestCase {
    func testSearchDecodesPageAndSendsQuery() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"u-1","displayName":"干饭人","avatarUrl":null,"followedByMe":false}],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteSocialService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.searchUsers(query: " 干饭 ", page: 1, size: 20)

        XCTAssertEqual(page.items.first?.displayName, "干饭人")
        XCTAssertEqual(page.total, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/users/search")
        let url = try XCTUnwrap(request.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "q" })?.value, "干饭")
    }

    func testFollowAndUnfollowUsePutAndDelete() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-s1"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"followed":true,"followerCount":1}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"followed":false,"followerCount":0}
            """))
        ]
        let service = RemoteSocialService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let followed = try await service.follow(userID: "u-1")
        let unfollowed = try await service.unfollow(userID: "u-1")

        XCTAssertTrue(followed.followed)
        XCTAssertFalse(unfollowed.followed)
        XCTAssertEqual(transport.requests[1].httpMethod, "PUT")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/users/u-1/follow")
        XCTAssertEqual(transport.requests[2].httpMethod, "DELETE")
        XCTAssertEqual(transport.requests[2].url?.path, "/api/v1/users/u-1/follow")
    }

    func testBlockedUsersAndUnblock() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"u-2","displayName":"拉黑人","avatarUrl":null,"blockedAt":"2099-11-20T04:00:00Z"}],"total":1,"page":1,"size":20}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-s2"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"blocked":false}
            """))
        ]
        let service = RemoteSocialService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.blockedUsers(page: 1, size: 20)
        let state = try await service.unblock(userID: "u-2")

        XCTAssertEqual(page.items.first?.displayName, "拉黑人")
        XCTAssertFalse(state.blocked)
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/users/me/blocks")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/auth/csrf")
        XCTAssertEqual(transport.requests[2].httpMethod, "DELETE")
        XCTAssertEqual(transport.requests[2].url?.path, "/api/v1/users/u-2/block")
    }
}
