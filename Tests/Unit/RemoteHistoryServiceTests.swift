import XCTest
@testable import FoodtimeNeo

final class RemoteHistoryServiceTests: XCTestCase {
    func testSettingsListAndRecord() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"enabled":true,"revision":1,"dishEpoch":2,"postEpoch":3}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"kind":"dish","targetId":"d-1","diningHallId":"h-1","stallId":"s-1","visitedAt":"2099-11-21T04:00:00Z","available":true,"title":"鸡腿饭","subtitle":"学苑食堂 · 三号档口","imageUrl":null}],"total":1,"page":1,"size":50}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-h1"}
            """)),
            .init(status: 204, body: "")
        ]
        let service = RemoteHistoryService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let settings = try await service.settings()
        let page = try await service.list(kind: .dish, page: 1, size: 50)
        try await service.record(
            kind: .dish,
            targetID: "d-1",
            epoch: settings.dishEpoch,
            visitEventID: "visit-1"
        )

        XCTAssertEqual(settings.dishEpoch, 2)
        XCTAssertEqual(page.items.first?.title, "鸡腿饭")
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/users/me/browsing-history/settings")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/users/me/browsing-history")
        XCTAssertEqual(transport.requests[3].httpMethod, "PUT")
        XCTAssertEqual(transport.requests[3].url?.path, "/api/v1/users/me/browsing-history/dish/d-1")
        let body = try XCTUnwrap(transport.requests[3].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["epoch"] as? Int, 2)
        XCTAssertEqual(json["visitEventId"] as? String, "visit-1")
    }

    func testUpdateSettingsDeleteAndClear() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-h2"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"enabled":false,"revision":2,"dishEpoch":3,"postEpoch":4}
            """)),
            .init(status: 204, body: ""),
            .init(status: 204, body: "")
        ]
        let service = RemoteHistoryService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let settings = try await service.updateSettings(enabled: false, expectedRevision: 1)
        try await service.deleteOne(kind: .dish, targetID: "d-1")
        try await service.clear(kind: .post)

        XCTAssertFalse(settings.enabled)
        XCTAssertEqual(transport.requests[1].httpMethod, "PUT")
        XCTAssertEqual(transport.requests[2].httpMethod, "DELETE")
        XCTAssertEqual(transport.requests[3].httpMethod, "DELETE")
        let clearURL = try XCTUnwrap(transport.requests[3].url)
        XCTAssertEqual(
            URLComponents(url: clearURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "kind" })?.value,
            "post"
        )
    }
}
