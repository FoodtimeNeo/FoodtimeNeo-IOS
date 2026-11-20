import XCTest
@testable import FoodtimeNeo

final class RemoteReviewServiceTests: XCTestCase {
    func testReviewsDecodeInteractivePage() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"rv-1","dishId":"d-1","userId":"u-1","userDisplayName":"干饭人","rating":5,"content":"好吃","createdAt":"2099-11-21T04:00:00Z","updatedAt":"2099-11-21T04:00:00Z","dishName":"鸡腿饭","stallId":"s-1","stallName":"三号档口","diningHallId":"h-1","diningHallName":"学苑食堂","likeCount":2,"replyCount":1,"likedByMe":false,"counterVersion":3}],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteReviewService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.reviews(dishID: "d-1", page: 1, size: 20)

        XCTAssertEqual(page.items.first?.content, "好吃")
        XCTAssertEqual(page.items.first?.likeCount, 2)
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/v1/dishes/d-1/reviews")
    }

    func testSubmitReviewSendsRatingAndContent() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-r1"}
            """)),
            .init(status: 202, body: TestFixtures.envelope("""
            {"id":"sub-1","dishId":"d-1","rating":5,"content":"好吃","status":"pending","submittedAt":"2099-11-21T04:00:00Z"}
            """))
        ]
        let service = RemoteReviewService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let receipt = try await service.submitReview(dishID: "d-1", rating: 5, content: "好吃")

        XCTAssertEqual(receipt.status, "pending")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["rating"] as? Int, 5)
        XCTAssertEqual(json["content"] as? String, "好吃")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/dishes/d-1/reviews")
    }

    func testLikeUsesPutAndDelete() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-r2"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"likedByMe":true,"likeCount":1,"counterVersion":2}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"likedByMe":false,"likeCount":0,"counterVersion":3}
            """))
        ]
        let service = RemoteReviewService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let liked = try await service.setReviewLike(id: "rv-1", liked: true)
        let unliked = try await service.setReviewLike(id: "rv-1", liked: false)

        XCTAssertTrue(liked.likedByMe)
        XCTAssertFalse(unliked.likedByMe)
        XCTAssertEqual(transport.requests[1].httpMethod, "PUT")
        XCTAssertEqual(transport.requests[2].httpMethod, "DELETE")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/reviews/rv-1/like")
    }

    func testMySubmissionsDecode() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"sub-1","dishId":"d-1","dishName":"鸡腿饭","stallId":"s-1","stallName":"三号档口","diningHallId":"h-1","diningHallName":"学苑食堂","rating":5,"content":"好吃","status":"rejected","submittedAt":"2099-11-21T04:00:00Z","reviewedAt":"2099-11-21T05:00:00Z","reviewReason":"内容过于简单","updatedAt":"2099-11-21T05:00:00Z"}],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteReviewService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.myReviewSubmissions(page: 1, size: 20)

        XCTAssertEqual(page.items.first?.status, "rejected")
        XCTAssertEqual(page.items.first?.statusLabel, "已驳回")
        XCTAssertEqual(page.items.first?.reviewReason, "内容过于简单")
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/v1/users/me/review-submissions")
    }
}
