import XCTest
@testable import FoodtimeNeo

final class PriceHistoryBuilderTests: XCTestCase {
    func testRunsBreakOnUnitChangeAndNullAndMergeEqualPrices() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 100)
        let history = DishPriceHistory(
            dishId: "d-1",
            dishName: "鸡腿饭",
            currentPrice: Decimal(string: "6"),
            priceUnit: "piece",
            revision: 1,
            windowStart: start,
            windowEnd: end,
            canManage: false,
            totalRecords: 6,
            records: [
                entry("1", "10", "serving", 10),
                entry("2", "10", "serving", 20),
                entry("3", "12", "serving", 30),
                entry("4", nil, "serving", 40),
                entry("5", "5", "piece", 50),
                entry("6", "6", "piece", 60)
            ]
        )

        let runs = PriceHistoryBuilder.runs(history)

        XCTAssertEqual(runs.count, 2)
        XCTAssertEqual(runs[0].unit, "serving")
        XCTAssertEqual(runs[0].points.count, 2)
        XCTAssertEqual(runs[0].start, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(runs[0].end, Date(timeIntervalSince1970: 40))
        XCTAssertEqual(runs[1].unit, "piece")
        XCTAssertEqual(runs[1].points.count, 2)
        XCTAssertEqual(runs[1].start, Date(timeIntervalSince1970: 50))
        XCTAssertEqual(runs[1].end, end)
    }

    func testUnitLabels() {
        XCTAssertEqual(PriceUnit.label("serving"), "份")
        XCTAssertEqual(PriceUnit.label("100g"), "100克")
        XCTAssertEqual(PriceUnit.label("unspecified"), "未注明")
        XCTAssertEqual(PriceUnit.label("other"), "other")
    }

    private func entry(_ id: String, _ price: String?, _ unit: String, _ time: TimeInterval) -> PriceHistoryEntry {
        PriceHistoryEntry(
            id: id,
            price: price.flatMap { Decimal(string: $0) },
            priceUnit: unit,
            recordedAt: Date(timeIntervalSince1970: time),
            origin: "user",
            revision: 1,
            carriedForward: false
        )
    }
}
