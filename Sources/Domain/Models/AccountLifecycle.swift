import Foundation

enum AccountLifecycleAction: String, Sendable {
    case delete
    case unbind
}

struct AccountLifecycleSummary: Codable, Equatable, Sendable {
    let verificationEmail: String
    let schoolEmail: String?
    let canDelete: Bool
    let canUnbind: Bool
    let deletionCodeAvailableAt: Date?
}

struct AccountActionReceipt: Codable, Equatable, Sendable {
    let expiresAt: Date?
    let nextSendAt: Date?
    let verificationEmail: String
}

struct AccountDeletionResult: Codable, Equatable, Sendable {
    let deleted: Bool
    let emailsReusableAt: Date?
}

struct SchoolEmailUnbindResult: Codable, Equatable, Sendable {
    let profile: UserProfile
    let schoolEmailReusableAt: Date?
}
