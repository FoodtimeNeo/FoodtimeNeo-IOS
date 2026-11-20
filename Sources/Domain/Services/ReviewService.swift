import Foundation

protocol ReviewService: AnyObject {
    func reviews(dishID: String, page: Int, size: Int) async throws -> Page<Review>
    func submitReview(dishID: String, rating: Int, content: String) async throws -> ReviewCreatedReceipt
    func myReviews(page: Int, size: Int) async throws -> Page<Review>
    func myReviewSubmissions(page: Int, size: Int) async throws -> Page<ReviewSubmission>
    func deleteMyReview(id: String) async throws
    func setReviewLike(id: String, liked: Bool) async throws -> ReviewLikeState
}
