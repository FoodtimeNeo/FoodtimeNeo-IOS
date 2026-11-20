import XCTest
@testable import FoodtimeNeo

final class RemoteAuthServiceTests: XCTestCase {
    func testRegistrationPolicyDecodesInvitationMode() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"mode":"invitation","canSendEmailCode":true,"invitationRequired":true,"revision":"invitation:email"}
            """))
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let policy = try await service.registrationPolicy()

        XCTAssertEqual(policy.mode, .invitation)
        XCTAssertTrue(policy.canSendEmailCode)
        XCTAssertTrue(policy.invitationRequired)
        XCTAssertEqual(policy.revision, "invitation:email")
    }

    func testSendRegistrationCodeUsesCSRFAndNormalizedEmail() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-1"}
            """)),
            .init(status: 202, body: TestFixtures.envelope("""
            {"expiresAt":"2026-11-20T04:15:00Z","resendAfterSeconds":60}
            """))
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let receipt = try await service.sendRegistrationCode(email: " User@Example.COM ")

        XCTAssertEqual(receipt.resendAfterSeconds, 60)
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/auth/register/email-code")
        XCTAssertEqual(transport.requests[1].value(forHTTPHeaderField: "X-CSRF-TOKEN"), "token-1")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["email"] as? String, "user@example.com")
    }

    func testRegisterSendsInvitationAndDecodesUser() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-2"}
            """)),
            .init(status: 201, body: TestFixtures.envelope("""
            {"id":"9e55b67f-f051-4019-bafd-a4082c95f2a6","email":"user@example.com","displayName":"干饭人012345","role":"user"}
            """))
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let user = try await service.register(
            email: "USER@example.com",
            password: "Foodtime2026!",
            verificationCode: "012345",
            invitationCode: "abcdefghjklm"
        )

        XCTAssertEqual(user.email, "user@example.com")
        XCTAssertEqual(user.displayName, "干饭人012345")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["email"] as? String, "user@example.com")
        XCTAssertEqual(json["verificationCode"] as? String, "012345")
        XCTAssertEqual(json["invitationCode"] as? String, "ABCDEFGHJKLM")
        XCTAssertEqual(json["password"] as? String, "Foodtime2026!")
    }

    func testEmailCodeInvalidSurfacesBusinessCode() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-3"}
            """)),
            .init(status: 400, body: """
            {"code":"EMAIL_CODE_INVALID","message":"验证码错误、过期或已用","data":null,"timestamp":"2026-11-20T00:00:00Z","requestId":"reg-1"}
            """)
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        do {
            _ = try await service.register(
                email: "user@example.com",
                password: "Foodtime2026!",
                verificationCode: "000000",
                invitationCode: nil
            )
            XCTFail("Expected EMAIL_CODE_INVALID")
        } catch let error as AppError {
            XCTAssertEqual(error.code, "EMAIL_CODE_INVALID")
        }
    }
}
