import XCTest
@testable import FoodtimeNeo

final class RemoteCatalogServiceTests: XCTestCase {
    func testSearchBuildsQueryAndDecodesPage() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"d-1","name":"鸡腿饭","price":15.00,"stallId":"s-1","stallName":"三号档口","diningHallId":"h-1","diningHallName":"学苑食堂","averageScore":4.32,"reviewCount":18}],"total":1,"page":2,"size":20}
            """))
        ]
        let service = RemoteCatalogService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar()),
            baseURL: TestFixtures.baseURL
        )
        let filters = DishSearchFilters(
            query: " 鸡腿 ",
            diningHallIDs: ["h-1", "h-2"],
            minPrice: Decimal(string: "5"),
            maxPrice: Decimal(string: "20.5"),
            minRating: 3.5,
            sort: .priceAsc,
            page: 2,
            size: 20
        )

        let page = try await service.searchDishes(filters)

        XCTAssertEqual(page.items.first?.name, "鸡腿饭")
        XCTAssertEqual(page.page, 2)
        let url = try XCTUnwrap(transport.requests.first?.url)
        XCTAssertEqual(url.path, "/api/v1/dishes/search")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        XCTAssertEqual(items.filter { $0.name == "diningHallIds" }.compactMap(\.value), ["h-1", "h-2"])
        XCTAssertEqual(items.first(where: { $0.name == "q" })?.value, "鸡腿")
        XCTAssertEqual(items.first(where: { $0.name == "minPrice" })?.value, "5")
        XCTAssertEqual(items.first(where: { $0.name == "maxPrice" })?.value, "20.5")
        XCTAssertEqual(items.first(where: { $0.name == "minRating" })?.value, "3.5")
        XCTAssertEqual(items.first(where: { $0.name == "sort" })?.value, "price_asc")
        XCTAssertEqual(items.first(where: { $0.name == "page" })?.value, "2")
    }

    func testDiningHallAndDishReadsDecode() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            [{"id":"h-1","name":"第一食堂","coverImageUrl":null,"description":null,"latitude":null,"longitude":null,"revision":1}]
            """))
        ]
        let service = RemoteCatalogService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar()),
            baseURL: TestFixtures.baseURL
        )

        let halls = try await service.diningHalls()

        XCTAssertEqual(halls.first?.name, "第一食堂")
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/v1/dining-halls")
    }

    func testDishDetailImagesAndRatingDecode() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"d-1","stallId":"s-1","stallName":"三号档口","diningHallId":"h-1","diningHallName":"学苑食堂","name":"鸡腿饭","description":null,"price":15.00,"revision":1}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[{"id":"i-1","dishId":"d-1","imageUrl":"/api/v1/media/i-1","createdAt":"2099-11-20T04:00:00Z"}],"total":1,"page":1,"size":20}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"averageScore":4.5,"reviewCount":2}
            """))
        ]
        let service = RemoteCatalogService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar()),
            baseURL: TestFixtures.baseURL
        )

        let detail = try await service.dishDetail(id: "d-1")
        let images = try await service.dishImages(id: "d-1", page: 1, size: 20)
        let rating = try await service.dishRating(id: "d-1")

        XCTAssertEqual(detail.name, "鸡腿饭")
        XCTAssertEqual(images.items.first?.imageUrl, "/api/v1/media/i-1")
        XCTAssertEqual(rating.averageScore, 4.5)
        XCTAssertEqual(transport.requests.map(\.url?.path), [
            "/api/v1/dishes/d-1",
            "/api/v1/dishes/d-1/images",
            "/api/v1/dishes/d-1/rating"
        ])
    }
}
