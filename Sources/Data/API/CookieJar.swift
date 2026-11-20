import Foundation

protocol CookieJar: AnyObject {
    func cookies(for url: URL) -> [HTTPCookie]
    func setCookie(_ cookie: HTTPCookie)
    func deleteCookie(_ cookie: HTTPCookie)
    func hasSessionCookie(for url: URL) -> Bool
    func clearSessionCookies(for url: URL)
}

final class SystemCookieJar: CookieJar {
    static let sessionCookieName = "FOODTIME_SESSION"
    static let deviceCookieName = "foodtime_device"

    private let storage: HTTPCookieStorage

    init(storage: HTTPCookieStorage = .shared) {
        self.storage = storage
    }

    func cookies(for url: URL) -> [HTTPCookie] {
        storage.cookies(for: url) ?? []
    }

    func setCookie(_ cookie: HTTPCookie) {
        storage.setCookie(cookie)
    }

    func deleteCookie(_ cookie: HTTPCookie) {
        storage.deleteCookie(cookie)
    }

    func hasSessionCookie(for url: URL) -> Bool {
        cookies(for: url).contains { cookie in
            cookie.name == Self.sessionCookieName
                && !cookie.value.isEmpty
                && !(cookie.expiresDate.map { $0 <= Date() } ?? false)
        }
    }

    /// Sign-out removes the identity cookie but keeps the installation device
    /// cookie used by login captcha/rate-limit accounting.
    func clearSessionCookies(for url: URL) {
        for cookie in cookies(for: url) where cookie.name == Self.sessionCookieName {
            deleteCookie(cookie)
        }
    }

    func clearAllCookies(for url: URL) {
        for cookie in cookies(for: url) {
            deleteCookie(cookie)
        }
    }
}
