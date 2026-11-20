import Foundation

protocol VenueReviewService: AnyObject {
    func target(type: VenueTargetType, id: String) async throws -> VenueRatingTarget
    func reviews(
        type: VenueTargetType,
        id: String,
        rating: String,
        cursor: String?,
        size: Int
    ) async throws -> VenueReviewPage
    func mine(type: VenueTargetType, id: String) async throws -> VenueReviewMine
    func submit(
        type: VenueTargetType,
        id: String,
        rating: Int,
        content: String,
        requestID: String
    ) async throws -> VenueReview
    func setLike(reviewID: String, liked: Bool) async throws -> ReviewLikeState
    func myReviews(page: Int, size: Int, type: String?) async throws -> Page<VenueReview>
}
