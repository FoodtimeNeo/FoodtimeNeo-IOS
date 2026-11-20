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

    func testPasswordResetVerifyDecodesGrant() async throws {
        let transport = StubHTTPTransport()
        let token = String(repeating: "a", count: 43)
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-4"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"resetToken":"\(token)","expiresAt":"2099-11-20T04:05:00Z"}
            """))
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let grant = try await service.verifyPasswordResetCode(
            email: "USER@example.com",
            verificationCode: "012345"
        )

        XCTAssertEqual(grant.resetToken, token)
        XCTAssertFalse(grant.isExpired)
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["email"] as? String, "user@example.com")
        XCTAssertEqual(json["verificationCode"] as? String, "012345")
    }

    func testChangePasswordUsesPUTAndCSRF() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-5"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        try await service.changePassword(oldPassword: "Old12345!", newPassword: "New12345!")

        let request = transport.requests[1]
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.url?.path, "/api/v1/users/me/password")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-CSRF-TOKEN"), "token-5")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["oldPassword"] as? String, "Old12345!")
        XCTAssertEqual(json["newPassword"] as? String, "New12345!")
    }

    func testResetPasswordSendsTokenAndNewPassword() async throws {
        let transport = StubHTTPTransport()
        let token = String(repeating: "b", count: 43)
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-6"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        try await service.resetPassword(resetToken: token, newPassword: "New12345!")

        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/auth/password-reset")
        XCTAssertEqual(json["resetToken"] as? String, token)
        XCTAssertEqual(json["newPassword"] as? String, "New12345!")
    }

    func testCurrentProfileDecodesCountsAndSchoolEmail() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"9e55b67f-f051-4019-bafd-a4082c95f2a6","email":"user@example.com","displayName":"干饭人012345","role":"user","avatarUrl":null,"followingCount":3,"followerCount":5,"schoolEmail":"20260001@bjtu.edu.cn","schoolEmailVerified":true}
            """))
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let profile = try await service.currentProfile()

        XCTAssertEqual(profile.displayName, "干饭人012345")
        XCTAssertEqual(profile.followingCount, 3)
        XCTAssertEqual(profile.followerCount, 5)
        XCTAssertEqual(profile.schoolEmail, "20260001@bjtu.edu.cn")
        XCTAssertTrue(profile.schoolEmailVerified)
    }

    func testUpdateProfileAlwaysEncodesAvatarKey() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-7"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"9e55b67f-f051-4019-bafd-a4082c95f2a6","email":"user@example.com","displayName":"干饭达人","role":"user","avatarUrl":null,"followingCount":3,"followerCount":5,"schoolEmail":null,"schoolEmailVerified":false}
            """))
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let profile = try await service.updateProfile(displayName: " 干饭达人 ", avatarUrl: nil)

        XCTAssertEqual(profile.displayName, "干饭达人")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["displayName"] as? String, "干饭达人")
        XCTAssertTrue(json["avatarUrl"] is NSNull)
    }

    func testAccountLifecycleSummaryAndDeletionCode() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"verificationEmail":"user@example.com","schoolEmail":null,"canDelete":true,"canUnbind":false,"deletionCodeAvailableAt":null}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-8"}
            """)),
            .init(status: 202, body: TestFixtures.envelope("""
            {"expiresAt":"2099-11-20T04:15:00Z","nextSendAt":"2099-11-21T00:00:00Z","verificationEmail":"user@example.com"}
            """))
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let summary = try await service.accountLifecycle()
        let receipt = try await service.sendAccountLifecycleCode(.delete)

        XCTAssertTrue(summary.canDelete)
        XCTAssertNil(summary.schoolEmail)
        XCTAssertEqual(receipt.verificationEmail, "user@example.com")
        XCTAssertEqual(transport.requests.count, 3)
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/users/me/account-lifecycle")
        XCTAssertEqual(transport.requests[2].url?.path, "/api/v1/users/me/account-lifecycle/delete-code")
        XCTAssertEqual(transport.requests[2].value(forHTTPHeaderField: "X-CSRF-TOKEN"), "token-8")
    }

    func testBindSchoolEmailNormalizesAddress() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-9"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"9e55b67f-f051-4019-bafd-a4082c95f2a6","email":"user@example.com","displayName":"干饭人012345","role":"user","avatarUrl":null,"followingCount":3,"followerCount":5,"schoolEmail":"20260001@bjtu.edu.cn","schoolEmailVerified":true}
            """))
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let profile = try await service.bindSchoolEmail(
            email: "20260001@BJTU.EDU.CN",
            verificationCode: "012345"
        )

        XCTAssertEqual(profile.schoolEmail, "20260001@bjtu.edu.cn")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["email"] as? String, "20260001@bjtu.edu.cn")
        XCTAssertEqual(json["verificationCode"] as? String, "012345")
    }

    func testDeleteAccountPostsVerificationCode() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-10"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"deleted":true,"emailsReusableAt":"2099-11-20T05:00:00Z"}
            """))
        ]
        let service = RemoteAuthService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let result = try await service.deleteAccount(verificationCode: "012345")

        XCTAssertTrue(result.deleted)
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/users/me/account-lifecycle/delete")
        let body = try XCTUnwrap(transport.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["verificationCode"] as? String, "012345")
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
