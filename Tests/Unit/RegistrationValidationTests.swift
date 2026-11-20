import XCTest
@testable import FoodtimeNeo

final class RegistrationValidationTests: XCTestCase {
    func testEmailNormalizationAndShape() {
        XCTAssertEqual(RegistrationValidation.normalizedEmail(" User@Example.COM "), "user@example.com")
        XCTAssertNil(RegistrationValidation.emailError("user@example.com"))
        XCTAssertNotNil(RegistrationValidation.emailError(""))
        XCTAssertNotNil(RegistrationValidation.emailError("not-an-email"))
        XCTAssertNotNil(RegistrationValidation.emailError("a@b"))
        XCTAssertNotNil(RegistrationValidation.emailError(String(repeating: "a", count: 250) + "@b.com"))
    }

    func testPasswordRules() {
        XCTAssertNil(RegistrationValidation.passwordError("Foodtime2026!"))
        XCTAssertNotNil(RegistrationValidation.passwordError("short1"))
        XCTAssertNotNil(RegistrationValidation.passwordError("12345678"))
        XCTAssertNotNil(RegistrationValidation.passwordError("abcdefgh"))
        XCTAssertNotNil(RegistrationValidation.passwordError("密码12345678"))
        XCTAssertNotNil(RegistrationValidation.passwordError("abc 12345"))
        XCTAssertNotNil(RegistrationValidation.passwordError(String(repeating: "a1", count: 65)))
    }

    func testEmailCodeIsSixDigits() {
        XCTAssertNil(RegistrationValidation.emailCodeError("012345"))
        XCTAssertNotNil(RegistrationValidation.emailCodeError("12345"))
        XCTAssertNotNil(RegistrationValidation.emailCodeError("1234567"))
        XCTAssertNotNil(RegistrationValidation.emailCodeError("12a456"))
    }

    func testInvitationCodeRules() {
        XCTAssertNil(RegistrationValidation.invitationError("", required: false))
        XCTAssertNotNil(RegistrationValidation.invitationError("", required: true))
        XCTAssertNil(RegistrationValidation.invitationError("abcdefghjklm", required: true))
        XCTAssertEqual(
            RegistrationValidation.normalizedInvitationCode("abcdefghjklm"),
            "ABCDEFGHJKLM"
        )
        XCTAssertNotNil(RegistrationValidation.invitationError("ABCDEFGHIJKL", required: true))
        XCTAssertNotNil(RegistrationValidation.invitationError("ABCDEFGHJK", required: true))
    }
}
