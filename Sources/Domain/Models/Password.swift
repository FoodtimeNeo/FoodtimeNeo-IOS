import Foundation

struct PasswordResetGrant: Equatable, Sendable {
    let resetToken: String
    let expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date()
    }
}
