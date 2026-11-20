import Foundation

struct User: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let displayName: String
    let role: String

    var isAdmin: Bool { role == "admin" || role == "superadmin" }
    var isSuperadmin: Bool { role == "superadmin" }
}

enum SessionMode: String, Codable, Sendable {
    case normal
    case appealOnly = "appeal_only"
}

struct SessionSnapshot: Equatable, Sendable {
    let user: User
    let mode: SessionMode
}

struct LoginOutcome: Equatable, Sendable {
    let user: User
    let mode: SessionMode
    let expiresAt: Date?
}

struct CSRFToken: Equatable, Sendable {
    let headerName: String
    let token: String
}

struct CaptchaChallenge: Equatable, Sendable {
    let challengeId: String
    let imageBase64: String
    let expiresAt: Date?
}

struct CaptchaAnswer: Equatable, Sendable {
    let challengeId: String
    let answer: String
}

struct RegistrationPolicy: Equatable, Sendable {
    enum Mode: String, Sendable {
        case open
        case invitation
        case closed
    }

    let mode: Mode
    let canSendEmailCode: Bool
    let invitationRequired: Bool
    let revision: String
}

struct CapabilitySnapshot: Equatable, Sendable {
    let capabilities: [String]
    let revision: String

    static let empty = CapabilitySnapshot(capabilities: [], revision: "")

    func contains(_ capability: String) -> Bool {
        capabilities.contains(capability)
    }

    var canUseAdminArea: Bool {
        contains("moderation.review") || contains("catalog.edit")
    }
}
