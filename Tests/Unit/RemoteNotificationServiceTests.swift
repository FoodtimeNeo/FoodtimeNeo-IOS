import XCTest
@testable import FoodtimeNeo

final class RemoteNotificationServiceTests: XCTestCase {
    func testPreferencesDecodeCategories() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"category":"message","enabled":true,"revision":1},{"category":"report","enabled":false,"revision":3}]}
            """))
        ]
        let service = RemoteNotificationService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let preferences = try await service.preferences()

        XCTAssertEqual(preferences.items.count, 2)
        XCTAssertEqual(preferences.items.last?.category, "report")
        XCTAssertEqual(preferences.items.last?.revision, 3)
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/v1/users/me/notification-preferences")
    }

    func testUpdateSendsRevisionAndDecodesSavedChoice() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-pref"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"category":"message","enabled":false,"revision":2}
            """))
        ]
        let service = RemoteNotificationService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let saved = try await service.update(category: "message", enabled: false, expectedRevision: 1)

        XCTAssertEqual(saved.enabled, false)
        XCTAssertEqual(saved.revision, 2)
        XCTAssertEqual(
            transport.requests[1].url?.path,
            "/api/v1/users/me/notification-preferences/message"
        )
        XCTAssertEqual(transport.requests[1].httpMethod, "PUT")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["enabled"] as? Bool, false)
        XCTAssertEqual(json["expectedRevision"] as? Int, 1)
    }

    func testUpdateRejectsCategoryMismatch() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-pref"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"category":"notice","enabled":true,"revision":2}
            """))
        ]
        let service = RemoteNotificationService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        do {
            _ = try await service.update(category: "message", enabled: true, expectedRevision: 1)
            XCTFail("expected invalid response")
        } catch {
            guard case AppError.invalidResponse = error else {
                XCTFail("unexpected error \(error)")
                return
            }
        }
    }

    func testEventsUseCursorAndDecodeDeliveryStatus() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"eventId":"11111111-1111-1111-1111-111111111111","seq":12,"category":"report","title":"举报处理有更新","body":"去查看","refType":"report","refId":"22222222-2222-2222-2222-222222222222","refCommentId":null,"refRootCommentId":null,"createdAt":"2099-11-21T04:00:00Z","deliveryStatus":"pending"}],"nextSeq":12}
            """))
        ]
        let service = RemoteNotificationService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.events(afterSeq: 10, limit: 50)

        XCTAssertEqual(page.nextSeq, 12)
        XCTAssertEqual(page.items.first?.category, "report")
        let url = try XCTUnwrap(transport.requests.first?.url)
        XCTAssertEqual(url.path, "/api/v1/users/me/notification-events")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "afterSeq" })?.value, "10")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "limit" })?.value, "50")
    }

    func testDeliveredPostsToEventPath() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-delivered"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let service = RemoteNotificationService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        try await service.markDelivered(eventID: "11111111-1111-1111-1111-111111111111")

        XCTAssertEqual(transport.requests[1].httpMethod, "POST")
        XCTAssertEqual(
            transport.requests[1].url?.path,
            "/api/v1/users/me/notification-events/11111111-1111-1111-1111-111111111111/delivered"
        )
    }
}
