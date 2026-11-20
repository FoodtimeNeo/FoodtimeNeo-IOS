import Foundation

final class RemoteFavoriteService: FavoriteService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func groups(kind: FavoriteKind) async throws -> [FavoriteGroup] {
        try await api.send(
            .get("users/me/favorite-groups", query: [URLQueryItem(name: "kind", value: kind.rawValue)]),
            as: [FavoriteGroup].self
        )
    }

    func createGroup(
        kind: FavoriteKind,
        name: String,
        sortOrder: Int?
    ) async throws -> FavoriteGroup {
        struct Body: Encodable {
            let kind: String
            let name: String
            let sortOrder: Int?
        }
        let request = try APIRequest.json(
            .post,
            "users/me/favorite-groups",
            body: Body(kind: kind.rawValue, name: name, sortOrder: sortOrder),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: FavoriteGroup.self)
    }

    func updateGroup(
        id: String,
        name: String?,
        sortOrder: Int?,
        expectedRevision: Int?
    ) async throws -> FavoriteGroup {
        struct Body: Encodable {
            let name: String?
            let sortOrder: Int?
            let expectedRevision: Int?
        }
        let request = try APIRequest.json(
            .put,
            "users/me/favorite-groups/\(encoded(id))",
            body: Body(name: name, sortOrder: sortOrder, expectedRevision: expectedRevision),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: FavoriteGroup.self)
    }

    func deleteGroup(id: String) async throws {
        try await api.sendVoid(.delete("users/me/favorite-groups/\(encoded(id))"))
    }

    func memberships(kind: FavoriteKind, targetID: String) async throws -> [String] {
        let response: FavoriteMembership = try await api.send(
            .get(
                "users/me/favorite-groups/memberships",
                query: [
                    URLQueryItem(name: "kind", value: kind.rawValue),
                    URLQueryItem(name: "targetId", value: targetID)
                ]
            ),
            as: FavoriteMembership.self
        )
        return response.groupIds
    }

    func addMember(groupID: String, targetID: String) async throws -> [String] {
        let response: FavoriteMembership = try await api.send(
            .put("users/me/favorite-groups/\(encoded(groupID))/members/\(encoded(targetID))"),
            as: FavoriteMembership.self
        )
        return response.groupIds
    }

    func removeMember(groupID: String, targetID: String) async throws -> [String] {
        let response: FavoriteMembership = try await api.send(
            .delete("users/me/favorite-groups/\(encoded(groupID))/members/\(encoded(targetID))"),
            as: FavoriteMembership.self
        )
        return response.groupIds
    }

    func dishFavorites(
        groupID: String?,
        unfiled: Bool,
        page: Int,
        size: Int
    ) async throws -> Page<DishSearchRow> {
        try await favoritesPage(
            path: "users/me/dish-favorites",
            groupID: groupID,
            unfiled: unfiled,
            page: page,
            size: size,
            as: Page<DishSearchRow>.self
        )
    }

    func communityFavorites(
        groupID: String?,
        unfiled: Bool,
        page: Int,
        size: Int
    ) async throws -> Page<CommunityPost> {
        try await favoritesPage(
            path: "users/me/community-favorites",
            groupID: groupID,
            unfiled: unfiled,
            page: page,
            size: size,
            as: Page<CommunityPost>.self
        )
    }

    func dishFavoriteState(dishID: String) async throws -> Bool {
        let state: FavoriteSaveState = try await api.send(
            .get("users/me/dish-favorites/\(encoded(dishID))"),
            as: FavoriteSaveState.self
        )
        return state.saved
    }

    func setDishFavorite(dishID: String, favorited: Bool) async throws -> Bool {
        let request = favorited
            ? APIRequest.put("users/me/dish-favorites/\(encoded(dishID))")
            : APIRequest.delete("users/me/dish-favorites/\(encoded(dishID))")
        let state: FavoriteSaveState = try await api.send(request, as: FavoriteSaveState.self)
        return state.saved
    }

    private func favoritesPage<T: Decodable>(
        path: String,
        groupID: String?,
        unfiled: Bool,
        page: Int,
        size: Int,
        as type: T.Type
    ) async throws -> T {
        var query = [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
        if let groupID, !groupID.isEmpty {
            query.append(URLQueryItem(name: "groupId", value: groupID))
        } else if unfiled {
            query.append(URLQueryItem(name: "unfiled", value: "true"))
        }
        return try await api.send(.get(path, query: query), as: type)
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
