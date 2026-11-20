import XCTest
@testable import FoodtimeNeo

final class FeedbackValidationTests: XCTestCase {
    func testContentTrimAndLength() {
        XCTAssertEqual(FeedbackValidation.normalizedContent("  建议  "), "建议")
        XCTAssertNil(FeedbackValidation.contentError("建议"))
        XCTAssertNil(FeedbackValidation.contentError(String(repeating: "a", count: 5000)))
        XCTAssertNotNil(FeedbackValidation.contentError("   "))
        XCTAssertNotNil(FeedbackValidation.contentError(String(repeating: "a", count: 5001)))
    }

    func testTypeLabels() {
        XCTAssertEqual(FeedbackType.suggestion.label, "改进建议")
        XCTAssertEqual(FeedbackType.other.label, "其他")
    }
}
