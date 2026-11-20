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
}
