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
