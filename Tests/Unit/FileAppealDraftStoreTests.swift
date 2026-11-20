import XCTest
@testable import FoodtimeNeo

final class FileAppealDraftStoreTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("foodtime-appeal-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root {
            try? FileManager.default.removeItem(at: root)
        }
    }

    func testSaveLoadAndClear() throws {
        let store = FileAppealDraftStore(
            origin: URL(string: "https://example.test/api/v1/")!,
            accountID: "account-1",
            rootDirectory: root
        )

        store.save(
            AppealDraft(content: "请复核处理结果", evidence: [Data([1, 2, 3])]),
            decisionID: "decision-1"
        )
        let loaded = try XCTUnwrap(store.load(decisionID: "decision-1"))

        XCTAssertEqual(loaded.content, "请复核处理结果")
        XCTAssertEqual(loaded.evidence, [Data([1, 2, 3])])

        store.clear(decisionID: "decision-1")
        XCTAssertNil(store.load(decisionID: "decision-1"))
    }

    func testAccountAndOriginAreIsolated() {
        let originA = URL(string: "https://a.example/api/v1/")!
        let originB = URL(string: "https://b.example/api/v1/")!
        let first = FileAppealDraftStore(origin: originA, accountID: "a-1", rootDirectory: root)
        let second = FileAppealDraftStore(origin: originA, accountID: "a-2", rootDirectory: root)
        let otherOrigin = FileAppealDraftStore(origin: originB, accountID: "a-1", rootDirectory: root)

        first.save(AppealDraft(content: "账号一的草稿", evidence: []), decisionID: "d-1")

        XCTAssertNil(second.load(decisionID: "d-1"))
        XCTAssertNil(otherOrigin.load(decisionID: "d-1"))
        XCTAssertEqual(first.load(decisionID: "d-1")?.content, "账号一的草稿")
    }

    func testEmptyDraftIsNotRestored() {
        let store = FileAppealDraftStore(
            origin: URL(string: "https://example.test/api/v1/")!,
            accountID: "account-1",
            rootDirectory: root
        )

        store.save(AppealDraft(content: "", evidence: []), decisionID: "d-1")

        XCTAssertNil(store.load(decisionID: "d-1"))
    }
}
