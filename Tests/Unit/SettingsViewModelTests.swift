import XCTest
@testable import FoodtimeNeo

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testShowsUsageAndClearsCache() async {
        let cache = FakeMediaCache()
        cache.usage = 2_000_000
        let model = SettingsViewModel(
            cache: cache,
            version: AppVersionInfo(version: "2.0.0", build: "24", stage: "β")
        )

        await model.loadCache()
        XCTAssertFalse(model.cacheText.isEmpty)

        await model.clearCache()
        XCTAssertEqual(cache.clearCalls, 1)
        XCTAssertEqual(model.cacheText, "暂无缓存")
        XCTAssertEqual(model.infoMessage, "图片缓存已清理")
    }

    func testReportsIncompleteClear() async {
        let cache = FakeMediaCache()
        cache.usage = 1_000
        cache.keepsUsageAfterClear = true
        let model = SettingsViewModel(
            cache: cache,
            version: AppVersionInfo(version: "1.0.0", build: "1", stage: nil)
        )
        await model.loadCache()

        await model.clearCache()

        XCTAssertEqual(model.errorMessage, "缓存未能完全清理，请稍后重试")
    }

    func testVersionDisplayKeepsStageSuffix() {
        let staged = AppVersionInfo(version: "2.0.0", build: "24", stage: "β")
        let release = AppVersionInfo(version: "1.0.0", build: "1", stage: nil)

        XCTAssertEqual(staged.display, "v2.0.0β（24）")
        XCTAssertEqual(release.display, "v1.0.0（1）")
    }
}

final class FakeMediaCache: MediaCacheManaging {
    var usage: Int64 = 0
    var keepsUsageAfterClear = false
    private(set) var clearCalls = 0

    func usageBytes() async -> Int64 {
        usage
    }

    func clear() async {
        clearCalls += 1
        if !keepsUsageAfterClear {
            usage = 0
        }
    }
}
