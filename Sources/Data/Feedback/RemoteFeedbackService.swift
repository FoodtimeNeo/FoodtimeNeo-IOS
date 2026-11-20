import Foundation

final class RemoteFeedbackService: FeedbackService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func create(type: FeedbackType, content: String, requestID: String) async throws -> Feedback {
        struct Body: Encodable {
            let type: String
            let content: String
            let clientRequestId: String
        }
        let request = try APIRequest.json(
            .post,
            "users/me/feedback",
            body: Body(type: type.rawValue, content: content, clientRequestId: requestID),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: Feedback.self)
    }

    func list(archived: Bool, page: Int, size: Int) async throws -> Page<Feedback> {
        try await api.send(
            .get(
                "users/me/feedback",
                query: [
                    URLQueryItem(name: "archived", value: archived ? "true" : "false"),
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(size))
                ]
            ),
            as: Page<Feedback>.self
        )
    }

    func detail(id: String) async throws -> Feedback {
        try await api.send(
            .get("users/me/feedback/\(encoded(id))"),
            as: Feedback.self
        )
    }

    func replies(id: String, page: Int, size: Int) async throws -> Page<FeedbackReply> {
        try await api.send(
            .get(
                "users/me/feedback/\(encoded(id))/replies",
                query: [
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(size))
                ]
            ),
            as: Page<FeedbackReply>.self
        )
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
