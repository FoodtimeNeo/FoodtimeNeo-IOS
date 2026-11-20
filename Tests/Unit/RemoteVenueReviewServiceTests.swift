import XCTest
@testable import FoodtimeNeo

final class RemoteVenueReviewServiceTests: XCTestCase {
    func testTargetAndListDecode() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"type":"hall","targetId":"h-1","name":"学苑食堂","diningHallId":"h-1","stallId":null,"averageScore":4.5,"reviewCount":2}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"vr-1","reviewId":"vr-1","submissionId":null,"userId":"u-1","userDisplayName":"干饭人","targetType":"hall","targetId":"h-1","name":"学苑食堂","rating":5,"content":"环境不错","status":"approved","reviewReason":null,"createdAt":"2099-11-21T04:00:00Z","updatedAt":"2099-11-21T04:00:00Z","ownedByMe":false,"likedByMe":false,"likeCount":0,"counterVersion":1,"replyCount":0}],"total":1,"hasMore":false,"nextCursor":null}
            """))
        ]
        let service = RemoteVenueReviewService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let target = try await service.target(type: .hall, id: "h-1")
        let page = try await service.reviews(type: .hall, id: "h-1", rating: "5", cursor: nil, size: 20)

        XCTAssertEqual(target.name, "学苑食堂")
        XCTAssertEqual(page.items.first?.content, "环境不错")
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/dining-halls/h-1/rating")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/dining-halls/h-1/reviews")
        let query = URLComponents(url: try XCTUnwrap(transport.requests[1].url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(query?.first(where: { $0.name == "rating" })?.value, "5")
    }

    func testSubmitAndLike() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-v1"}
            """)),
            .init(status: 202, body: TestFixtures.envelope("""
            {"id":"vr-2","reviewId":"vr-2","submissionId":"s-2","userId":"u-1","userDisplayName":"干饭人","targetType":"stall","targetId":"s-1","name":"三号档口","rating":4,"content":"不错","status":"pending","reviewReason":null,"createdAt":"2099-11-21T04:00:00Z","updatedAt":"2099-11-21T04:00:00Z","ownedByMe":true,"likedByMe":false,"likeCount":0,"counterVersion":1,"replyCount":0}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"likedByMe":true,"likeCount":1,"counterVersion":2}
            """))
        ]
        let service = RemoteVenueReviewService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let review = try await service.submit(
            type: .stall,
            id: "s-1",
            rating: 4,
            content: "不错",
            requestID: "request-v1"
        )
        let like = try await service.setLike(reviewID: "vr-2", liked: true)

        XCTAssertEqual(review.status, "pending")
        XCTAssertTrue(like.likedByMe)
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["rating"] as? Int, 4)
        XCTAssertEqual(json["clientRequestId"] as? String, "request-v1")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/stalls/s-1/reviews")
        XCTAssertEqual(transport.requests[2].url?.path, "/api/v1/venue-reviews/vr-2/like")
    }
}
