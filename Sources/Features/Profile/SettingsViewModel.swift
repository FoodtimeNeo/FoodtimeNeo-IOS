import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    let version: AppVersionInfo
    @Published private(set) var cacheBytes: Int64 = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isClearing = false
    @Published var infoMessage: String?
    @Published var errorMessage: String?

    private let cache: MediaCacheManaging

    init(cache: MediaCacheManaging, version: AppVersionInfo) {
        self.cache = cache
        self.version = version
    }

    var cacheText: String {
        if isLoading && cacheBytes == 0 {
            return "正在统计…"
        }
        if cacheBytes == 0 {
            return "暂无缓存"
        }
        return ByteCountFormatter.string(fromByteCount: cacheBytes, countStyle: .file)
    }

    func loadCache() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        cacheBytes = await cache.usageBytes()
    }

    func clearCache() async {
        guard !isClearing else { return }
        isClearing = true
        errorMessage = nil
        infoMessage = nil
        defer { isClearing = false }
        await cache.clear()
        cacheBytes = await cache.usageBytes()
        if cacheBytes == 0 {
            infoMessage = "图片缓存已清理"
        } else {
            errorMessage = "缓存未能完全清理，请稍后重试"
        }
    }
}
