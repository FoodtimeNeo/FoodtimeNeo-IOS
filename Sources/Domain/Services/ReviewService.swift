import Foundation

protocol ReviewService: AnyObject {
    func reviews(dishID: String, page: Int, size: Int) async throws -> Page<Review>
    func submitReview(dishID: String, rating: Int, content: String) async throws -> ReviewCreatedReceipt
    func myReviews(page: Int, size: Int) async throws -> Page<Review>
    func myReviewSubmissions(page: Int, size: Int) async throws -> Page<ReviewSubmission>
    func deleteMyReview(id: String) async throws
    func setReviewLike(id: String, liked: Bool) async throws -> ReviewLikeState

    func replies(reviewID: String, size: Int, cursor: String?) async throws -> ReviewReplyPage
    func submitReply(
        reviewID: String,
        content: String,
        replyToID: String?,
        requestID: String
    ) async throws -> ReviewReplyCreatedReceipt
    func myReplies(page: Int, size: Int) async throws -> Page<ReviewReply>
    func deleteReply(id: String) async throws
    func setReplyLike(id: String, liked: Bool) async throws -> ReviewLikeState
}
