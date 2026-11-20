import XCTest
@testable import FoodtimeNeo

@MainActor
final class MyCorrectionsViewModelTests: XCTestCase {
    func testFirstPageAndLoadMore() async {
        let service = FakeCorrectionService()
        let first = (0..<20).map { correction(id: "cc-\($0)") }
        let second = (20..<25).map { correction(id: "cc-\($0)") }
        service.mineResult = .success(Page(items: first, total: 25, page: 1, size: 20))
        let model = MyCorrectionsViewModel(service: service)

        await model.load()
        XCTAssertEqual(model.items.count, 20)
        XCTAssertTrue(model.hasMore)
        XCTAssertEqual(model.statusText, "共 25 条")

        service.mineResult = .success(Page(items: second, total: 25, page: 2, size: 20))
        await model.loadMore()

        XCTAssertEqual(model.items.count, 25)
        XCTAssertFalse(model.hasMore)
        XCTAssertEqual(model.page, 2)
    }

    func testLoadFailureKeepsItems() async {
        let service = FakeCorrectionService()
        service.mineResult = .success(
            Page(items: [CorrectionFixtures.correction], total: 1, page: 1, size: 20)
        )
        let model = MyCorrectionsViewModel(service: service)
        await model.load()
        XCTAssertEqual(model.items.count, 1)

        service.mineResult = .failure(AppError.network(message: "offline"))
        await model.load()

        XCTAssertEqual(model.items.count, 1)
        XCTAssertNotNil(model.errorMessage)
    }

    private func correction(id: String) -> CatalogCorrection {
        CatalogCorrection(
            id: id,
            targetType: "dish",
            targetId: "dish-1",
            targetSummary: "红烧肉",
            baseRevision: 3,
            originalName: "红烧肉",
            originalDescription: nil,
            originalPrice: nil,
            proposedName: "红烧肉盖饭",
            proposedDescription: nil,
            proposedPrice: nil,
            changedFields: ["name"],
            reason: "菜单更新",
            status: "pending",
            reviewNote: nil,
            createdAt: Date(),
            reviewedAt: nil,
            revision: 1,
            evidenceUrls: [],
            originalPriceUnit: nil,
            proposedPriceUnit: nil
        )
    }
}
