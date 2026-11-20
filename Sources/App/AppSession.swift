import Foundation
import SwiftUI

enum SessionState: Equatable {
    case launching
    case signedOut
    case signedIn(User)
    case appealOnly(User)
    case unavailable(String)
}

@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var state: SessionState = .launching
    @Published private(set) var capabilities: CapabilitySnapshot = .empty

    let auth: AuthService
    let catalog: CatalogService

    private let api: APIClient
    private let cookieJar: CookieJar
    private let archive: CookieArchiving
    private let baseURL: URL
    private var isStarting = false
    private var isHandlingUnauthorized = false

    init(
        auth: AuthService,
        catalog: CatalogService,
        api: APIClient,
        cookieJar: CookieJar,
        archive: CookieArchiving,
        baseURL: URL
    ) {
        self.auth = auth
        self.catalog = catalog
        self.api = api
        self.cookieJar = cookieJar
        self.archive = archive
        self.baseURL = baseURL
    }

    static func live() -> AppSession {
        let environment = AppEnvironment.live()
        let session = AppSession(
            auth: environment.auth,
            catalog: environment.catalog,
            api: environment.api,
            cookieJar: environment.cookieJar,
            archive: environment.archive,
            baseURL: environment.baseURL
        )
        environment.api.onUnauthorized = { [weak session] in
            await session?.handleUnauthorized()
        }
        return session
    }

    var user: User? {
        switch state {
        case .signedIn(let user), .appealOnly(let user):
            return user
        default:
            return nil
        }
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    var canUseAdminArea: Bool {
        capabilities.canUseAdminArea
    }

    func start() async {
        switch state {
        case .signedIn, .appealOnly:
            return
        default:
            break
        }
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        guard cookieJar.hasSessionCookie(for: baseURL) else {
            state = .signedOut
            return
        }

        state = .launching
        do {
            let snapshot = try await auth.currentSession()
            await apply(snapshot)
        } catch let error as AppError {
            if case .unauthenticated = error {
                await clearLocalSession()
                state = .signedOut
            } else {
                state = .unavailable(error.localizedDescription)
            }
        } catch {
            state = .unavailable(error.localizedDescription)
        }
    }

    func login(account: String, password: String, captcha: CaptchaAnswer?) async throws {
        let outcome = try await auth.login(
            account: account,
            password: password,
            captcha: captcha
        )
        if outcome.mode == .appealOnly {
            capabilities = .empty
            state = .appealOnly(outcome.user)
            return
        }
        state = .signedIn(outcome.user)
        await loadCapabilities()
    }

    func requestCaptcha() async throws -> CaptchaChallenge {
        try await auth.captcha()
    }

    func registrationPolicy() async throws -> RegistrationPolicy {
        try await auth.registrationPolicy()
    }

    func sendRegistrationCode(email: String) async throws -> EmailCodeReceipt {
        try await auth.sendRegistrationCode(email: email)
    }

    func register(
        email: String,
        password: String,
        verificationCode: String,
        invitationCode: String?
    ) async throws -> User {
        try await auth.register(
            email: email,
            password: password,
            verificationCode: verificationCode,
            invitationCode: invitationCode
        )
    }

    func logout() async {
        do {
            try await auth.logout()
        } catch {
            // Local cleanup below is intentional: a failed network logout must
            // not leave a usable session on this device.
        }
        await clearLocalSession()
        capabilities = .empty
        state = .signedOut
    }

    func handleUnauthorized() async {
        guard !isHandlingUnauthorized else { return }
        isHandlingUnauthorized = true
        defer { isHandlingUnauthorized = false }
        await clearLocalSession()
        capabilities = .empty
        state = .signedOut
    }

    func reloadCapabilities() async {
        guard isSignedIn else { return }
        await loadCapabilities()
    }

    private func apply(_ snapshot: SessionSnapshot) async {
        capabilities = .empty
        if snapshot.mode == .appealOnly {
            state = .appealOnly(snapshot.user)
            return
        }
        state = .signedIn(snapshot.user)
        await loadCapabilities()
    }

    private func loadCapabilities() async {
        do {
            capabilities = try await auth.capabilities()
        } catch let error as AppError {
            capabilities = .empty
            if case .unauthenticated = error {
                await handleUnauthorized()
            }
        } catch {
            capabilities = .empty
        }
    }

    private func clearLocalSession() async {
        await api.invalidateSession()
        cookieJar.clearSessionCookies(for: baseURL)
        archive.save(cookies: cookieJar.cookies(for: baseURL), origin: baseURL)
    }
}
