import XCTest
@testable import FoodtimeNeo

final class RemoteAvatarServiceTests: XCTestCase {
    func testUploadsMultipartToAvatarEndpoint() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-avatar"}
            """)),
            .init(status: 201, body: TestFixtures.envelope("""
            {"id":"media-1","imageUrl":"/api/v1/media/11111111-1111-1111-1111-111111111111","width":512,"height":512}
            """))
        ]
        let service = RemoteAvatarService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let uploaded = try await service.uploadAvatar(Data([0xFF, 0xD8, 0xFF, 0xD9]))

        XCTAssertEqual(uploaded.width, 512)
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/uploads/avatars")
        XCTAssertEqual(transport.requests[1].httpMethod, "POST")
        XCTAssertTrue(
            transport.requests[1].value(forHTTPHeaderField: "Content-Type")?
                .hasPrefix("multipart/form-data; boundary=") == true
        )
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        XCTAssertTrue(String(decoding: body, as: UTF8.self).contains("avatar.jpg"))
    }

    func testRejectsNonMediaReference() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-avatar"}
            """)),
            .init(status: 201, body: TestFixtures.envelope("""
            {"id":"media-1","imageUrl":"https://evil.test/a.jpg","width":512,"height":512}
            """))
        ]
        let service = RemoteAvatarService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        do {
            _ = try await service.uploadAvatar(Data([1]))
            XCTFail("expected invalid response")
        } catch {
            guard case AppError.invalidResponse = error else {
                XCTFail("unexpected error \(error)")
                return
            }
        }
    }
}
