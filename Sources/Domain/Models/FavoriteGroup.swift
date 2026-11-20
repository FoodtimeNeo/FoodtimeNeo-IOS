import Foundation

enum FavoriteKind: String, CaseIterable, Identifiable, Hashable, Sendable {
    case dish
    case post

    var id: String { rawValue }
    var label: String { self == .dish ? "菜品" : "帖子" }
}

struct FavoriteGroup: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let kind: String
    let name: String
    let sortOrder: Int
    let revision: Int
    let itemCount: Int
}

struct FavoriteMembership: Codable, Equatable, Sendable {
    let groupIds: [String]
}

struct FavoriteSaveState: Codable, Equatable, Sendable {
    let saved: Bool
}
