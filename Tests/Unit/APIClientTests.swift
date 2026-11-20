import XCTest
@testable import FoodtimeNeo

final class APIClientTests: XCTestCase {
    func testDecodesSuccessEnvelopeAndSendsClientHeaders() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            [{"id":"hall-1","name":"第一食堂","coverImageUrl":null,"description":"食堂简介","latitude":null,"longitude":null,"revision":1}]
            """))
        ]
        let client = TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())

        let halls = try await client.send(.get("dining-halls"), as: [DiningHall].self)

        XCTAssertEqual(halls.count, 1)
        XCTAssertEqual(halls[0].name, "第一食堂")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/dining-halls")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Foodtime-Client"), "ios")
        XCTAssertFalse(request.value(forHTTPHeaderField: "X-Request-Id")?.isEmpty ?? true)
    }

    func test204EmptyBodyIsSuccess() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [.init(status: 204)]
        let client = TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())

        try await client.sendVoid(.post("users/me/history/records/abc", requiresCSRF: false))

        XCTAssertEqual(transport.requests.count, 1)
    }

    func testValidationErrorCarriesFieldMessages() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 400, body: """
            {"code":"VALIDATION_ERROR","message":"请求参数校验失败","data":[{"field":"email","message":"邮箱不合法"}],"timestamp":"2026-11-20T00:00:00Z","requestId":"v-1"}
            """)
        ]
        let client = TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())

        do {
            _ = try await client.send(.get("users/me/profile"), as: EmptyPayload.self)
            XCTFail("Expected validation error")
        } catch let error as AppError {
            guard case .validation(let fields) = error else {
                return XCTFail("Expected validation, got \(error)")
            }
            XCTAssertEqual(fields.first?.field, "email")
            XCTAssertEqual(fields.first?.message, "邮箱不合法")
        }
    }

    func test401OnAuthenticatedRequestInvokesHandler() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 401, body: """
            {"code":"UNAUTHENTICATED","message":"请重新登录","data":null,"timestamp":"2026-11-20T00:00:00Z","requestId":"u-1"}
            """)
        ]
        let client = TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        let flag = FlagBox()
        client.onUnauthorized = { flag.value = true }

        do {
            _ = try await client.send(.get("users/me/profile"), as: EmptyPayload.self)
            XCTFail("Expected unauthenticated")
        } catch let error as AppError {
            XCTAssertEqual(error, .unauthenticated)
        }
        XCTAssertTrue(flag.value)
    }

    func testLogin401IsBusinessErrorNotSessionExpiry() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 401, body: """
            {"code":"INVALID_CREDENTIALS","message":"账号或密码错误","data":null,"timestamp":"2026-11-20T00:00:00Z","requestId":"l-1"}
            """)
        ]
        let client = TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())

        do {
            _ = try await client.send(.get("auth/me", requiresAuth: false), as: EmptyPayload.self)
            XCTFail("Expected business error")
        } catch let error as AppError {
            XCTAssertEqual(error.code, "INVALID_CREDENTIALS")
        }
    }

    func test429ExposesRetryAfter() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 429, body: """
            {"code":"LOGIN_RATE_LIMITED","message":"登录尝试过于频繁","data":null,"timestamp":"2026-11-20T00:00:00Z","requestId":"r-1"}
            """, headers: ["Retry-After": "12"])
        ]
        let client = TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())

        do {
            _ = try await client.send(.get("auth/me", requiresAuth: false), as: EmptyPayload.self)
            XCTFail("Expected rate limit")
        } catch let error as AppError {
            XCTAssertEqual(error, .rateLimited(retryAfter: 12))
        }
    }

    func testCSRFFetchIsAttachedToWriteRequest() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-1"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("null"))
        ]
        let client = TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())

        struct Body: Encodable { let account = "user@example.com" }
        let request = try APIRequest.json(.post, "auth/login", body: Body(), requiresAuth: false)
        try await client.sendVoid(request)

        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/auth/csrf")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "X-CSRF-TOKEN"), nil)
        XCTAssertEqual(transport.requests[1].url?.path, "/api/v1/auth/login")
        XCTAssertEqual(transport.requests[1].value(forHTTPHeaderField: "X-CSRF-TOKEN"), "token-1")
    }

    func testMalformedSuccessfulResponseIsInvalidResponse() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [.init(status: 200, body: "not-json")]
        let client = TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())

        do {
            _ = try await client.send(.get("dining-halls"), as: [DiningHall].self)
            XCTFail("Expected invalid response")
        } catch let error as AppError {
            guard case .invalidResponse = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
        }
    }
}
