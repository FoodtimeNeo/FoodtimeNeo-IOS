import XCTest
@testable import FoodtimeNeo

final class CommunityDraftStoreTests: XCTestCase {
    func testSaveLoadImagesAndClearPerAccount() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("community-draft-tests-\(UUID().uuidString)", isDirectory: true)
        let store = FileCommunityDraftStore(baseDirectory: base)
        defer { try? FileManager.default.removeItem(at: base) }

        let image = try XCTUnwrap(store.saveImage(Data([1, 2, 3]), accountID: "user-a"))
        let draft = CommunityDraft(
            title: "标题",
            content: "正文",
            imageFiles: [image],
            updatedAt: Date()
        )
        store.save(draft, accountID: "user-a")

        XCTAssertEqual(store.load(accountID: "user-a")?.title, "标题")
        XCTAssertEqual(store.imageData(named: image, accountID: "user-a"), Data([1, 2, 3]))
        XCTAssertNil(store.load(accountID: "user-b"))

        store.clear(accountID: "user-a")
        XCTAssertNil(store.load(accountID: "user-a"))
        XCTAssertNil(store.imageData(named: image, accountID: "user-a"))
    }

    func testMemoryStoreClearsOnlyAccount() {
        let store = MemoryDraftStore()
        let draft = CommunityDraft(title: "a", content: "b", imageFiles: [], updatedAt: nil)
        store.save(draft, accountID: "a")
        store.save(draft, accountID: "b")

        store.clear(accountID: "a")

        XCTAssertNil(store.load(accountID: "a"))
        XCTAssertNotNil(store.load(accountID: "b"))
    }
}
