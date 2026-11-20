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

    func testModerationQueueDecodesAndSendsFilters() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"sub-1","type":"dish","targetId":"stall-1","userId":"u-1","userDisplayName":"干饭人","name":"红烧肉","content":"新菜品","price":12.5,"imageUrl":null,"rating":null,"status":"pending","reason":null,"createdAt":"2099-11-20T04:00:00Z","aiRiskLevel":"low","aiConfidence":0.9,"aiLabels":["food"],"aiReason":"ok","aiCheckedAt":null,"userEmail":"user@example.com","contentRevision":null}],"total":1,"page":2,"size":20}
            """))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.moderationQueue(
            status: "pending",
            type: "dish",
            page: 2,
            size: 20
        )

        XCTAssertEqual(page.total, 1)
        XCTAssertEqual(page.items.first?.price, Decimal(string: "12.5"))
        XCTAssertEqual(page.items.first?.userEmail, "user@example.com")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/admin/moderation")
        let query = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
            .queryItems
        XCTAssertEqual(query?.first(where: { $0.name == "status" })?.value, "pending")
        XCTAssertEqual(query?.first(where: { $0.name == "type" })?.value, "dish")
        XCTAssertEqual(query?.first(where: { $0.name == "page" })?.value, "2")
    }

    func testModerateSendsDecisionAndDecodesResult() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-a1"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"sub-1","status":"approved","approvedId":"dish-9"}
            """))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let result = try await service.moderate(
            type: "dish",
            submissionID: "sub-1",
            action: "approve",
            reason: nil,
            price: Decimal(string: "12.5"),
            contentRevision: nil
        )

        XCTAssertEqual(result.status, "approved")
        XCTAssertEqual(result.approvedId, "dish-9")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/admin/moderation/dish/sub-1")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["action"] as? String, "approve")
        XCTAssertEqual(json["price"] as? Double, 12.5)
    }

    func testModerationLogsDecode() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"log-1","submissionId":"sub-1","type":"dish","moderatorId":"admin-1","actor":"human","aiModel":null,"action":"approve","reason":null,"createdAt":"2099-11-20T04:00:00Z","userId":"u-1","userEmail":"user@example.com","userDisplayName":"干饭人","name":"红烧肉","content":"新菜品","imageUrl":null,"submittedAt":"2099-11-19T04:00:00Z"}],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.moderationLogs(page: 1, size: 20)

        XCTAssertEqual(page.items.first?.actor, "human")
        XCTAssertEqual(page.items.first?.userDisplayName, "干饭人")
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/v1/admin/moderation/logs")
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
