import Foundation

/// 图片/网络缓存的可替换适配器；业务层不直接持有 URLCache。
protocol MediaCacheManaging: AnyObject {
    func usageBytes() async -> Int64
    func clear() async
}
