import Foundation

protocol HistoryService: AnyObject {
    func settings() async throws -> BrowsingHistorySettings
    func updateSettings(enabled: Bool, expectedRevision: Int) async throws -> BrowsingHistorySettings
    func list(kind: HistoryKind, page: Int, size: Int) async throws -> Page<BrowsingHistoryItem>
    func record(
        kind: HistoryKind,
        targetID: String,
        epoch: Int,
        visitEventID: String
    ) async throws
    func deleteOne(kind: HistoryKind, targetID: String) async throws
    func clear(kind: HistoryKind) async throws
}
