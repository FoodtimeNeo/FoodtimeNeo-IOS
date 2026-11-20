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
}
