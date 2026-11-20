import Foundation

final class RemoteAuthService: AuthService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func registrationPolicy() async throws -> RegistrationPolicy {
        let response: RegistrationPolicyResponse = try await api.send(
            .get("auth/registration-policy", requiresAuth: false),
            as: RegistrationPolicyResponse.self
        )
        guard let mode = RegistrationPolicy.Mode(rawValue: response.mode) else {
            throw AppError.invalidResponse(message: "注册策略响应异常，请稍后重试")
        }
        guard !response.revision.isEmpty else {
            throw AppError.invalidResponse(message: "注册策略响应异常，请稍后重试")
        }
        return RegistrationPolicy(
            mode: mode,
            canSendEmailCode: response.canSendEmailCode,
            invitationRequired: response.invitationRequired,
            revision: response.revision
        )
    }

    func captcha() async throws -> CaptchaChallenge {
        let response: CaptchaResponse = try await api.send(
            .get("auth/captcha", requiresAuth: false),
            as: CaptchaResponse.self
        )
        guard !response.challengeId.isEmpty, !response.imageBase64.isEmpty else {
            throw AppError.invalidResponse(message: "验证码响应异常，请重试")
        }
        return CaptchaChallenge(
            challengeId: response.challengeId,
            imageBase64: response.imageBase64,
            expiresAt: response.expiresAt
        )
    }

    func login(
        account: String,
        password: String,
        captcha: CaptchaAnswer?
    ) async throws -> LoginOutcome {
        var body = LoginBody(
            account: account.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        if let captcha {
            body.challengeId = captcha.challengeId
            body.challengeAnswer = captcha.answer
        }
        let request = try APIRequest.json(
            .post,
            "auth/login",
            body: body,
            requiresAuth: false,
            requiresCSRF: true
        )
        let response: LoginResponse = try await api.send(request, as: LoginResponse.self)
        // Login replaces the whole session; the previous CSRF token is dead.
        _ = try? await api.csrfToken(forceRefresh: true)
        let mode = SessionMode(rawValue: response.sessionMode ?? SessionMode.normal.rawValue) ?? .normal
        return LoginOutcome(user: response.user, mode: mode, expiresAt: response.expiresAt)
    }

    func sendRegistrationCode(email: String) async throws -> EmailCodeReceipt {
        let body = RegistrationCodeBody(email: RegistrationValidation.normalizedEmail(email))
        let request = try APIRequest.json(
            .post,
            "auth/register/email-code",
            body: body,
            requiresAuth: false,
            requiresCSRF: true
        )
        return try await api.send(request, as: EmailCodeReceipt.self)
    }

    func register(
        email: String,
        password: String,
        verificationCode: String,
        invitationCode: String?
    ) async throws -> User {
        let normalizedInvitation = invitationCode.map(RegistrationValidation.normalizedInvitationCode)
        let body = RegistrationBody(
            email: RegistrationValidation.normalizedEmail(email),
            password: password,
            verificationCode: verificationCode.trimmingCharacters(in: .whitespacesAndNewlines),
            invitationCode: normalizedInvitation?.isEmpty == true ? nil : normalizedInvitation
        )
        let request = try APIRequest.json(
            .post,
            "auth/register",
            body: body,
            requiresAuth: false,
            requiresCSRF: true
        )
        return try await api.send(request, as: User.self)
    }

    func sendPasswordResetCode(email: String) async throws -> EmailCodeReceipt {
        let body = PasswordResetCodeBody(email: RegistrationValidation.normalizedEmail(email))
        let request = try APIRequest.json(
            .post,
            "auth/password-reset/email-code",
            body: body,
            requiresAuth: false,
            requiresCSRF: true
        )
        return try await api.send(request, as: EmailCodeReceipt.self)
    }

    func verifyPasswordResetCode(
        email: String,
        verificationCode: String
    ) async throws -> PasswordResetGrant {
        let body = PasswordResetVerifyBody(
            email: RegistrationValidation.normalizedEmail(email),
            verificationCode: verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let request = try APIRequest.json(
            .post,
            "auth/password-reset/verify",
            body: body,
            requiresAuth: false,
            requiresCSRF: true
        )
        let response: PasswordResetGrantResponse = try await api.send(
            request,
            as: PasswordResetGrantResponse.self
        )
        return PasswordResetGrant(resetToken: response.resetToken, expiresAt: response.expiresAt)
    }

    func resetPassword(resetToken: String, newPassword: String) async throws {
        let body = PasswordResetBody(
            resetToken: resetToken.trimmingCharacters(in: .whitespacesAndNewlines),
            newPassword: newPassword
        )
        let request = try APIRequest.json(
            .post,
            "auth/password-reset",
            body: body,
            requiresAuth: false,
            requiresCSRF: true
        )
        try await api.sendVoid(request)
    }

    func changePassword(oldPassword: String, newPassword: String) async throws {
        let body = ChangePasswordBody(oldPassword: oldPassword, newPassword: newPassword)
        let request = try APIRequest.json(
            .put,
            "users/me/password",
            body: body,
            requiresAuth: true,
            requiresCSRF: true
        )
        try await api.sendVoid(request)
    }

    func currentProfile() async throws -> UserProfile {
        try await api.send(.get("users/me/profile"), as: UserProfile.self)
    }

    func updateProfile(displayName: String, avatarUrl: String?) async throws -> UserProfile {
        let body = ProfileUpdateBody(
            displayName: ProfileValidation.normalizedDisplayName(displayName),
            avatarUrl: avatarUrl
        )
        let request = try APIRequest.json(
            .put,
            "users/me/profile",
            body: body,
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: UserProfile.self)
    }

    func accountLifecycle() async throws -> AccountLifecycleSummary {
        try await api.send(
            .get("users/me/account-lifecycle"),
            as: AccountLifecycleSummary.self
        )
    }

    func sendAccountLifecycleCode(
        _ action: AccountLifecycleAction
    ) async throws -> AccountActionReceipt {
        try await api.send(
            .post("users/me/account-lifecycle/\(action.rawValue)-code"),
            as: AccountActionReceipt.self
        )
    }

    func unbindSchoolEmail(verificationCode: String) async throws -> SchoolEmailUnbindResult {
        let body = VerificationCodeBody(
            verificationCode: verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let request = try APIRequest.json(
            .post,
            "users/me/account-lifecycle/unbind",
            body: body,
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: SchoolEmailUnbindResult.self)
    }

    func deleteAccount(verificationCode: String) async throws -> AccountDeletionResult {
        let body = VerificationCodeBody(
            verificationCode: verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let request = try APIRequest.json(
            .post,
            "users/me/account-lifecycle/delete",
            body: body,
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: AccountDeletionResult.self)
    }

    func sendSchoolEmailCode(email: String) async throws -> EmailCodeReceipt {
        let body = SchoolEmailCodeBody(email: SchoolEmailValidation.normalized(email))
        let request = try APIRequest.json(
            .post,
            "auth/bind-email/email-code",
            body: body,
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: EmailCodeReceipt.self)
    }

    func bindSchoolEmail(email: String, verificationCode: String) async throws -> UserProfile {
        let body = BindSchoolEmailBody(
            email: SchoolEmailValidation.normalized(email),
            verificationCode: verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let request = try APIRequest.json(
            .post,
            "users/me/bind-email",
            body: body,
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: UserProfile.self)
    }

    func currentSession() async throws -> SessionSnapshot {
        let response: SessionMeResponse = try await api.send(
            .get("auth/me"),
            as: SessionMeResponse.self
        )
        let mode = SessionMode(rawValue: response.sessionMode ?? SessionMode.normal.rawValue) ?? .normal
        return SessionSnapshot(
            user: User(
                id: response.id,
                email: response.email,
                displayName: response.displayName,
                role: response.role
            ),
            mode: mode
        )
    }

    func capabilities() async throws -> CapabilitySnapshot {
        let response: CapabilitiesResponse = try await api.send(
            .get("users/me/capabilities"),
            as: CapabilitiesResponse.self
        )
        guard !response.revision.isEmpty else {
            throw AppError.invalidResponse(message: "能力响应异常，请稍后重试")
        }
        return CapabilitySnapshot(
            capabilities: response.capabilities,
            revision: response.revision
        )
    }

    func logout() async throws {
        try await api.sendVoid(.post("auth/logout", requiresCSRF: true))
        await api.invalidateSession()
    }
}

private struct RegistrationCodeBody: Encodable {
    let email: String
}

/// PUT /users/me/profile replaces both editable fields. Always encode the
/// avatar key, including null, so a display-name edit never silently clears it
/// when the caller passes the current reference.
private struct ProfileUpdateBody: Encodable {
    let displayName: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case displayName
        case avatarUrl
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        if let avatarUrl {
            try container.encode(avatarUrl, forKey: .avatarUrl)
        } else {
            try container.encodeNil(forKey: .avatarUrl)
        }
    }
}

private struct VerificationCodeBody: Encodable {
    let verificationCode: String
}

private struct SchoolEmailCodeBody: Encodable {
    let email: String
}

private struct BindSchoolEmailBody: Encodable {
    let email: String
    let verificationCode: String
}

private struct PasswordResetCodeBody: Encodable {
    let email: String
}

private struct PasswordResetVerifyBody: Encodable {
    let email: String
    let verificationCode: String
}

private struct PasswordResetBody: Encodable {
    let resetToken: String
    let newPassword: String
}

private struct ChangePasswordBody: Encodable {
    let oldPassword: String
    let newPassword: String
}

private struct PasswordResetGrantResponse: Decodable {
    let resetToken: String
    let expiresAt: Date?
}

private struct RegistrationBody: Encodable {
    let email: String
    let password: String
    let verificationCode: String
    let invitationCode: String?
}

private struct LoginBody: Encodable {
    let account: String
    let password: String
    var challengeId: String?
    var challengeAnswer: String?
}

private struct LoginResponse: Decodable {
    let user: User
    let expiresAt: Date?
    let sessionMode: String?
}

private struct SessionMeResponse: Decodable {
    let id: String
    let email: String
    let displayName: String
    let role: String
    let sessionMode: String?
}

private struct CapabilitiesResponse: Decodable {
    let capabilities: [String]
    let revision: String
}

private struct RegistrationPolicyResponse: Decodable {
    let mode: String
    let canSendEmailCode: Bool
    let invitationRequired: Bool
    let revision: String
}

private struct CaptchaResponse: Decodable {
    let challengeId: String
    let imageBase64: String
    let expiresAt: Date?
}
