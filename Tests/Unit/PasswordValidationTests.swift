import XCTest
@testable import FoodtimeNeo

final class PasswordValidationTests: XCTestCase {
    func testCurrentPasswordOnlyChecksTransportShape() {
        XCTAssertNil(PasswordValidation.currentPasswordError("abcdefgh"))
        XCTAssertNil(PasswordValidation.currentPasswordError("12345678"))
        XCTAssertNotNil(PasswordValidation.currentPasswordError("short"))
        XCTAssertNotNil(PasswordValidation.currentPasswordError("密码12345678"))
        XCTAssertNotNil(PasswordValidation.currentPasswordError("abc 12345"))
    }

    func testNewPasswordUsesRegistrationRules() {
        XCTAssertNil(PasswordValidation.newPasswordError("Foodtime2026!"))
        XCTAssertNotNil(PasswordValidation.newPasswordError("abcdefgh"))
        XCTAssertNotNil(PasswordValidation.newPasswordError("12345678"))
    }

    func testResetTokenShape() {
        XCTAssertNil(PasswordValidation.resetTokenError(String(repeating: "a", count: 43)))
        XCTAssertNotNil(PasswordValidation.resetTokenError(String(repeating: "a", count: 42)))
        XCTAssertNotNil(PasswordValidation.resetTokenError(String(repeating: "!", count: 43)))
    }
}
