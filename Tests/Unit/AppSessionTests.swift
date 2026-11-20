import XCTest
@testable import FoodtimeNeo

@MainActor
final class AppSessionTests: XCTestCase {
    func testStartWithoutSessionCookieSignsOut() async {
        let jar = MemoryCookieJar()
        let auth = FakeAuthService()
        let session = makeSession(auth: auth, jar: jar)

        await session.start()

        XCTAssertEqual(session.state, .signedOut)
        XCTAssertTrue(session.capabilities.capabilities.isEmpty)
    }

    func testStartRestoresSessionAndCapabilities() async {
        let jar = MemoryCookieJar()
        jar.sessionCookiePresent = true
        let auth = FakeAuthService()
        auth.sessionResult = .success(SessionSnapshot(user: TestFixtures.user, mode: .normal))
        auth.capabilitiesResult = .success(
            CapabilitySnapshot(capabilities: ["catalog.edit"], revision: "default-v4")
        )
        let session = makeSession(auth: auth, jar: jar)

        await session.start()

        XCTAssertEqual(session.state, .signedIn(TestFixtures.user))
        XCTAssertEqual(session.capabilities.capabilities, ["catalog.edit"])
        XCTAssertTrue(session.canUseAdminArea)
    }

    func testStartAppealOnlyDoesNotLoadCapabilities() async {
        let jar = MemoryCookieJar()
        jar.sessionCookiePresent = true
        let auth = FakeAuthService()
        auth.sessionResult = .success(SessionSnapshot(user: TestFixtures.user, mode: .appealOnly))
        auth.capabilitiesResult = .success(
            CapabilitySnapshot(capabilities: ["user.manage"], revision: "default-v4")
        )
        let session = makeSession(auth: auth, jar: jar)

        await session.start()

        XCTAssertEqual(session.state, .appealOnly(TestFixtures.user))
        XCTAssertTrue(session.capabilities.capabilities.isEmpty)
    }

    func testLoginAppliesOutcomeAndCapabilities() async throws {
        let auth = FakeAuthService()
        auth.loginResult = .success(
            LoginOutcome(user: TestFixtures.user, mode: .normal, expiresAt: nil)
        )
        auth.capabilitiesResult = .success(
            CapabilitySnapshot(capabilities: ["correction.submit"], revision: "default-v4")
        )
        let session = makeSession(auth: auth, jar: MemoryCookieJar())

        try await session.login(account: "user@example.com", password: "password1", captcha: nil)

        XCTAssertEqual(session.state, .signedIn(TestFixtures.user))
        XCTAssertEqual(session.capabilities.capabilities, ["correction.submit"])
        XCTAssertEqual(auth.loginCalls, 1)
    }

    func testLogoutClearsLocalSessionEvenWhenNetworkFails() async {
        let jar = MemoryCookieJar()
        jar.sessionCookiePresent = true
        let auth = FakeAuthService()
        auth.logoutError = AppError.network(message: "offline")
        let session = makeSession(auth: auth, jar: jar)

        await session.logout()

        XCTAssertEqual(session.state, .signedOut)
        XCTAssertFalse(jar.sessionCookiePresent)
    }

    func testChangePasswordClearsLocalSession() async throws {
        let jar = MemoryCookieJar()
        jar.sessionCookiePresent = true
        let auth = FakeAuthService()
        auth.sessionResult = .success(SessionSnapshot(user: TestFixtures.user, mode: .normal))
        let session = makeSession(auth: auth, jar: jar)
        await session.start()
        XCTAssertTrue(session.isSignedIn)

        try await session.changePassword(oldPassword: "Old12345!", newPassword: "New12345!")

        XCTAssertEqual(session.state, .signedOut)
        XCTAssertFalse(jar.sessionCookiePresent)
        XCTAssertEqual(auth.changePasswordCalls, 1)
    }

    func testUpdateProfileRefreshesSessionUser() async throws {
        let jar = MemoryCookieJar()
        jar.sessionCookiePresent = true
        let auth = FakeAuthService()
        auth.sessionResult = .success(SessionSnapshot(user: TestFixtures.user, mode: .normal))
        let updatedProfile = UserProfile(
            id: TestFixtures.user.id,
            email: TestFixtures.user.email,
            displayName: "新昵称",
            role: TestFixtures.user.role,
            avatarUrl: nil,
            followingCount: 3,
            followerCount: 5,
            schoolEmail: nil,
            schoolEmailVerified: false
        )
        auth.updateProfileResult = .success(updatedProfile)
        let session = makeSession(auth: auth, jar: jar)
        await session.start()

        let result = try await session.updateProfile(displayName: " 新昵称 ", avatarUrl: nil)

        XCTAssertEqual(result.displayName, "新昵称")
        XCTAssertEqual(session.state, .signedIn(updatedProfile.asUser))
        XCTAssertEqual(auth.updateProfileCalls, 1)
        XCTAssertEqual(auth.lastUpdatedDisplayName, " 新昵称 ")
    }

    func testDeleteAccountClearsSessionAndSetsNotice() async throws {
        let jar = MemoryCookieJar()
        jar.sessionCookiePresent = true
        let auth = FakeAuthService()
        auth.sessionResult = .success(SessionSnapshot(user: TestFixtures.user, mode: .normal))
        auth.deleteAccountResult = .success(
            AccountDeletionResult(deleted: true, emailsReusableAt: Date().addingTimeInterval(3600))
        )
        let session = makeSession(auth: auth, jar: jar)
        await session.start()

        _ = try await session.deleteAccount(verificationCode: "012345")

        XCTAssertEqual(session.state, .signedOut)
        XCTAssertFalse(jar.sessionCookiePresent)
        XCTAssertNotNil(session.accountDeletionNotice)
        XCTAssertEqual(auth.deleteAccountCalls, 1)
    }

    func testUnbindSchoolEmailRefreshesSessionUser() async throws {
        let jar = MemoryCookieJar()
        jar.sessionCookiePresent = true
        let auth = FakeAuthService()
        auth.sessionResult = .success(SessionSnapshot(user: TestFixtures.user, mode: .normal))
        let visitor = UserProfile(
            id: TestFixtures.user.id,
            email: TestFixtures.user.email,
            displayName: TestFixtures.user.displayName,
            role: "visitor",
            avatarUrl: nil,
            followingCount: 0,
            followerCount: 0,
            schoolEmail: nil,
            schoolEmailVerified: false
        )
        auth.unbindResult = .success(
            SchoolEmailUnbindResult(profile: visitor, schoolEmailReusableAt: Date().addingTimeInterval(3600))
        )
        let session = makeSession(auth: auth, jar: jar)
        await session.start()

        _ = try await session.unbindSchoolEmail(verificationCode: "012345")

        XCTAssertEqual(session.state, .signedIn(visitor.asUser))
    }

    func testRecordHistoryUsesSettingsEpoch() async {
        let jar = MemoryCookieJar()
        jar.sessionCookiePresent = true
        let auth = FakeAuthService()
        auth.sessionResult = .success(SessionSnapshot(user: TestFixtures.user, mode: .normal))
        let history = FakeHistoryService()
        history.settingsResult = .success(
            BrowsingHistorySettings(enabled: true, revision: 1, dishEpoch: 7, postEpoch: 8)
        )
        let session = makeSession(auth: auth, jar: jar, history: history)
        await session.start()

        await session.recordHistory(kind: .dish, targetID: "d-1")

        XCTAssertEqual(history.recordCalls.count, 1)
        XCTAssertEqual(history.recordCalls.first?.0, .dish)
        XCTAssertEqual(history.recordCalls.first?.1, "d-1")
        XCTAssertEqual(history.recordCalls.first?.2, 7)
    }

    func testUnauthorizedClearsSessionAndCapabilities() async {
        let jar = MemoryCookieJar()
        jar.sessionCookiePresent = true
        let auth = FakeAuthService()
        auth.sessionResult = .success(SessionSnapshot(user: TestFixtures.user, mode: .normal))
        auth.capabilitiesResult = .success(
            CapabilitySnapshot(capabilities: ["catalog.edit"], revision: "default-v4")
        )
        let session = makeSession(auth: auth, jar: jar)
        await session.start()
        XCTAssertTrue(session.isSignedIn)

        await session.handleUnauthorized()

        XCTAssertEqual(session.state, .signedOut)
        XCTAssertTrue(session.capabilities.capabilities.isEmpty)
        XCTAssertFalse(jar.sessionCookiePresent)
    }

    private func makeSession(
        auth: FakeAuthService,
        jar: MemoryCookieJar,
        history: FakeHistoryService = FakeHistoryService()
    ) -> AppSession {
        let api = APIClient(
            baseURL: TestFixtures.baseURL,
            transport: StubHTTPTransport(),
            cookieJar: jar
        )
        return AppSession(
            auth: auth,
            catalog: FakeCatalogService(),
            social: FakeSocialService(),
            feedback: FakeFeedbackService(),
            reviews: FakeReviewService(),
            venueReviews: FakeVenueReviewService(),
            submissions: FakeSubmissionService(),
            community: FakeCommunityService(),
            drafts: MemoryDraftStore(),
            favorites: FakeFavoriteService(),
            history: history,
            inbox: FakeInboxService(),
            messages: FakeMessageService(),
            notifications: FakeNotificationService(),
            api: api,
            cookieJar: jar,
            archive: MemoryCookieArchive(),
            baseURL: TestFixtures.baseURL
        )
    }
}
