import Foundation

final class RemoteVenueReviewService: VenueReviewService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func target(type: VenueTargetType, id: String) async throws -> VenueRatingTarget {
        try await api.send(
            .get("\(type.path)/\(encoded(id))/rating"),
            as: VenueRatingTarget.self
        )
    }

    func reviews(
        type: VenueTargetType,
        id: String,
        rating: String,
        cursor: String?,
        size: Int
    ) async throws -> VenueReviewPage {
        let allowed = ["all", "5", "4", "1-3"]
        var query = [
            URLQueryItem(name: "size", value: String(min(100, max(1, size)))),
            URLQueryItem(name: "rating", value: allowed.contains(rating) ? rating : "all")
        ]
        if let cursor, !cursor.isEmpty {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await api.send(
            .get("\(type.path)/\(encoded(id))/reviews", query: query),
            as: VenueReviewPage.self
        )
    }

    func mine(type: VenueTargetType, id: String) async throws -> VenueReviewMine {
        try await api.send(
            .get("\(type.path)/\(encoded(id))/reviews/me"),
            as: VenueReviewMine.self
        )
    }

    func submit(
        type: VenueTargetType,
        id: String,
        rating: Int,
        content: String,
        requestID: String
    ) async throws -> VenueReview {
        struct Body: Encodable {
            let rating: Int
            let content: String
            let clientRequestId: String
        }
        let request = try APIRequest.json(
            .post,
            "\(type.path)/\(encoded(id))/reviews",
            body: Body(rating: rating, content: content, clientRequestId: requestID),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: VenueReview.self)
    }

    func setLike(reviewID: String, liked: Bool) async throws -> ReviewLikeState {
        let request = liked
            ? APIRequest.put("venue-reviews/\(encoded(reviewID))/like")
            : APIRequest.delete("venue-reviews/\(encoded(reviewID))/like")
        return try await api.send(request, as: ReviewLikeState.self)
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
