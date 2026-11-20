import Foundation

enum AppConfiguration {
    static let productionBaseURL = URL(string: "https://bjtufoodtime.top/api/v1/")!

    /// Production is the default. A simulator/debug build may override the
    /// base URL with the FOODTIME_API_BASE_URL environment variable; release
    /// builds must still be HTTPS.
    static var baseURL: URL {
        if let raw = ProcessInfo.processInfo.environment["FOODTIME_API_BASE_URL"],
           let url = URL(string: raw) {
            return url
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "FoodtimeAPIBaseURL") as? String,
           let url = URL(string: raw) {
            return url
        }
        return productionBaseURL
    }

    static let requestTimeout: TimeInterval = 10
    static let resourceTimeout: TimeInterval = 180
}
