import Foundation

struct APIRequest {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    let method: Method
    let path: String
    var query: [URLQueryItem]
    var body: Data?
    var requiresAuth: Bool
    var requiresCSRF: Bool
    var timeout: TimeInterval?
    var contentType: String?

    init(
        method: Method,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        requiresAuth: Bool = true,
        requiresCSRF: Bool = false,
        timeout: TimeInterval? = nil,
        contentType: String? = "application/json"
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.requiresAuth = requiresAuth
        self.requiresCSRF = requiresCSRF
        self.timeout = timeout
        self.contentType = contentType
    }

    static func get(
        _ path: String,
        query: [URLQueryItem] = [],
        requiresAuth: Bool = true
    ) -> APIRequest {
        APIRequest(method: .get, path: path, query: query, requiresAuth: requiresAuth, contentType: nil)
    }

    static func post(
        _ path: String,
        body: Data? = nil,
        requiresAuth: Bool = true,
        requiresCSRF: Bool = true
    ) -> APIRequest {
        APIRequest(
            method: .post,
            path: path,
            body: body,
            requiresAuth: requiresAuth,
            requiresCSRF: requiresCSRF,
            contentType: body == nil ? nil : "application/json"
        )
    }

    static func put(
        _ path: String,
        body: Data? = nil,
        requiresAuth: Bool = true,
        requiresCSRF: Bool = true
    ) -> APIRequest {
        APIRequest(
            method: .put,
            path: path,
            body: body,
            requiresAuth: requiresAuth,
            requiresCSRF: requiresCSRF,
            contentType: body == nil ? nil : "application/json"
        )
    }

    static func delete(
        _ path: String,
        requiresAuth: Bool = true,
        requiresCSRF: Bool = true
    ) -> APIRequest {
        APIRequest(
            method: .delete,
            path: path,
            requiresAuth: requiresAuth,
            requiresCSRF: requiresCSRF,
            contentType: nil
        )
    }

    static func json<T: Encodable>(
        _ method: Method,
        _ path: String,
        body: T,
        requiresAuth: Bool = true,
        requiresCSRF: Bool = true
    ) throws -> APIRequest {
        APIRequest(
            method: method,
            path: path,
            body: try JSONEncoder().encode(body),
            requiresAuth: requiresAuth,
            requiresCSRF: requiresCSRF
        )
    }
}
