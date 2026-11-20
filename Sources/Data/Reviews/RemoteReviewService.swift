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

    func replies(
        reviewID: String,
        size: Int,
        cursor: String?
    ) async throws -> ReviewReplyPage {
        var query = [URLQueryItem(name: "size", value: String(min(100, max(1, size))))]
        if let cursor, !cursor.isEmpty {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await api.send(
            .get("reviews/\(encoded(reviewID))/replies", query: query),
            as: ReviewReplyPage.self
        )
    }

    func submitReply(
        reviewID: String,
        content: String,
        replyToID: String?,
        requestID: String
    ) async throws -> ReviewReplyCreatedReceipt {
        struct Body: Encodable {
            let content: String
            let replyToId: String?
            let clientRequestId: String
        }
        let request = try APIRequest.json(
            .post,
            "reviews/\(encoded(reviewID))/replies",
            body: Body(
                content: content,
                replyToId: replyToID?.isEmpty == true ? nil : replyToID,
                clientRequestId: requestID
            ),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: ReviewReplyCreatedReceipt.self)
    }

    func myReplies(page: Int, size: Int) async throws -> Page<ReviewReply> {
        try await api.send(
            .get(
                "users/me/review-replies",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<ReviewReply>.self
        )
    }

    func deleteReply(id: String) async throws {
        try await api.sendVoid(.delete("review-replies/\(encoded(id))"))
    }

    func setReplyLike(id: String, liked: Bool) async throws -> ReviewLikeState {
        let request = liked
            ? APIRequest.put("review-replies/\(encoded(id))/like")
            : APIRequest.delete("review-replies/\(encoded(id))/like")
        return try await api.send(request, as: ReviewLikeState.self)
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
