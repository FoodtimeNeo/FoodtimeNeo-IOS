import XCTest
@testable import FoodtimeNeo

final class RemoteCorrectionServiceTests: XCTestCase {
    func testSubmitSendsFieldsAndEvidence() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-correction"}
            """)),
            .init(status: 201, body: TestFixtures.envelope(CorrectionFixtures.responseJSON))
        ]
        let service = RemoteCorrectionService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )
        let proposal = CorrectionProposal(
            targetType: "dish",
            targetId: "dish-1",
            baseRevision: 3,
            changedFields: ["name", "price"],
            name: "红烧肉盖饭",
            description: nil,
            price: Decimal(string: "15.5"),
            priceUnit: "serving",
            reason: "菜单已更新",
            evidenceUrls: ["/api/v1/media/media-1"],
            idempotencyKey: "idem-1"
        )

        let correction = try await service.submit(proposal)

        XCTAssertEqual(correction.id, "cc-1")
        XCTAssertEqual(correction.statusLabel, "待核对")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/users/me/catalog-corrections")
        XCTAssertEqual(transport.requests[1].httpMethod, "POST")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["targetType"] as? String, "dish")
        XCTAssertEqual(json["baseRevision"] as? Int, 3)
        XCTAssertEqual(json["changedFields"] as? [String], ["name", "price"])
        XCTAssertEqual(json["reason"] as? String, "菜单已更新")
        XCTAssertEqual(json["idempotencyKey"] as? String, "idem-1")
        XCTAssertEqual(json["priceUnit"] as? String, "serving")
        XCTAssertEqual(json["evidenceUrls"] as? [String], ["/api/v1/media/media-1"])
        XCTAssertEqual((json["price"] as? NSNumber)?.doubleValue, 15.5)
        XCTAssertNil(json["description"])
    }

    func testMineDecodesPageAndSendsPaging() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[\(CorrectionFixtures.responseJSON)],"total":1,"page":2,"size":20}
            """))
        ]
        let service = RemoteCorrectionService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let page = try await service.mine(page: 2, size: 20)

        XCTAssertEqual(page.items.first?.targetSummary, "红烧肉")
        XCTAssertEqual(page.items.first?.changeDescriptions, ["名称：红烧肉 → 红烧肉盖饭"])
        let url = try XCTUnwrap(transport.requests.first?.url)
        XCTAssertEqual(url.path, "/api/v1/users/me/catalog-corrections")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "page" })?.value, "2")
    }

    func testDetailUsesOwnProposalPath() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope(CorrectionFixtures.responseJSON))
        ]
        let service = RemoteCorrectionService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        _ = try await service.detail(id: "cc-1")

        XCTAssertEqual(
            transport.requests.first?.url?.path,
            "/api/v1/users/me/catalog-corrections/cc-1"
        )
    }
}

enum CorrectionFixtures {
    static let dish = DishDetail(
        id: "dish-1",
        stallId: "stall-1",
        stallName: "一档",
        diningHallId: "hall-1",
        diningHallName: "学苑食堂",
        name: "红烧肉",
        description: "咸香",
        price: Decimal(string: "12.5"),
        revision: 3
    )

    static let correction = CatalogCorrection(
        id: "cc-1",
        targetType: "dish",
        targetId: "dish-1",
        targetSummary: "红烧肉",
        baseRevision: 3,
        originalName: "红烧肉",
        originalDescription: "咸香",
        originalPrice: Decimal(string: "12.5"),
        proposedName: "红烧肉盖饭",
        proposedDescription: nil,
        proposedPrice: Decimal(string: "15.5"),
        changedFields: ["name"],
        reason: "菜单已更新",
        status: "pending",
        reviewNote: nil,
        createdAt: Date(),
        reviewedAt: nil,
        revision: 1,
        evidenceUrls: [],
        originalPriceUnit: "serving",
        proposedPriceUnit: nil
    )

    static let responseJSON = """
    {"id":"cc-1","targetType":"dish","targetId":"dish-1","targetSummary":"红烧肉","baseRevision":3,"originalName":"红烧肉","originalDescription":"咸香","originalPrice":12.5,"proposedName":"红烧肉盖饭","proposedDescription":null,"proposedPrice":15.5,"changedFields":["name"],"reason":"菜单已更新","status":"pending","reviewNote":null,"createdAt":"2099-11-21T04:00:00Z","reviewedAt":null,"revision":1,"evidenceUrls":[],"originalPriceUnit":"serving","proposedPriceUnit":null}
    """
}
