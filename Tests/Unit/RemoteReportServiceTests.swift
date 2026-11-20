import XCTest
@testable import FoodtimeNeo

final class RemoteReportServiceTests: XCTestCase {
    func testSubmitReportSendsTargetAndReason() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-report"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let service = makeService(transport)

        try await service.submitReport(targetType: "post", targetID: "post-1", reason: "内容违规")

        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/reports")
        XCTAssertEqual(transport.requests[1].httpMethod, "POST")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["targetType"] as? String, "post")
        XCTAssertEqual(json["targetId"] as? String, "post-1")
        XCTAssertEqual(json["reason"] as? String, "内容违规")
    }

    func testMyReportsDecodeReceiptStatus() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[\(ReportFixtures.reportJSON)],"total":1,"page":1,"size":20}
            """))
        ]
        let service = makeService(transport)

        let page = try await service.myReports(page: 1, size: 20)

        XCTAssertEqual(page.items.first?.targetLabel, "食记")
        XCTAssertEqual(page.items.first?.statusLabel, "已完成")
        XCTAssertEqual(page.items.first?.outcome, "upheld")
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/v1/users/me/reports")
    }

    func testDecisionsAndActionsPaths() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[\(ReportFixtures.decisionJSON)],"total":1,"page":1,"size":20}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            [\(ReportFixtures.actionJSON)]
            """))
        ]
        let service = makeService(transport)

        let page = try await service.myDecisions(page: 1, size: 20)
        let actions = try await service.decisionActions(decisionID: "d-1")

        let decision = try XCTUnwrap(page.items.first)
        XCTAssertTrue(decision.canAppeal)
        XCTAssertEqual(decision.sideLabel, "你是举报人")
        XCTAssertEqual(actions.first?.label, "下架帖子")
        XCTAssertEqual(
            transport.requests[1].url?.path,
            "/api/v1/users/me/moderation-decisions/d-1/actions"
        )
    }

    func testFollowUpThreadAndSubmit() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[\(ReportFixtures.followUpJSON)],"total":1,"page":1,"size":20}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-follow"}
            """)),
            .init(status: 201, body: TestFixtures.envelope(ReportFixtures.followUpJSON))
        ]
        let service = makeService(transport)

        let page = try await service.followUps(reportID: "r-1", page: 1, size: 20)
        let created = try await service.addFollowUp(
            reportID: "r-1",
            content: "请再核对",
            evidenceURLs: ["/api/v1/media/media-1"],
            requestID: "request-1"
        )

        XCTAssertTrue(page.items.first?.isStaff == true)
        XCTAssertEqual(created.id, "f-1")
        XCTAssertEqual(
            transport.requests[2].url?.path,
            "/api/v1/users/me/reports/r-1/follow-ups"
        )
        let body = try XCTUnwrap(transport.requests[2].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["content"] as? String, "请再核对")
        XCTAssertEqual(json["clientRequestId"] as? String, "request-1")
        XCTAssertEqual(json["evidenceUrls"] as? [String], ["/api/v1/media/media-1"])
    }

    func testAppealSubmitAndList() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-appeal"}
            """)),
            .init(status: 201, body: TestFixtures.envelope(ReportFixtures.appealJSON)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[\(ReportFixtures.appealJSON)],"total":1,"page":1,"size":20}
            """))
        ]
        let service = makeService(transport)

        let appeal = try await service.submitAppeal(
            decisionID: "d-1",
            content: "请复核",
            evidenceURLs: [],
            requestID: "request-appeal"
        )
        let page = try await service.myAppeals(page: 1, size: 20)

        XCTAssertEqual(appeal.statusLabel, "已提交")
        XCTAssertEqual(page.items.first?.id, "ap-1")
        XCTAssertEqual(
            transport.requests[1].url?.path,
            "/api/v1/users/me/moderation-decisions/d-1/appeals"
        )
        XCTAssertEqual(transport.requests[2].url?.path, "/api/v1/users/me/appeals")
    }

    private func makeService(_ transport: StubHTTPTransport) -> RemoteReportService {
        RemoteReportService(api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar()))
    }
}

enum ReportFixtures {
    static let reportJSON = """
    {"id":"r-1","targetType":"post","targetId":"post-1","postId":"post-1","reason":"内容违规","excerpt":"这段内容","status":"completed","createdAt":"2099-11-21T04:00:00Z","decisionId":"d-1","outcome":"upheld","publicReason":"违反社区规范","decidedAt":"2099-11-21T05:00:00Z"}
    """

    static let decisionJSON = """
    {"decisionId":"d-1","reportId":"r-1","side":"reporter","targetType":"post","outcome":"upheld","publicReason":"违反社区规范","deliveredAt":"2099-11-21T05:00:00Z","appealDeadline":"2099-11-28T05:00:00Z","appealId":null,"appealStatus":null,"appealOutcome":null}
    """

    static let actionJSON = """
    {"id":"a-1","decisionId":"d-1","actionType":"remove_post","targetType":"post","targetId":"post-1","performedBy":"admin-1","note":"已下架","createdAt":"2099-11-21T05:10:00Z"}
    """

    static let followUpJSON = """
    {"id":"f-1","reportId":"r-1","authorRole":"staff","authorName":"管理员","content":"已收到补充材料","internalNote":null,"evidenceUrls":[],"createdAt":"2099-11-21T06:00:00Z"}
    """

    static let appealJSON = """
    {"id":"ap-1","decisionId":"d-1","appellantId":"u-1","appellantName":"干饭人","side":"reporter","content":"请复核","status":"submitted","outcome":null,"publicReason":null,"internalNote":null,"revision":1,"createdAt":"2099-11-21T06:00:00Z","resolvedAt":null,"evidenceUrls":[]}
    """
}
