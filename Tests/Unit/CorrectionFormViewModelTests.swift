import XCTest
import UIKit
@testable import FoodtimeNeo

@MainActor
final class CorrectionFormViewModelTests: XCTestCase {
    func testSubmitRequiresAtLeastOneField() async {
        let model = makeModel()

        await model.submit()

        XCTAssertEqual(model.errorMessage, "请至少勾选一个要更正的字段")
        XCTAssertTrue(FakeCorrectionService().proposals.isEmpty)
    }

    func testSubmitRequiresReason() async {
        let model = makeModel()
        model.fixName = true

        await model.submit()

        XCTAssertEqual(model.errorMessage, "请填写更正理由")
    }

    func testRejectsNegativePrice() async {
        let model = makeModel()
        model.fixPrice = true
        model.priceText = "-1"
        model.reason = "菜单更新"

        await model.submit()

        XCTAssertEqual(model.errorMessage, "价格必须为非负数")
    }

    func testSubmitSendsSelectedFieldsAndEvidence() async throws {
        let submissions = FakeSubmissionService()
        let corrections = FakeCorrectionService()
        let model = makeModel(submissions: submissions, corrections: corrections)
        model.fixName = true
        model.name = "  红烧肉盖饭  "
        model.fixPrice = true
        model.priceText = "15.50"
        model.fixPriceUnit = true
        model.priceUnit = "serving"
        model.reason = "  菜单已更新  "
        await model.addEvidence([testImage()])

        await model.submit()

        let proposal = try XCTUnwrap(corrections.proposals.first)
        XCTAssertEqual(proposal.targetType, "dish")
        XCTAssertEqual(proposal.targetId, "dish-1")
        XCTAssertEqual(proposal.baseRevision, 3)
        XCTAssertEqual(proposal.changedFields, ["name", "price", "priceUnit"])
        XCTAssertEqual(proposal.name, "红烧肉盖饭")
        XCTAssertEqual(proposal.price, Decimal(string: "15.5"))
        XCTAssertEqual(proposal.priceUnit, "serving")
        XCTAssertEqual(proposal.reason, "菜单已更新")
        XCTAssertEqual(proposal.evidenceUrls, ["/api/v1/media/media-1"])
        XCTAssertEqual(submissions.uploadCalls, 1)
        XCTAssertNotNil(model.receipt)
    }

    func testEmptyPriceMeansUnknown() async throws {
        let corrections = FakeCorrectionService()
        let model = makeModel(corrections: corrections)
        model.fixPrice = true
        model.priceText = ""
        model.reason = "价格待补充"

        await model.submit()

        let proposal = try XCTUnwrap(corrections.proposals.first)
        XCTAssertEqual(proposal.changedFields, ["price"])
        XCTAssertNil(proposal.price)
    }

    func testRetryReusesIdempotencyKeyForSamePayload() async throws {
        let corrections = FakeCorrectionService()
        var attempts = 0
        corrections.submitHandler = { _ in
            attempts += 1
            if attempts == 1 {
                throw AppError.network(message: "offline")
            }
            return CorrectionFixtures.correction
        }
        let model = makeModel(corrections: corrections)
        model.fixName = true
        model.name = "红烧肉盖饭"
        model.reason = "菜单更新"

        await model.submit()
        await model.submit()

        XCTAssertEqual(corrections.proposals.count, 2)
        XCTAssertEqual(corrections.proposals[0].idempotencyKey, corrections.proposals[1].idempotencyKey)
        XCTAssertNotNil(model.receipt)
    }

    func testChangedContentUsesNewIdempotencyKey() async throws {
        let corrections = FakeCorrectionService()
        var attempts = 0
        corrections.submitHandler = { _ in
            attempts += 1
            if attempts == 1 {
                throw AppError.network(message: "offline")
            }
            return CorrectionFixtures.correction
        }
        let model = makeModel(corrections: corrections)
        model.fixName = true
        model.name = "红烧肉盖饭"
        model.reason = "菜单更新"

        await model.submit()
        model.reason = "菜单再次更新"
        await model.submit()

        XCTAssertEqual(corrections.proposals.count, 2)
        XCTAssertNotEqual(corrections.proposals[0].idempotencyKey, corrections.proposals[1].idempotencyKey)
    }

    func testEvidenceUploadFailureBlocksSubmit() async {
        let submissions = FakeSubmissionService()
        submissions.uploadResult = .failure(AppError.network(message: "offline"))
        let corrections = FakeCorrectionService()
        let model = makeModel(submissions: submissions, corrections: corrections)
        model.fixName = true
        model.name = "红烧肉盖饭"
        model.reason = "菜单更新"

        await model.addEvidence([testImage()])
        await model.submit()

        XCTAssertTrue(corrections.proposals.isEmpty)
        XCTAssertEqual(model.errorMessage, "证据图片上传失败，请重试")
    }

    func testMissingRevisionDoesNotSubmit() async {
        let corrections = FakeCorrectionService()
        var dish = CorrectionFixtures.dish
        dish = DishDetail(
            id: dish.id,
            stallId: dish.stallId,
            stallName: dish.stallName,
            diningHallId: dish.diningHallId,
            diningHallName: dish.diningHallName,
            name: dish.name,
            description: dish.description,
            price: dish.price,
            revision: 0
        )
        let model = CorrectionFormViewModel(
            dish: dish,
            corrections: corrections,
            submissions: FakeSubmissionService()
        )
        model.fixName = true
        model.name = "红烧肉盖饭"
        model.reason = "菜单更新"

        await model.submit()

        XCTAssertTrue(corrections.proposals.isEmpty)
        XCTAssertFalse(model.canInteract)
    }

    private func makeModel(
        submissions: FakeSubmissionService = FakeSubmissionService(),
        corrections: FakeCorrectionService = FakeCorrectionService()
    ) -> CorrectionFormViewModel {
        CorrectionFormViewModel(
            dish: CorrectionFixtures.dish,
            corrections: corrections,
            submissions: submissions
        )
    }

    private func testImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
}

final class FakeCorrectionService: CorrectionService {
    var submitHandler: (CorrectionProposal) throws -> CatalogCorrection = { _ in
        CorrectionFixtures.correction
    }
    var mineResult = Result<Page<CatalogCorrection>, Error>.success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    private(set) var proposals: [CorrectionProposal] = []

    func submit(_ proposal: CorrectionProposal) async throws -> CatalogCorrection {
        proposals.append(proposal)
        return try submitHandler(proposal)
    }

    func mine(page: Int, size: Int) async throws -> Page<CatalogCorrection> {
        try mineResult.get()
    }

    func detail(id: String) async throws -> CatalogCorrection {
        CorrectionFixtures.correction
    }
}
