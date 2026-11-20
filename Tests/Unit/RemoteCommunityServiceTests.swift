import XCTest
@testable import FoodtimeNeo

final class RemoteCommunityServiceTests: XCTestCase {
    func testFeedSendsFiltersAndDecodes() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"post-1","userId":"u-1","userDisplayName":"干饭人","title":"今天吃什么","content":"食堂新菜","imageUrls":[],"images":[],"likeCount":1,"commentCount":0,"repostCount":0,"repostOfId":null,"repost":null,"likedByMe":false,"favoritedByMe":false,"favoriteCount":0,"status":"approved","reviewReason":null,"createdAt":"2099-11-21T04:00:00Z","editedAt":null,"viewCount":3,"contentRevision":1,"userAvatarUrl":null,"linkedDish":null}],"total":1,"hasMore":false,"nextCursor":null,"pins":null}
            """))
        ]
        let service = RemoteCommunityService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.feed(size: 20, cursor: nil, following: true, query: "面", pinRevision: 2)

        XCTAssertEqual(page.items.first?.title, "今天吃什么")
        let url = try XCTUnwrap(transport.requests.first?.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "following" })?.value, "true")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "q" })?.value, "面")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "pinRevision" })?.value, "2")
        XCTAssertEqual(url.path, "/api/v1/community/feed/cursor")
    }

    func testCommentsSubmitAndLike() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"c-1","postId":"post-1","userId":"u-1","userDisplayName":"干饭人","content":"不错","likeCount":0,"status":"approved","createdAt":"2099-11-21T04:00:00Z","rootCommentId":null,"replyToCommentId":null,"replyToUserId":null,"replyToDisplayName":null,"replyCount":0,"likedByMe":false,"deleted":false,"userAvatarUrl":null}],"total":1,"hasMore":false,"nextCursor":null}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-c1"}
            """)),
            .init(status: 202, body: TestFixtures.envelope("""
            {"id":"c-2","postId":"post-1","userId":"u-1","userDisplayName":"干饭人","content":"新评论","likeCount":0,"status":"pending","createdAt":"2099-11-21T04:00:00Z","rootCommentId":null,"replyToCommentId":null,"replyToUserId":null,"replyToDisplayName":null,"replyCount":0,"likedByMe":false,"deleted":false,"userAvatarUrl":null}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"likedByMe":true,"likeCount":1,"counterVersion":1}
            """))
        ]
        let service = RemoteCommunityService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.roots(postID: "post-1", size: 20, cursor: nil)
        let comment = try await service.submitComment(
            postID: "post-1",
            content: "新评论",
            rootID: nil,
            replyToID: nil,
            requestID: "request-c1"
        )
        let like = try await service.likeComment(id: "c-2", liked: true)

        XCTAssertEqual(page.items.first?.content, "不错")
        XCTAssertEqual(comment.status, "pending")
        XCTAssertTrue(like.likedByMe ?? false)
        let body = try XCTUnwrap(transport.requests[2].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["content"] as? String, "新评论")
        XCTAssertEqual(json["clientRequestId"] as? String, "request-c1")
        XCTAssertEqual(transport.requests[2].url?.path, "/api/v1/community/posts/post-1/comments")
        XCTAssertEqual(transport.requests[3].httpMethod, "PUT")
        XCTAssertEqual(transport.requests[3].url?.path, "/api/v1/community/comments/c-2/like")
    }

    func testRepliesAndNestedCommentBody() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"c-2","postId":"post-1","userId":"u-1","userDisplayName":"干饭人","content":"楼内回复","likeCount":0,"status":"approved","createdAt":"2099-11-21T04:00:00Z","rootCommentId":"c-1","replyToCommentId":null,"replyToUserId":null,"replyToDisplayName":null,"replyCount":0,"likedByMe":false,"deleted":false,"userAvatarUrl":null}],"total":1,"hasMore":false,"nextCursor":null}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-c4"}
            """)),
            .init(status: 202, body: TestFixtures.envelope("""
            {"id":"c-3","postId":"post-1","userId":"u-1","userDisplayName":"干饭人","content":"回复","likeCount":0,"status":"pending","createdAt":"2099-11-21T04:00:00Z","rootCommentId":"c-1","replyToCommentId":"c-2","replyToUserId":"u-2","replyToDisplayName":"另一位","replyCount":0,"likedByMe":false,"deleted":false,"userAvatarUrl":null}
            """))
        ]
        let service = RemoteCommunityService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.replies(postID: "post-1", rootID: "c-1", size: 20, cursor: nil)
        let created = try await service.submitComment(
            postID: "post-1",
            content: "回复",
            rootID: "c-1",
            replyToID: "c-2",
            requestID: "request-c2"
        )

        XCTAssertEqual(page.items.first?.content, "楼内回复")
        XCTAssertEqual(created.status, "pending")
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/community/posts/post-1/comments/c-1/replies")
        let body = try XCTUnwrap(transport.requests[2].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["rootCommentId"] as? String, "c-1")
        XCTAssertEqual(json["replyToCommentId"] as? String, "c-2")
        XCTAssertEqual(json["clientRequestId"] as? String, "request-c2")
    }

    func testCreatePostSendsImagesAndRequestID() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-c3"}
            """)),
            .init(status: 202, body: TestFixtures.envelope("""
            {"id":"post-2"}
            """))
        ]
        let service = RemoteCommunityService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let receipt = try await service.createPost(
            title: "标题",
            content: "正文",
            imageURLs: ["/api/v1/media/media-1"],
            requestID: "request-post-1"
        )

        XCTAssertEqual(receipt.id, "post-2")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["title"] as? String, "标题")
        XCTAssertEqual(json["content"] as? String, "正文")
        XCTAssertEqual(json["imageUrls"] as? [String], ["/api/v1/media/media-1"])
        XCTAssertEqual(json["clientRequestId"] as? String, "request-post-1")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/community/posts")
    }

    func testPostLikeFavoriteAndView() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-c2"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"likedByMe":true,"likeCount":2}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"favoritedByMe":true,"favoriteCount":1}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"viewCount":4}
            """))
        ]
        let service = RemoteCommunityService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let like = try await service.likePost(id: "post-1", liked: true)
        let favorite = try await service.favoritePost(id: "post-1", favorited: true)
        let views = try await service.recordView(postID: "post-1", requestID: "view-1")

        XCTAssertTrue(like.likedByMe ?? false)
        XCTAssertTrue(favorite.favoritedByMe ?? false)
        XCTAssertEqual(views, 4)
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/community/posts/post-1/like")
        XCTAssertEqual(transport.requests[2].url?.path, "/api/v1/community/posts/post-1/favorite")
        XCTAssertEqual(transport.requests[3].url?.path, "/api/v1/community/posts/post-1/views")
    }
}
