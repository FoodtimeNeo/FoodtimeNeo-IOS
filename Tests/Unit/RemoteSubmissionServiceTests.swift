import XCTest
@testable import FoodtimeNeo

final class RemoteSubmissionServiceTests: XCTestCase {
    func testUploadBuildsMultipartAndDecodesMedia() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-s1"}
            """)),
            .init(status: 201, body: TestFixtures.envelope("""
            {"id":"media-1","imageUrl":"/api/v1/media/media-1","width":1600,"height":1200}
            """))
        ]
        let service = RemoteSubmissionService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

        let uploaded = try await service.uploadImage(jpeg)

        XCTAssertEqual(uploaded.imageUrl, "/api/v1/media/media-1")
        let request = transport.requests[1]
        XCTAssertEqual(request.url?.path, "/api/v1/uploads/images")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") ?? false)
        let body = try XCTUnwrap(request.httpBody)
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.contains("name=\"file\"; filename=\"photo.jpg\""))
        XCTAssertTrue(text.contains("Content-Type: image/jpeg"))
        XCTAssertEqual(transport.requests[1].value(forHTTPHeaderField: "X-CSRF-TOKEN"), "token-s1")
    }

    func testSubmitDishImageSendsReference() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-s2"}
            """)),
            .init(status: 201, body: TestFixtures.envelope("""
            {"id":"is-1","dishId":"d-1","dishName":"鸡腿饭","stallId":"s-1","stallName":"三号档口","diningHallId":"h-1","diningHallName":"学苑食堂","imageUrl":"/api/v1/media/media-1","status":"pending","reviewedAt":null,"reviewReason":null,"createdAt":"2099-11-21T04:00:00Z"}
            """))
        ]
        let service = RemoteSubmissionService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let submission = try await service.submitDishImage(
            dishID: "d-1",
            imageURL: "/api/v1/media/media-1"
        )

        XCTAssertEqual(submission.status, "pending")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["imageUrl"] as? String, "/api/v1/media/media-1")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/dishes/d-1/image-submissions")
    }

    func testMyImageSubmissionsDecode() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[],"total":0,"page":1,"size":20}
            """))
        ]
        let service = RemoteSubmissionService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.myImageSubmissions(page: 1, size: 20)

        XCTAssertEqual(page.total, 0)
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/v1/users/me/image-submissions")
    }
}
