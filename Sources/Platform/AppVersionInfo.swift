import Foundation

/// 版本展示信息。iOS 只接受 x.y.z 主版本；α/β 等阶段通过可选配置项展示，
/// 不把测试阶段写成正式版。
struct AppVersionInfo: Equatable {
    let version: String
    let build: String
    let stage: String?

    static func current(bundle: Bundle = .main) -> AppVersionInfo {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let stage = bundle.object(forInfoDictionaryKey: "FoodtimeReleaseStage") as? String
        return AppVersionInfo(
            version: version?.isEmpty == false ? version! : "—",
            build: build?.isEmpty == false ? build! : "—",
            stage: stage?.isEmpty == false ? stage : nil
        )
    }

    var display: String {
        var result = "v\(version)"
        if let stage, !stage.isEmpty {
            result += stage
        }
        return result + "（\(build)）"
    }
}
