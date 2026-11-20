import XCTest
@testable import FoodtimeNeo

final class RemoteFeedbackServiceTests: XCTestCase {
    func testCreateSendsTypeContentAndRequestID() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-f1"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"fb-1","type":"suggestion","content":"建议","status":"pending","createdAt":"2099-11-20T04:00:00Z","updatedAt":"2099-11-20T04:00:00Z","userDisplayName":"干饭人","latestReply":null}
            """))
        ]
        let service = RemoteFeedbackService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let feedback = try await service.create(
            type: .suggestion,
            content: "建议",
            requestID: "request-1"
        )

        XCTAssertEqual(feedback.id, "fb-1")
        XCTAssertEqual(feedback.typeLabel, "改进建议")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/users/me/feedback")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "suggestion")
        XCTAssertEqual(json["content"] as? String, "建议")
        XCTAssertEqual(json["clientRequestId"] as? String, "request-1")
    }

    func testListSendsArchivedAndPagination() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[],"total":0,"page":2,"size":20}
            """))
        ]
        let service = RemoteFeedbackService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.list(archived: true, page: 2, size: 20)

        XCTAssertEqual(page.page, 2)
        let url = try XCTUnwrap(transport.requests.first?.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "archived" })?.value, "true")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "page" })?.value, "2")
    }

    func testRepliesDecodePage() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"r-1","content":"已处理","createdAt":"2099-11-20T04:00:00Z"}],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteFeedbackService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.replies(id: "fb-1", page: 1, size: 20)

        XCTAssertEqual(page.items.first?.content, "已处理")
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/v1/users/me/feedback/fb-1/replies")
    }
}
