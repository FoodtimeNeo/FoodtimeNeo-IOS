import XCTest
@testable import FoodtimeNeo

final class CommunityAuthorServiceTests: XCTestCase {
    func testAuthorProfileAndPostsPaths() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"u-2","displayName":"饭搭子","avatarUrl":null}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[\(AuthorFixtures.postJSON)],"total":1,"hasMore":false,"nextCursor":null}
            """))
        ]
        let service = RemoteCommunityService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let author = try await service.author(id: "u-2")
        let page = try await service.authorPosts(authorID: "u-2", size: 20, cursor: "c-1")

        XCTAssertEqual(author.displayName, "饭搭子")
        XCTAssertEqual(page.items.first?.title, "作者食记")
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/community/authors/u-2")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/community/authors/u-2/posts")
        let components = try XCTUnwrap(
            URLComponents(url: transport.requests[1].url!, resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "cursor" })?.value, "c-1")
    }
}

@MainActor
final class AuthorPostsViewModelTests: XCTestCase {
    func testLoadAndPaging() async {
        let service = FakeCommunityService()
        service.authorResult = CommunityAuthor(id: "u-2", displayName: "饭搭子", avatarUrl: nil)
        service.authorPostsResult = CommunityFeedPage(
            items: [AuthorFixtures.samplePost],
            total: 2,
            hasMore: true,
            nextCursor: "c-1"
        )
        let model = AuthorPostsViewModel(authorID: "u-2", service: service)

        await model.load()
        XCTAssertEqual(model.author?.displayName, "饭搭子")
        XCTAssertEqual(model.posts.count, 1)
        XCTAssertTrue(model.hasMore)

        service.authorPostsResult = CommunityFeedPage(
            items: [AuthorFixtures.post(id: "post-2")],
            total: 2,
            hasMore: false,
            nextCursor: nil
        )
        await model.loadMore()
        XCTAssertEqual(model.posts.count, 2)
        XCTAssertFalse(model.hasMore)
    }
}

enum AuthorFixtures {
    static let samplePost = CommunityPost(
        id: "post-1",
        userId: "u-2",
        userDisplayName: "饭搭子",
        title: "作者食记",
        content: "今天吃了面",
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
        status: "approved",
        reviewReason: nil,
        createdAt: Date(),
        editedAt: nil,
        viewCount: 0,
        contentRevision: 1,
        userAvatarUrl: nil,
        linkedDish: nil
    )

    static func post(id: String) -> CommunityPost {
        CommunityPost(
            id: id,
            userId: samplePost.userId,
            userDisplayName: samplePost.userDisplayName,
            title: "作者食记",
            content: "今天吃了面",
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
            status: "approved",
            reviewReason: nil,
            createdAt: Date(),
            editedAt: nil,
            viewCount: 0,
            contentRevision: 1,
            userAvatarUrl: nil,
            linkedDish: nil
        )
    }

    static let postJSON = """
    {"id":"post-1","userId":"u-2","userDisplayName":"饭搭子","title":"作者食记","content":"今天吃了面","imageUrls":[],"images":[],"likeCount":0,"commentCount":0,"repostCount":0,"repostOfId":null,"repost":null,"likedByMe":false,"favoritedByMe":false,"favoriteCount":0,"status":"approved","reviewReason":null,"createdAt":"2099-11-21T04:00:00Z","editedAt":null,"viewCount":0,"contentRevision":1,"userAvatarUrl":null,"linkedDish":null}
    """
}
