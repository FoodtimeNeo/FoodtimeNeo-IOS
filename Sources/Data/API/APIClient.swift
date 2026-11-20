import Foundation

final class APIClient {
    typealias UnauthorizedHandler = @Sendable () async -> Void

    private let baseURL: URL
    private let transport: HTTPTransporting
    private let decoder: JSONDecoder
    private let epoch = SessionEpoch()

    let cookieJar: CookieJar
    var onUnauthorized: UnauthorizedHandler?
    var onCookiesChanged: (@Sendable ([HTTPCookie]) -> Void)?

    private lazy var csrfProvider = CSRFProvider { [weak self] in
        guard let self else { throw AppError.unavailable(message: "网络层已释放") }
        return try await self.fetchCSRF()
    }

    init(baseURL: URL, transport: HTTPTransporting, cookieJar: CookieJar) {
        self.baseURL = baseURL
        self.transport = transport
        self.cookieJar = cookieJar

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = FoodtimeDate.parse(raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO 8601 date: \(raw)"
                )
            }
            return date
        }
        self.decoder = decoder
    }

    func send<T: Decodable>(_ request: APIRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await perform(request)
        return try decode(T.self, data: data, response: response, request: request).value
    }

    func sendVoid(_ request: APIRequest) async throws {
        let (data, response) = try await perform(request)
        if response.statusCode == 204 || response.statusCode == 205 {
            return
        }
        _ = try decode(EmptyPayload.self, data: data, response: response, request: request)
    }

    func csrfToken(forceRefresh: Bool = false) async throws -> CSRFToken {
        try await csrfProvider.token(forceRefresh: forceRefresh)
    }

    /// Called on logout, 401 and account changes. Rotating the epoch makes
    /// responses from the previous session fail as stale instead of leaking
    /// into the next account.
    func invalidateSession() async {
        await epoch.rotate()
        await csrfProvider.invalidate()
        cookieJar.clearSessionCookies(for: baseURL)
        // Images and API responses cached under the previous account must not
        // survive sign-out, 401 or account deletion. Clearing the shared cache
        // is intentional; per-account media is re-fetched after the next login.
        URLCache.shared.removeAllCachedResponses()
        onCookiesChanged?(cookieJar.cookies(for: baseURL))
    }

    private func fetchCSRF() async throws -> CSRFToken {
        let request = APIRequest.get("auth/csrf", requiresAuth: false)
        let (data, response) = try await perform(request, manageCSRF: false)
        let envelope: APIEnvelope<CSRFResponse> = try decodeEnvelope(
            data: data,
            response: response,
            request: request
        )
        guard (200..<300).contains(response.statusCode), envelope.code == "OK",
              let payload = envelope.data else {
            if (200..<300).contains(response.statusCode) {
                throw AppError.invalidResponse(message: "CSRF 响应缺少数据")
            }
            throw mapError(
                status: response.statusCode,
                code: envelope.code,
                message: envelope.message,
                data: data,
                request: request,
                response: response
            )
        }
        return CSRFToken(
            headerName: payload.headerName.isEmpty ? "X-CSRF-TOKEN" : payload.headerName,
            token: payload.token
        )
    }

    private func perform(
        _ request: APIRequest,
        manageCSRF: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        let url = try makeURL(for: request)
        var urlRequest = URLRequest(url: url, timeoutInterval: request.timeout ?? 10)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("ios", forHTTPHeaderField: "X-Foodtime-Client")
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")
        if request.body != nil, let contentType = request.contentType {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if manageCSRF, request.requiresCSRF {
            let csrf = try await csrfProvider.token()
            urlRequest.setValue(csrf.token, forHTTPHeaderField: csrf.headerName)
        }
        urlRequest.httpBody = request.body

        let epochBefore = await epoch.current()
        let (data, response) = try await transport.send(urlRequest)

        if response.value(forHTTPHeaderField: "Set-Cookie") != nil {
            onCookiesChanged?(cookieJar.cookies(for: baseURL))
        }
        if response.statusCode == 401, request.requiresAuth {
            await onUnauthorized?()
            throw AppError.unauthenticated
        }
        if response.statusCode == 403 {
            await csrfProvider.invalidate()
        }
        guard await epoch.current() == epochBefore else {
            throw AppError.staleSession
        }
        return (data, response)
    }

    private func makeURL(for request: APIRequest) throws -> URL {
        let path = request.path.hasPrefix("/") ? String(request.path.dropFirst()) : request.path
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw AppError.invalidResponse(message: "请求地址无效")
        }
        let basePath = components.path.hasSuffix("/") ? components.path : components.path + "/"
        components.path = basePath + path
        if !request.query.isEmpty {
            components.queryItems = request.query
        }
        guard let url = components.url,
              url.scheme?.lowercased() == baseURL.scheme?.lowercased(),
              url.host?.lowercased() == baseURL.host?.lowercased() else {
            throw AppError.invalidResponse(message: "请求地址无效")
        }
        return url
    }

    private func decode<T: Decodable>(
        _ type: T.Type,
        data: Data,
        response: HTTPURLResponse,
        request: APIRequest
    ) throws -> (value: T, requestId: String?) {
        if response.statusCode == 204 || response.statusCode == 205 {
            if let empty = EmptyPayload() as? T {
                return (empty, nil)
            }
            throw AppError.invalidResponse(message: "服务未返回数据")
        }

        let envelope: APIEnvelope<T> = try decodeEnvelope(
            data: data,
            response: response,
            request: request
        )
        guard (200..<300).contains(response.statusCode), envelope.code == "OK" else {
            throw mapError(
                status: response.statusCode,
                code: envelope.code,
                message: envelope.message,
                data: data,
                request: request,
                response: response
            )
        }
        guard let value = envelope.data else {
            if let empty = EmptyPayload() as? T {
                return (empty, envelope.requestId)
            }
            throw AppError.invalidResponse(message: "服务响应缺少数据")
        }
        return (value, envelope.requestId)
    }

    private func decodeEnvelope<T: Decodable>(
        data: Data,
        response: HTTPURLResponse,
        request: APIRequest
    ) throws -> APIEnvelope<T> {
        do {
            return try decoder.decode(APIEnvelope<T>.self, from: data)
        } catch {
            if (200..<300).contains(response.statusCode) {
                throw AppError.invalidResponse(message: "服务响应格式异常")
            }
            let fallback = try? decoder.decode(ErrorEnvelope.self, from: data)
            throw mapError(
                status: response.statusCode,
                code: fallback?.code,
                message: fallback?.message ?? "请求失败（\(response.statusCode)）",
                data: data,
                request: request,
                response: response
            )
        }
    }

    private func mapError(
        status: Int,
        code: String?,
        message: String,
        data: Data,
        request: APIRequest,
        response: HTTPURLResponse
    ) -> AppError {
        let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
        if status == 400, code == "VALIDATION_ERROR",
           let validation = try? decoder.decode(ValidationEnvelope.self, from: data) {
            return .validation(validation.data ?? [])
        }
        switch status {
        case 401:
            return request.requiresAuth
                ? .unauthenticated
                : .business(code: code ?? "UNAUTHENTICATED", message: message)
        case 403:
            return .forbidden(code: code, message: message)
        case 429:
            return .rateLimited(retryAfter: retryAfter)
        case 503:
            return .unavailable(message: message)
        default:
            if let code {
                return .business(code: code, message: message)
            }
            return .unknown(message: message)
        }
    }
}

private struct CSRFResponse: Decodable {
    let headerName: String
    let token: String
}
