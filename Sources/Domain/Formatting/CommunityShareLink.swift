import Foundation

/// 与 Android 一致的公开分享地址；只接受服务端签发的帖子 UUID。
enum CommunityShareLink {
    static let host = "bjtufoodtime.top"

    static func postURLString(id: String) -> String {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return "https://\(host)/community/posts/\(encoded)"
    }

    static func postURL(id: String) -> URL? {
        URL(string: postURLString(id: id))
    }
}
