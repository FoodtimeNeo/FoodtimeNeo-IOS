import Foundation

protocol CommunityService: AnyObject {
    func feed(
        size: Int,
        cursor: String?,
        following: Bool,
        query: String,
        pinRevision: Int?
    ) async throws -> CommunityFeedPage
    func detail(id: String) async throws -> CommunityPost
    func roots(postID: String, size: Int, cursor: String?) async throws -> CommunityCommentPage
    func replies(
        postID: String,
        rootID: String,
        size: Int,
        cursor: String?
    ) async throws -> CommunityCommentPage
    func submitComment(
        postID: String,
        content: String,
        rootID: String?,
        replyToID: String?,
        requestID: String
    ) async throws -> CommunityComment
    func likePost(id: String, liked: Bool) async throws -> CommunityLikeState
    func favoritePost(id: String, favorited: Bool) async throws -> CommunityLikeState
    func likeComment(id: String, liked: Bool) async throws -> CommunityLikeState
    func recordView(postID: String, requestID: String) async throws -> Int
    func createPost(
        title: String,
        content: String,
        imageURLs: [String],
        requestID: String
    ) async throws -> CommunityPostReceipt
    func myPosts(page: Int, size: Int) async throws -> Page<CommunityPost>
    func author(id: String) async throws -> CommunityAuthor
    func authorPosts(
        authorID: String,
        size: Int,
        cursor: String?
    ) async throws -> CommunityFeedPage
    func editPost(
        id: String,
        expectedRevision: Int,
        title: String,
        content: String,
        imageURLs: [String],
        requestID: String
    ) async throws -> CommunityEditReceipt
    func pins(manage: Bool) async throws -> CommunityPinSnapshot
    func pin(postID: String, expectedRevision: Int) async throws -> CommunityPinSnapshot
    func unpin(postID: String, expectedRevision: Int) async throws -> CommunityPinSnapshot
    func reorderPins(postIDs: [String], expectedRevision: Int) async throws -> CommunityPinSnapshot
}
