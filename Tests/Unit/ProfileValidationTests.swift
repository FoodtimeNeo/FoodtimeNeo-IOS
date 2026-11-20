import XCTest
@testable import FoodtimeNeo

final class ProfileValidationTests: XCTestCase {
    func testDisplayNameTrimsAndChecksLength() {
        XCTAssertEqual(ProfileValidation.normalizedDisplayName("  干饭人  "), "干饭人")
        XCTAssertNil(ProfileValidation.displayNameError("干饭人"))
        XCTAssertNil(ProfileValidation.displayNameError(String(repeating: "a", count: 50)))
        XCTAssertNotNil(ProfileValidation.displayNameError("   "))
        XCTAssertNotNil(ProfileValidation.displayNameError(String(repeating: "a", count: 51)))
    }
}
