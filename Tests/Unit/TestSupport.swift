import Foundation
@testable import FoodtimeNeo

final class StubHTTPTransport: HTTPTransporting {
    struct Reply {
        let status: Int
        let body: String
        let headers: [String: String]

        init(status: Int, body: String = "", headers: [String: String] = [:]) {
            self.status = status
            self.body = body
            self.headers = headers
        }
    }

    var replies: [Reply] = []
    var error: Error?
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if let error { throw error }
        guard !replies.isEmpty else {
            throw AppError.network(message: "No stubbed reply")
        }
        let reply = replies.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: reply.status,
            httpVersion: "HTTP/1.1",
            headerFields: reply.headers
        )!
        return (Data(reply.body.utf8), response)
    }
}

final class MemoryCookieJar: CookieJar {
    var stored: [HTTPCookie] = []
    var sessionCookiePresent = false

    func cookies(for url: URL) -> [HTTPCookie] {
        stored
    }

    func setCookie(_ cookie: HTTPCookie) {
        stored.append(cookie)
        if cookie.name == "FOODTIME_SESSION" {
            sessionCookiePresent = true
        }
    }

    func deleteCookie(_ cookie: HTTPCookie) {
        stored.removeAll { $0.name == cookie.name && $0.value == cookie.value }
        if cookie.name == "FOODTIME_SESSION" {
            sessionCookiePresent = false
        }
    }

    func hasSessionCookie(for url: URL) -> Bool {
        sessionCookiePresent
    }

    func clearSessionCookies(for url: URL) {
        stored.removeAll { $0.name == "FOODTIME_SESSION" }
        sessionCookiePresent = false
    }
}

final class MemoryCookieArchive: CookieArchiving {
    private(set) var saved: [HTTPCookie] = []

    func save(cookies: [HTTPCookie], origin: URL) {
        saved = cookies
    }

    func load(origin: URL) -> [HTTPCookie] {
        saved
    }

    func clearAll() {
        saved = []
    }
}

final class FakeAuthService: AuthService {
    var policy = RegistrationPolicy(
        mode: .open,
        canSendEmailCode: true,
        invitationRequired: false,
        revision: "open:email"
    )
    var challenge = CaptchaChallenge(challengeId: "challenge-1", imageBase64: "", expiresAt: nil)
    var loginResult: Result<LoginOutcome, Error> = .failure(AppError.unauthenticated)
    var registrationCodeResult: Result<EmailCodeReceipt, Error> = .success(
        EmailCodeReceipt(expiresAt: nil, resendAfterSeconds: 60)
    )
    var registerResult: Result<User, Error> = .success(TestFixtures.user)
    var sessionResult: Result<SessionSnapshot, Error> = .failure(AppError.unauthenticated)
    var capabilitiesResult: Result<CapabilitySnapshot, Error> = .success(.empty)
    var logoutError: Error?
    private(set) var loginCalls = 0
    private(set) var registrationCodeEmails: [String] = []
    private(set) var registerCalls = 0

    func registrationPolicy() async throws -> RegistrationPolicy {
        policy
    }

    func captcha() async throws -> CaptchaChallenge {
        challenge
    }

    func login(
        account: String,
        password: String,
        captcha: CaptchaAnswer?
    ) async throws -> LoginOutcome {
        loginCalls += 1
        return try loginResult.get()
    }

    func sendRegistrationCode(email: String) async throws -> EmailCodeReceipt {
        registrationCodeEmails.append(email)
        return try registrationCodeResult.get()
    }

    func register(
        email: String,
        password: String,
        verificationCode: String,
        invitationCode: String?
    ) async throws -> User {
        registerCalls += 1
        return try registerResult.get()
    }

    func currentSession() async throws -> SessionSnapshot {
        try sessionResult.get()
    }

    func capabilities() async throws -> CapabilitySnapshot {
        try capabilitiesResult.get()
    }

    func logout() async throws {
        if let logoutError {
            throw logoutError
        }
    }
}

final class FakeCatalogService: CatalogService {
    var halls: [DiningHall] = []
    var stallsByHall: [String: [Stall]] = [:]
    var dishesByStall: [String: [DishSummary]] = [:]

    func diningHalls() async throws -> [DiningHall] {
        halls
    }

    func stalls(diningHallID: String) async throws -> [Stall] {
        stallsByHall[diningHallID] ?? []
    }

    func dishes(stallID: String) async throws -> [DishSummary] {
        dishesByStall[stallID] ?? []
    }
}

enum TestFixtures {
    static let baseURL = URL(string: "https://example.test/api/v1/")!
    static let user = User(
        id: "9e55b67f-f051-4019-bafd-a4082c95f2a6",
        email: "20260001@bjtu.edu.cn",
        displayName: "干饭人012345",
        role: "user"
    )

    static func envelope(_ data: String, code: String = "OK", message: String = "success") -> String {
        """
        {"code":"\(code)","message":"\(message)","data":\(data),"timestamp":"2026-11-20T00:00:00Z","requestId":"test-request"}
        """
    }

    static func makeClient(
        transport: StubHTTPTransport,
        jar: MemoryCookieJar
    ) -> APIClient {
        APIClient(baseURL: baseURL, transport: transport, cookieJar: jar)
    }
}

final class FlagBox: @unchecked Sendable {
    var value = false
}
