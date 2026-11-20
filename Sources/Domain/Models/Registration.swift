import Foundation

struct EmailCodeReceipt: Decodable, Equatable, Sendable {
    let expiresAt: Date?
    let resendAfterSeconds: Int
}
