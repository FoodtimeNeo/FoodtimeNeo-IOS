import Foundation

final class RemoteSocialService: SocialService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func searchUsers(query: String, page: Int, size: Int) async throws -> Page<SocialUser> {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await api.send(
            .get(
                "users/search",
                query: [
                    URLQueryItem(name: "q", value: q),
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(size))
                ]
            ),
            as: Page<SocialUser>.self
        )
    }

    func following(userID: String, page: Int, size: Int) async throws -> Page<SocialUser> {
        try await list(path: "users/\(encoded(userID))/following", page: page, size: size)
    }

    func followers(userID: String, page: Int, size: Int) async throws -> Page<SocialUser> {
        try await list(path: "users/\(encoded(userID))/followers", page: page, size: size)
    }

    func follow(userID: String) async throws -> FollowState {
        try await api.send(.put("users/\(encoded(userID))/follow"), as: FollowState.self)
    }

    func unfollow(userID: String) async throws -> FollowState {
        try await api.send(.delete("users/\(encoded(userID))/follow"), as: FollowState.self)
    }

    func blockedUsers(page: Int, size: Int) async throws -> Page<BlockedUser> {
        try await api.send(
            .get(
                "users/me/blocks",
                query: [
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(size))
                ]
            ),
            as: Page<BlockedUser>.self
        )
    }

    func block(userID: String) async throws -> BlockState {
        try await api.send(.put("users/\(encoded(userID))/block"), as: BlockState.self)
    }

    func unblock(userID: String) async throws -> BlockState {
        try await api.send(.delete("users/\(encoded(userID))/block"), as: BlockState.self)
    }

    private func list(path: String, page: Int, size: Int) async throws -> Page<SocialUser> {
        try await api.send(
            .get(
                path,
                query: [
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(size))
                ]
            ),
            as: Page<SocialUser>.self
        )
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
