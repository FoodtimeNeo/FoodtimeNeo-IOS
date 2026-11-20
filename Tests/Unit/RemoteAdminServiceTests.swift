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

    func testCommunityQueueUsesKindPathAndFilters() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"post-1","type":"community-post","targetId":null,"userId":"u-1","userDisplayName":"干饭人","name":"今天的食堂","content":"好吃","price":null,"imageUrl":null,"rating":null,"status":"pending","reason":null,"createdAt":"2099-11-20T04:00:00Z","aiRiskLevel":"medium","aiConfidence":0.7,"aiLabels":null,"aiReason":null,"aiCheckedAt":null,"userEmail":"user@example.com","contentRevision":3}],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.communityQueue(
            kind: "posts",
            status: "pending",
            page: 1,
            size: 20
        )

        XCTAssertEqual(page.items.first?.contentRevision, 3)
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/v1/admin/community/posts")
        let query = URLComponents(
            url: try XCTUnwrap(transport.requests.first?.url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(query?.first(where: { $0.name == "status" })?.value, "pending")
    }

    func testCommunityModerateSendsRevision() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-a1"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"post-1","status":"approved","approvedId":"post-1"}
            """))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let result = try await service.moderateCommunity(
            kind: "posts",
            id: "post-1",
            action: "approve",
            reason: nil,
            contentRevision: 3
        )

        XCTAssertEqual(result.status, "approved")
        XCTAssertEqual(
            transport.requests[1].url?.path,
            "/api/v1/admin/community/posts/post-1"
        )
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["action"] as? String, "approve")
        XCTAssertEqual(json["contentRevision"] as? Int, 3)
    }

    func testCommunityDetailAndDelete() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"post":null,"comment":null,"rootComment":null,"replyToComment":null,"userEmail":"user@example.com"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-a1"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let detail = try await service.communityModerationDetail(
            kind: "comments",
            id: "comment-1"
        )
        try await service.deleteCommunityContent(kind: "comments", id: "comment-1")

        XCTAssertEqual(detail.userEmail, "user@example.com")
        XCTAssertEqual(
            transport.requests[0].url?.path,
            "/api/v1/admin/community/comments/comment-1"
        )
        XCTAssertEqual(transport.requests[2].httpMethod, "DELETE")
        XCTAssertEqual(
            transport.requests[2].url?.path,
            "/api/v1/admin/community/comments/comment-1"
        )
    }

    func testReportsPendingDecisionAndHistory() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"report-1","targetType":"community-post","targetId":"post-1","targetUserId":"u-1","postId":"post-1","reason":"spam","excerpt":"广告","createdAt":"2099-11-20T04:00:00Z"}],"total":1,"page":1,"size":20}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-a1"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"decision-1","reportId":"report-1","outcome":"upheld","publicReason":"违规","internalNote":null,"reviewerId":"admin-1","createdAt":"2099-11-20T04:10:00Z"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"decisionId":"decision-1","reportId":"report-1","outcome":"upheld","publicReason":"违规","targetType":"community-post","targetId":"post-1","targetUserId":"u-1","createdAt":"2099-11-20T04:10:00Z"}],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let pending = try await service.reportsPending(page: 1, size: 20)
        let receipt = try await service.decideReport(
            id: "report-1",
            outcome: "upheld",
            publicReason: "违规",
            internalNote: nil
        )
        let history = try await service.reportDecisions(page: 1, size: 20)

        XCTAssertEqual(pending.items.first?.reason, "spam")
        XCTAssertEqual(receipt.outcome, "upheld")
        XCTAssertEqual(history.items.first?.decisionId, "decision-1")
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/admin/reports")
        XCTAssertEqual(
            transport.requests[2].url?.path,
            "/api/v1/admin/reports/report-1/decision"
        )
        let body = try XCTUnwrap(transport.requests[2].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["outcome"] as? String, "upheld")
        XCTAssertEqual(json["publicReason"] as? String, "违规")
        XCTAssertEqual(transport.requests[3].url?.path, "/api/v1/admin/reports/decisions")
    }

    func testReportFollowUpsActionsAndReview() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-a1"}
            """)),
            .init(status: 201, body: TestFixtures.envelope("""
            {"id":"follow-1","reportId":"report-1","authorRole":"admin","authorName":"管理员","content":"请补充证据","internalNote":null,"evidenceUrls":[],"createdAt":"2099-11-20T04:20:00Z"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            [{"id":"action-1","decisionId":"decision-1","actionType":"remove_post","targetType":"community-post","targetId":"post-1","performedBy":"admin-1","note":null,"createdAt":"2099-11-20T04:30:00Z"}]
            """)),
            .init(status: 201, body: TestFixtures.envelope("""
            {"id":"action-2","decisionId":"decision-1","actionType":"disable_user","targetType":"user","targetId":"u-1","performedBy":"admin-1","note":"重复违规","createdAt":"2099-11-20T04:31:00Z"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null")),
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[],"total":0,"page":1,"size":20}
            """))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let followUp = try await service.addReportFollowUp(
            id: "report-1",
            content: "请补充证据",
            internalNote: nil,
            evidenceUrls: [],
            clientRequestID: "req-1"
        )
        let actions = try await service.reportActions(id: "report-1")
        let performed = try await service.performReportAction(
            id: "report-1",
            actionType: "disable_user",
            targetID: "u-1",
            note: "重复违规"
        )
        try await service.markReportReviewed(id: "report-1")
        _ = try await service.reportFollowUps(id: "report-1", page: 1, size: 20)

        XCTAssertEqual(followUp.authorRole, "admin")
        XCTAssertEqual(actions.first?.actionType, "remove_post")
        XCTAssertEqual(performed.actionType, "disable_user")
        XCTAssertEqual(
            transport.requests[1].url?.path,
            "/api/v1/admin/reports/report-1/follow-ups"
        )
        let followBody = try XCTUnwrap(transport.requests[1].httpBody)
        let followJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: followBody) as? [String: Any]
        )
        XCTAssertEqual(followJSON["clientRequestId"] as? String, "req-1")
        XCTAssertEqual(transport.requests[3].httpMethod, "POST")
        let actionBody = try XCTUnwrap(transport.requests[3].httpBody)
        let actionJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: actionBody) as? [String: Any]
        )
        XCTAssertEqual(actionJSON["actionType"] as? String, "disable_user")
        XCTAssertEqual(actionJSON["targetId"] as? String, "u-1")
        XCTAssertEqual(transport.requests[4].httpMethod, "PUT")
        XCTAssertEqual(
            transport.requests[4].url?.path,
            "/api/v1/admin/reports/report-1/review"
        )
    }

    func testAppealsListDetailStartAndResolve() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"appeal-1","decisionId":"decision-1","appellantId":"u-1","appellantName":"干饭人","side":"author","content":"请求复核","status":"submitted","outcome":null,"publicReason":null,"internalNote":null,"revision":1,"createdAt":"2099-11-20T05:00:00Z","resolvedAt":null,"evidenceUrls":[]}],"total":1,"page":1,"size":20}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"appeal-1","decisionId":"decision-1","appellantId":"u-1","appellantName":"干饭人","side":"author","content":"请求复核","status":"submitted","outcome":null,"publicReason":null,"internalNote":"内部","revision":1,"createdAt":"2099-11-20T05:00:00Z","resolvedAt":null,"evidenceUrls":[]}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-a1"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"appeal-1","decisionId":"decision-1","appellantId":"u-1","appellantName":"干饭人","side":"author","content":"请求复核","status":"under_review","outcome":null,"publicReason":null,"internalNote":null,"revision":2,"createdAt":"2099-11-20T05:00:00Z","resolvedAt":null,"evidenceUrls":[]}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"appeal-1","decisionId":"decision-1","appellantId":"u-1","appellantName":"干饭人","side":"author","content":"请求复核","status":"resolved","outcome":"rejected","publicReason":"维持原判","internalNote":null,"revision":3,"createdAt":"2099-11-20T05:00:00Z","resolvedAt":"2099-11-20T06:00:00Z","evidenceUrls":[]}
            """))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.appeals(status: "submitted", page: 1, size: 20)
        _ = try await service.appealDetail(id: "appeal-1")
        let started = try await service.startAppeal(id: "appeal-1", expectedRevision: 1)
        let resolved = try await service.resolveAppeal(
            id: "appeal-1",
            outcome: "rejected",
            publicReason: "维持原判",
            internalNote: nil,
            expectedRevision: 2
        )

        XCTAssertEqual(page.items.first?.status, "submitted")
        XCTAssertEqual(started.status, "under_review")
        XCTAssertEqual(resolved.status, "resolved")
        let query = URLComponents(
            url: try XCTUnwrap(transport.requests[0].url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(query?.first(where: { $0.name == "status" })?.value, "submitted")
        let startQuery = URLComponents(
            url: try XCTUnwrap(transport.requests[3].url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(
            startQuery?.first(where: { $0.name == "expectedRevision" })?.value,
            "1"
        )
        XCTAssertEqual(
            transport.requests[3].url?.path,
            "/api/v1/admin/appeals/appeal-1/start"
        )
        let body = try XCTUnwrap(transport.requests[4].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["outcome"] as? String, "rejected")
        XCTAssertEqual(json["expectedRevision"] as? Int, 2)
    }

    func testCatalogListCreateUpdateDelete() async throws {
        let itemJSON = """
        {"id":"dish-1","parentId":"stall-1","name":"红烧肉","description":null,"price":12.5,"coverImageUrl":null,"status":"active","sortOrder":1,"revision":3,"priceUnit":"份"}
        """
        let catalogPageJSON = """
        {"items":[\(itemJSON)],"total":1,"page":1,"size":20}
        """
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope(catalogPageJSON)),
            .init(status: 200, body: TestFixtures.envelope(itemJSON)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-a1"}
            """)),
            .init(status: 201, body: TestFixtures.envelope(itemJSON)),
            .init(status: 200, body: TestFixtures.envelope(itemJSON)),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )
        let edit = AdminCatalogEdit(
            parentId: "stall-1",
            name: "红烧肉",
            description: "招牌",
            price: Decimal(string: "12.5"),
            coverImageUrl: nil,
            status: "active",
            sortOrder: 1,
            priceUnit: "份"
        )

        let page = try await service.catalogList(
            type: "dishes",
            parentID: "stall-1",
            page: 1,
            size: 20
        )
        _ = try await service.catalogItem(type: "dishes", id: "dish-1")
        _ = try await service.createCatalogItem(type: "dishes", edit: edit)
        _ = try await service.updateCatalogItem(type: "dishes", id: "dish-1", edit: edit)
        try await service.deleteCatalogItem(type: "dishes", id: "dish-1")

        XCTAssertEqual(page.items.first?.priceUnit, "份")
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/admin/catalog/dishes")
        let listQuery = URLComponents(
            url: try XCTUnwrap(transport.requests[0].url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(listQuery?.first(where: { $0.name == "parentId" })?.value, "stall-1")
        XCTAssertEqual(transport.requests[3].httpMethod, "POST")
        let createBody = try XCTUnwrap(transport.requests[3].httpBody)
        let createJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: createBody) as? [String: Any]
        )
        XCTAssertEqual(createJSON["name"] as? String, "红烧肉")
        XCTAssertEqual(createJSON["parentId"] as? String, "stall-1")
        XCTAssertEqual(createJSON["price"] as? Double, 12.5)
        XCTAssertEqual(transport.requests[4].httpMethod, "PUT")
        XCTAssertEqual(
            transport.requests[4].url?.path,
            "/api/v1/admin/catalog/dishes/dish-1"
        )
        XCTAssertEqual(transport.requests[5].httpMethod, "DELETE")
    }

    func testAdminReviewsAndRemove() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"review-1","dishId":"dish-1","userId":"u-1","userDisplayName":"干饭人","rating":5,"content":"好吃","createdAt":"2099-11-20T04:00:00Z","updatedAt":null,"dishName":"红烧肉","stallId":"stall-1","stallName":"一档","diningHallId":"hall-1","diningHallName":"一食堂","aiRiskLevel":null,"aiConfidence":null,"aiLabels":null,"aiReason":null,"aiCheckedAt":null,"userEmail":"user@example.com"}],"total":1,"page":1,"size":20}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-a1"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let service = RemoteAdminService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.adminReviews(query: "好吃", page: 1, size: 20)
        try await service.removeReview(id: "review-1", reason: "包含广告")

        XCTAssertEqual(page.items.first?.userEmail, "user@example.com")
        let query = URLComponents(
            url: try XCTUnwrap(transport.requests[0].url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(query?.first(where: { $0.name == "q" })?.value, "好吃")
        XCTAssertEqual(transport.requests[2].httpMethod, "DELETE")
        XCTAssertEqual(transport.requests[2].url?.path, "/api/v1/admin/reviews/review-1")
        let body = try XCTUnwrap(transport.requests[2].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["reason"] as? String, "包含广告")
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
