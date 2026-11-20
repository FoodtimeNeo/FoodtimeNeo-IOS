import Foundation

/// Ordinary page protocol: `items / total / page / size`.
struct Page<Item: Sendable>: Sendable {
    let items: [Item]
    let total: Int
    let page: Int
    let size: Int
}

/// Cursor protocol: `items / nextCursor / hasMore`. Do not mix it with `Page`.
struct CursorPage<Item: Sendable>: Sendable {
    let items: [Item]
    let nextCursor: String?
    let hasMore: Bool
}
