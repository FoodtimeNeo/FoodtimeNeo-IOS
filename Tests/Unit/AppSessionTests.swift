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

    private func makeSession(auth: FakeAuthService, jar: MemoryCookieJar) -> AppSession {
        let api = APIClient(
            baseURL: TestFixtures.baseURL,
            transport: StubHTTPTransport(),
            cookieJar: jar
        )
        return AppSession(
            auth: auth,
            catalog: FakeCatalogService(),
            api: api,
            cookieJar: jar,
            archive: MemoryCookieArchive(),
            baseURL: TestFixtures.baseURL
        )
    }
}
