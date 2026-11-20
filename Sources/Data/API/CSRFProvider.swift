import Foundation

actor CSRFProvider {
    private let fetch: @Sendable () async throws -> CSRFToken
    private var cached: CSRFToken?

    init(fetch: @escaping @Sendable () async throws -> CSRFToken) {
        self.fetch = fetch
    }

    func token(forceRefresh: Bool = false) async throws -> CSRFToken {
        if !forceRefresh, let cached {
            return cached
        }
        let fresh = try await fetch()
        cached = fresh
        return fresh
    }

    func invalidate() {
        cached = nil
    }
}

actor SessionEpoch {
    private var value = UUID()

    func current() -> UUID {
        value
    }

    func rotate() {
        value = UUID()
    }
}
