import Foundation

final class RemoteCommunityService: CommunityService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func feed(
        size: Int,
        cursor: String?,
        following: Bool,
        query: String,
        pinRevision: Int?
    ) async throws -> CommunityFeedPage {
        var items = [
            URLQueryItem(name: "size", value: String(min(100, max(1, size)))),
            URLQueryItem(name: "following", value: following ? "true" : "false"),
            URLQueryItem(name: "q", value: query.trimmingCharacters(in: .whitespacesAndNewlines))
        ]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let pinRevision {
            items.append(URLQueryItem(name: "pinRevision", value: String(pinRevision)))
        }
        return try await api.send(
            .get("community/feed/cursor", query: items),
            as: CommunityFeedPage.self
        )
    }

    func detail(id: String) async throws -> CommunityPost {
        try await api.send(.get("community/posts/\(encoded(id))"), as: CommunityPost.self)
    }

    func roots(postID: String, size: Int, cursor: String?) async throws -> CommunityCommentPage {
        var items = [URLQueryItem(name: "size", value: String(min(100, max(1, size))))]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await api.send(
            .get("community/posts/\(encoded(postID))/comments/cursor", query: items),
            as: CommunityCommentPage.self
        )
    }

    func replies(
        postID: String,
        rootID: String,
        size: Int,
        cursor: String?
    ) async throws -> CommunityCommentPage {
        var items = [URLQueryItem(name: "size", value: String(min(100, max(1, size))))]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await api.send(
            .get(
                "community/posts/\(encoded(postID))/comments/\(encoded(rootID))/replies",
                query: items
            ),
            as: CommunityCommentPage.self
        )
    }

    func submitComment(
        postID: String,
        content: String,
        rootID: String?,
        replyToID: String?,
        requestID: String
    ) async throws -> CommunityComment {
        struct Body: Encodable {
            let content: String
            let clientRequestId: String
            let rootCommentId: String?
            let replyToCommentId: String?
        }
        let request = try APIRequest.json(
            .post,
            "community/posts/\(encoded(postID))/comments",
            body: Body(
                content: content,
                clientRequestId: requestID,
                rootCommentId: rootID,
                replyToCommentId: replyToID
            ),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: CommunityComment.self)
    }

    func likePost(id: String, liked: Bool) async throws -> CommunityLikeState {
        let request = liked
            ? APIRequest.put("community/posts/\(encoded(id))/like")
            : APIRequest.delete("community/posts/\(encoded(id))/like")
        return try await api.send(request, as: CommunityLikeState.self)
    }

    func favoritePost(id: String, favorited: Bool) async throws -> CommunityLikeState {
        let request = favorited
            ? APIRequest.put("community/posts/\(encoded(id))/favorite")
            : APIRequest.delete("community/posts/\(encoded(id))/favorite")
        return try await api.send(request, as: CommunityLikeState.self)
    }

    func likeComment(id: String, liked: Bool) async throws -> CommunityLikeState {
        let request = liked
            ? APIRequest.put("community/comments/\(encoded(id))/like")
            : APIRequest.delete("community/comments/\(encoded(id))/like")
        return try await api.send(request, as: CommunityLikeState.self)
    }

    func recordView(postID: String, requestID: String) async throws -> Int {
        struct Body: Encodable {
            let clientRequestId: String
        }
        let request = try APIRequest.json(
            .post,
            "community/posts/\(encoded(postID))/views",
            body: Body(clientRequestId: requestID),
            requiresAuth: true,
            requiresCSRF: true
        )
        let response: ViewCountResponse = try await api.send(request, as: ViewCountResponse.self)
        return response.viewCount
    }

    func createPost(
        title: String,
        content: String,
        imageURLs: [String],
        requestID: String
    ) async throws -> CommunityPostReceipt {
        struct Body: Encodable {
            let title: String
            let content: String
            let imageUrls: [String]
            let clientRequestId: String
        }
        let request = try APIRequest.json(
            .post,
            "community/posts",
            body: Body(
                title: title,
                content: content,
                imageUrls: imageURLs,
                clientRequestId: requestID
            ),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: CommunityPostReceipt.self)
    }

    func editPost(
        id: String,
        expectedRevision: Int,
        title: String,
        content: String,
        imageURLs: [String],
        requestID: String
    ) async throws -> CommunityEditReceipt {
        struct Body: Encodable {
            let expectedRevision: Int
            let clientRequestId: String
            let title: String
            let content: String
            let imageUrls: [String]
            let dishId: String?
        }
        let request = try APIRequest.json(
            .put,
            "community/posts/\(encoded(id))",
            body: Body(
                expectedRevision: expectedRevision,
                clientRequestId: requestID,
                title: title,
                content: content,
                imageUrls: imageURLs,
                dishId: nil
            ),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: CommunityEditReceipt.self)
    }

    func pins(manage: Bool) async throws -> CommunityPinSnapshot {
        try await api.send(
            .get(manage ? "admin/community/pins" : "community/pins"),
            as: CommunityPinSnapshot.self
        )
    }

    func pin(postID: String, expectedRevision: Int) async throws -> CommunityPinSnapshot {
        struct Body: Encodable {
            let expectedRevision: Int
        }
        let request = try APIRequest.json(
            .put,
            "admin/community/pins/\(encoded(postID))",
            body: Body(expectedRevision: expectedRevision),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: CommunityPinSnapshot.self)
    }

    func unpin(postID: String, expectedRevision: Int) async throws -> CommunityPinSnapshot {
        let request = APIRequest(
            method: .delete,
            path: "admin/community/pins/\(encoded(postID))",
            query: [URLQueryItem(name: "expectedRevision", value: String(expectedRevision))],
            requiresAuth: true,
            requiresCSRF: true,
            contentType: nil
        )
        return try await api.send(request, as: CommunityPinSnapshot.self)
    }

    func reorderPins(postIDs: [String], expectedRevision: Int) async throws -> CommunityPinSnapshot {
        struct Body: Encodable {
            let expectedRevision: Int
            let postIds: [String]
        }
        let request = try APIRequest.json(
            .put,
            "admin/community/pins/order",
            body: Body(expectedRevision: expectedRevision, postIds: postIDs),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: CommunityPinSnapshot.self)
    }

    func myPosts(page: Int, size: Int) async throws -> Page<CommunityPost> {
        try await api.send(
            .get(
                "users/me/community-posts",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<CommunityPost>.self
        )
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}

private struct ViewCountResponse: Decodable {
    let viewCount: Int
}
