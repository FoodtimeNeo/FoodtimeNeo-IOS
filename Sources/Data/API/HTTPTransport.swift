import Foundation

protocol HTTPTransporting: AnyObject {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

final class URLSessionTransport: HTTPTransporting {
    private let session: URLSession

    init(
        requestTimeout: TimeInterval = 10,
        resourceTimeout: TimeInterval = 180,
        cookieStorage: HTTPCookieStorage = .shared
    ) {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = cookieStorage
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        self.session = URLSession(
            configuration: configuration,
            delegate: NoRedirectDelegate(),
            delegateQueue: nil
        )
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AppError.invalidResponse(message: "服务响应格式异常")
            }
            return (data, http)
        } catch let error as URLError {
            if error.code == .cancelled { throw AppError.cancelled }
            throw AppError.network(message: error.localizedDescription)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.network(message: error.localizedDescription)
        }
    }
}

/// The API never follows redirects: an authenticated request must stay on the
/// configured origin, and a redirect could leak a session header elsewhere.
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
