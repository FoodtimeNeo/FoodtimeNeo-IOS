import Foundation

protocol FavoriteService: AnyObject {
    func groups(kind: FavoriteKind) async throws -> [FavoriteGroup]
    func createGroup(kind: FavoriteKind, name: String, sortOrder: Int?) async throws -> FavoriteGroup
    func updateGroup(
        id: String,
        name: String?,
        sortOrder: Int?,
        expectedRevision: Int?
    ) async throws -> FavoriteGroup
    func deleteGroup(id: String) async throws
    func memberships(kind: FavoriteKind, targetID: String) async throws -> [String]
    func addMember(groupID: String, targetID: String) async throws -> [String]
    func removeMember(groupID: String, targetID: String) async throws -> [String]

    func dishFavorites(
        groupID: String?,
        unfiled: Bool,
        page: Int,
        size: Int
    ) async throws -> Page<DishSearchRow>
    func communityFavorites(
        groupID: String?,
        unfiled: Bool,
        page: Int,
        size: Int
    ) async throws -> Page<CommunityPost>
    func dishFavoriteState(dishID: String) async throws -> Bool
    func setDishFavorite(dishID: String, favorited: Bool) async throws -> Bool
}
