import XCTest
@testable import FoodtimeNeo

final class SchoolEmailValidationTests: XCTestCase {
    func testSchoolEmailRequiresDigitsAndBjtuDomain() {
        XCTAssertEqual(
            SchoolEmailValidation.normalized(" 20260001@BJTU.EDU.CN "),
            "20260001@bjtu.edu.cn"
        )
        XCTAssertNil(SchoolEmailValidation.error("20260001@bjtu.edu.cn"))
        XCTAssertNotNil(SchoolEmailValidation.error(""))
        XCTAssertNotNil(SchoolEmailValidation.error("user@bjtu.edu.cn"))
        XCTAssertNotNil(SchoolEmailValidation.error("20260001@example.com"))
        XCTAssertNotNil(SchoolEmailValidation.error("20260001@sub.bjtu.edu.cn"))
    }
}
