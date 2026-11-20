import Foundation

final class RemoteReviewService: ReviewService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func reviews(dishID: String, page: Int, size: Int) async throws -> Page<Review> {
        try await api.send(
            .get(
                "dishes/\(encoded(dishID))/reviews",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<Review>.self
        )
    }

    func submitReview(
        dishID: String,
        rating: Int,
        content: String
    ) async throws -> ReviewCreatedReceipt {
        struct Body: Encodable {
            let rating: Int
            let content: String
        }
        let request = try APIRequest.json(
            .post,
            "dishes/\(encoded(dishID))/reviews",
            body: Body(rating: rating, content: content),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: ReviewCreatedReceipt.self)
    }

    func myReviews(page: Int, size: Int) async throws -> Page<Review> {
        try await api.send(
            .get(
                "users/me/reviews",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<Review>.self
        )
    }

    func myReviewSubmissions(page: Int, size: Int) async throws -> Page<ReviewSubmission> {
        try await api.send(
            .get(
                "users/me/review-submissions",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<ReviewSubmission>.self
        )
    }

    func deleteMyReview(id: String) async throws {
        try await api.sendVoid(.delete("users/me/reviews/\(encoded(id))"))
    }

    func setReviewLike(id: String, liked: Bool) async throws -> ReviewLikeState {
        let request = liked
            ? APIRequest.put("reviews/\(encoded(id))/like")
            : APIRequest.delete("reviews/\(encoded(id))/like")
        return try await api.send(request, as: ReviewLikeState.self)
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
