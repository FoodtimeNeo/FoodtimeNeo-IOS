import Foundation

final class URLCacheMediaCache: MediaCacheManaging {
    private let cache: URLCache

    init(cache: URLCache = .shared) {
        self.cache = cache
    }

    func usageBytes() async -> Int64 {
        Int64(cache.currentDiskUsage) + Int64(cache.currentMemoryUsage)
    }

    func clear() async {
        cache.removeAllCachedResponses()
    }
}
