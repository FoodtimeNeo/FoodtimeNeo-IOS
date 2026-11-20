import Foundation

protocol CookieArchiving: AnyObject {
    func save(cookies: [HTTPCookie], origin: URL)
    func load(origin: URL) -> [HTTPCookie]
    func clearAll()
}

/// Cookie backup in the Keychain. URLSession still owns live cookies; this
/// archive restores a session after a system cookie purge. The archive is
/// origin-scoped, and the first launch after install clears it because Keychain
/// items can survive app deletion.
final class KeychainCookieArchive: CookieArchiving {
    private let store: KeychainStore

    init(service: String = "cn.edu.bjtu.foodtime.cookies") {
        self.store = KeychainStore(service: service)
    }

    func save(cookies: [HTTPCookie], origin: URL) {
        let records = cookies.compactMap(CookieRecord.init)
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? store.set(data, for: origin.absoluteString)
    }

    func load(origin: URL) -> [HTTPCookie] {
        guard let data = store.data(for: origin.absoluteString),
              let records = try? JSONDecoder().decode([CookieRecord].self, from: data) else {
            return []
        }
        return records.compactMap(\.cookie)
    }

    func clearAll() {
        store.deleteAll()
    }
}

private struct CookieRecord: Codable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let secure: Bool
    let expires: Date?
    let version: Int

    init?(_ cookie: HTTPCookie) {
        guard let domain = cookie.domain, let path = cookie.path, !cookie.name.isEmpty else {
            return nil
        }
        self.name = cookie.name
        self.value = cookie.value
        self.domain = domain
        self.path = path
        self.secure = cookie.isSecure
        self.expires = cookie.expiresDate
        self.version = cookie.version
    }

    var cookie: HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path,
            .version: version
        ]
        if secure {
            properties[.secure] = "TRUE"
        }
        if let expires {
            properties[.expires] = expires
        }
        return HTTPCookie(properties: properties)
    }
}

struct InstallationMarker {
    private let defaults: UserDefaults
    private let key = "foodtime.installation.identifier"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns true exactly once per app installation. The value itself is
    /// not used as an identity; it only decides whether stale Keychain data
    /// from a previous installation must be discarded.
    func consumeFirstLaunch() -> Bool {
        if defaults.string(forKey: key) == nil {
            defaults.set(UUID().uuidString, forKey: key)
            return true
        }
        return false
    }
}
