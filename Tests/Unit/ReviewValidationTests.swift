import XCTest
@testable import FoodtimeNeo

final class ReviewValidationTests: XCTestCase {
    func testRatingAndContent() {
        XCTAssertNil(ReviewValidation.ratingError(1))
        XCTAssertNil(ReviewValidation.ratingError(5))
        XCTAssertNotNil(ReviewValidation.ratingError(0))
        XCTAssertNotNil(ReviewValidation.ratingError(6))
        XCTAssertNil(ReviewValidation.contentError("好吃"))
        XCTAssertNil(ReviewValidation.contentError(String(repeating: "a", count: 500)))
        XCTAssertNotNil(ReviewValidation.contentError("   "))
        XCTAssertNotNil(ReviewValidation.contentError(String(repeating: "a", count: 501)))
    }
}
