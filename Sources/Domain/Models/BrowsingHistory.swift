import Foundation

enum HistoryKind: String, CaseIterable, Identifiable, Hashable, Sendable {
    case dish
    case post

    var id: String { rawValue }
    var label: String { self == .dish ? "菜品" : "帖子" }
}

struct BrowsingHistorySettings: Codable, Equatable, Sendable {
    let enabled: Bool
    let revision: Int
    let dishEpoch: Int
    let postEpoch: Int

    func epoch(for kind: HistoryKind) -> Int {
        kind == .dish ? dishEpoch : postEpoch
    }
}

struct BrowsingHistoryItem: Codable, Identifiable, Equatable, Sendable {
    let kind: String
    let targetId: String
    let diningHallId: String?
    let stallId: String?
    let visitedAt: Date?
    let available: Bool
    let title: String?
    let subtitle: String?
    let imageUrl: String?

    var id: String { "\(kind)-\(targetId)" }
}

struct HistoryRecordReceipt: Equatable, Sendable {
    let recorded: Bool
}
