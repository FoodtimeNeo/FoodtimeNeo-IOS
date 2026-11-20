import Foundation

struct CommunityDraft: Codable, Equatable, Sendable {
    var title: String
    var content: String
    var imageFiles: [String]
    var updatedAt: Date?

    static let empty = CommunityDraft(title: "", content: "", imageFiles: [], updatedAt: nil)

    var isEmpty: Bool {
        title.isEmpty && content.isEmpty && imageFiles.isEmpty
    }
}

protocol CommunityDraftStore: AnyObject {
    func load(accountID: String) -> CommunityDraft?
    func save(_ draft: CommunityDraft, accountID: String)
    func saveImage(_ data: Data, accountID: String) -> String?
    func imageData(named: String, accountID: String) -> Data?
    func clear(accountID: String)
}
