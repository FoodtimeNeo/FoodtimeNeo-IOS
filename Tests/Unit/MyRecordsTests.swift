import XCTest
@testable import FoodtimeNeo

final class MyRecordsServiceTests: XCTestCase {
    func testMyPostsPathAndPaging() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[\(MyRecordsFixtures.postJSON)],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteCommunityService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.myPosts(page: 1, size: 20)

        XCTAssertEqual(page.items.first?.status, "pending")
        let url = try XCTUnwrap(transport.requests.first?.url)
        XCTAssertEqual(url.path, "/api/v1/users/me/community-posts")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "size" })?.value, "20")
    }

    func testMyVenueReviewsFilterAndPaging() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[\(MyRecordsFixtures.venueJSON)],"total":1,"page":1,"size":20}
            """))
        ]
        let service = RemoteVenueReviewService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.myReviews(page: 1, size: 20, type: "hall")

        XCTAssertEqual(page.items.first?.name, "学苑食堂")
        let url = try XCTUnwrap(transport.requests.first?.url)
        XCTAssertEqual(url.path, "/api/v1/users/me/venue-reviews")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "type" })?.value, "hall")
    }
}

@MainActor
final class MyRecordsViewModelTests: XCTestCase {
    func testMyPostsPaging() async {
        let service = FakeCommunityService()
        let first = (0..<20).map { post(id: "p-\($0)") }
        let second = (20..<23).map { post(id: "p-\($0)") }
        service.myPostsResult = .success(Page(items: first, total: 23, page: 1, size: 20))
        let model = MyCommunityPostsViewModel(service: service)

        await model.load()
        XCTAssertEqual(model.posts.count, 20)
        XCTAssertTrue(model.hasMore)

        service.myPostsResult = .success(Page(items: second, total: 23, page: 2, size: 20))
        await model.loadMore()
        XCTAssertEqual(model.posts.count, 23)
        XCTAssertFalse(model.hasMore)
    }

    func testVenueFilterPassedToService() async {
        let service = FakeVenueReviewService()
        service.myReviewsResult = .success(
            Page(items: [MyRecordsFixtures.venue], total: 1, page: 1, size: 20)
        )
        let model = MyVenueReviewsViewModel(service: service)

        await model.switchFilter(.stall)

        XCTAssertEqual(model.reviews.count, 1)
        XCTAssertEqual(model.filter, .stall)
    }

    private func post(id: String) -> CommunityPost {
        CommunityPost(
            id: id,
            userId: TestFixtures.user.id,
            userDisplayName: TestFixtures.user.displayName,
            title: "食记",
            content: "内容",
            imageUrls: [],
            images: [],
            likeCount: 0,
            commentCount: 0,
            repostCount: 0,
            repostOfId: nil,
            repost: nil,
            likedByMe: false,
            favoritedByMe: false,
            favoriteCount: 0,
            status: "pending",
            reviewReason: nil,
            createdAt: Date(),
            editedAt: nil,
            viewCount: 0,
            contentRevision: 1,
            userAvatarUrl: nil,
            linkedDish: nil
        )
    }
}

enum MyRecordsFixtures {
    static let postJSON = """
    {"id":"p-1","userId":"u-1","userDisplayName":"干饭人","title":"食记","content":"内容","imageUrls":[],"images":[],"likeCount":0,"commentCount":0,"repostCount":0,"repostOfId":null,"repost":null,"likedByMe":false,"favoritedByMe":false,"favoriteCount":0,"status":"pending","reviewReason":"审核中","createdAt":"2099-11-21T04:00:00Z","editedAt":null,"viewCount":0,"contentRevision":1,"userAvatarUrl":null,"linkedDish":null}
    """

    static let venue = VenueReview(
        id: "vr-1",
        reviewId: "vr-1",
        submissionId: nil,
        userId: TestFixtures.user.id,
        userDisplayName: TestFixtures.user.displayName,
        targetType: "hall",
        targetId: "h-1",
        name: "学苑食堂",
        rating: 5,
        content: "环境不错",
        status: "approved",
        reviewReason: nil,
        createdAt: Date(),
        updatedAt: Date(),
        ownedByMe: true,
        likedByMe: false,
        likeCount: 0,
        counterVersion: 1,
        replyCount: 0
    )

    static let venueJSON = """
    {"id":"vr-1","reviewId":"vr-1","submissionId":null,"userId":"u-1","userDisplayName":"干饭人","targetType":"hall","targetId":"h-1","name":"学苑食堂","rating":5,"content":"环境不错","status":"approved","reviewReason":null,"createdAt":"2099-11-21T04:00:00Z","updatedAt":"2099-11-21T04:00:00Z","ownedByMe":true,"likedByMe":false,"likeCount":0,"counterVersion":1,"replyCount":0}
    """
}
