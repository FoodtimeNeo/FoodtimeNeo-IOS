import Foundation

enum MediaURL {
    /// Media responses may be absolute or same-origin references. Resolve both
    /// against the configured API origin; do not invent a host.
    static func resolve(_ raw: String, baseURL: URL) -> URL? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let url = URL(string: value), url.scheme != nil {
            return url
        }
        return URL(string: value, relativeTo: baseURL)?.absoluteURL
    }
}
