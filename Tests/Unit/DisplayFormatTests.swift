import XCTest
@testable import FoodtimeNeo

final class DisplayFormatTests: XCTestCase {
    func testPriceKeepsTwoDecimalsAndNullIsNotZero() {
        XCTAssertEqual(DisplayFormat.price(Decimal(string: "12.3")), "¥12.30")
        XCTAssertEqual(DisplayFormat.price(Decimal(string: "0")), "¥0.00")
        XCTAssertEqual(DisplayFormat.price(nil), "价格待补充")
    }

    func testScoreDistinguishesNoRatingFromZero() {
        XCTAssertEqual(DisplayFormat.score(nil, reviewCount: 0), "暂无评分（0）")
        XCTAssertEqual(DisplayFormat.score(4.5, reviewCount: 12), "4.5 分 · 12 条点评")
    }

    func testDateTimeUsesShanghaiTimeZone() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-20T04:00:00Z"))
        XCTAssertEqual(DisplayFormat.dateTime(date), "2026-11-20 12:00")
    }
}
