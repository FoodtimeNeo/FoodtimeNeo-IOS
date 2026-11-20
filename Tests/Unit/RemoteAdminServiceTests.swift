import XCTest
@testable import FoodtimeNeo

final class RemoteAdminServiceTests: XCTestCase {
    func testDashboardAndUsersDecode() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"totalUsers":10,"registeredUsers":9,"onlineUsers":2,"reviews":5,"replies":3,"posts":4,"halls":6,"stalls":20,"dishes":50,"generatedAt":"2099-11-21T04:00:00Z","trend":[{"day":"2099-11-20","totalUsers":9,"newUsers":1,"newReviews":2,"newReplies":1,"newPosts":1,"onlinePeak":2}]}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"u-1","email":"user@example.com","displayName":"干饭人","avatarUrl":null,"role":"user","status":"active","createdAt":"2099-11-21T04:00:00Z","reviewCount":2}],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let dashboard = try await service.dashboard(days: 7)
        let users = try await service.users(query: "干饭", page: 1, size: 20)

        XCTAssertEqual(dashboard.totalUsers, 10)
        XCTAssertEqual(dashboard.trend.first?.day, "2099-11-20")
        XCTAssertEqual(users.items.first?.email, "user@example.com")
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/admin/dashboard")
        let query = URLComponents(
            url: try XCTUnwrap(transport.requests[1].url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(query?.first(where: { $0.name == "q" })?.value, "干饭")
    }

    func testUpdateUserSendsRoleAndStatus() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-a1"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        try await service.updateUser(id: "u-1", role: "admin", status: "active")

        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["role"] as? String, "admin")
        XCTAssertEqual(json["status"] as? String, "active")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/admin/users/u-1")
    }
}
