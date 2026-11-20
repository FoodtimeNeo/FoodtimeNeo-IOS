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
    @Published private(set) var accountDeletionNotice: String?

    let auth: AuthService
    let catalog: CatalogService
    let social: SocialService
    let feedback: FeedbackService
    let reviews: ReviewService
    let venueReviews: VenueReviewService
    let submissions: SubmissionService
    let community: CommunityService
    let drafts: CommunityDraftStore
    let favorites: FavoriteService
    let history: HistoryService
    let inbox: InboxService
    let messages: MessageService
    let notifications: NotificationService

    private let api: APIClient
    private let cookieJar: CookieJar
    private let archive: CookieArchiving
    private let baseURL: URL
    private var isStarting = false
    private var isHandlingUnauthorized = false

    init(
        auth: AuthService,
        catalog: CatalogService,
        social: SocialService,
        feedback: FeedbackService,
        reviews: ReviewService,
        venueReviews: VenueReviewService,
        submissions: SubmissionService,
        community: CommunityService,
        drafts: CommunityDraftStore,
        favorites: FavoriteService,
        history: HistoryService,
        inbox: InboxService,
        messages: MessageService,
        notifications: NotificationService,
        api: APIClient,
        cookieJar: CookieJar,
        archive: CookieArchiving,
        baseURL: URL
    ) {
        self.auth = auth
        self.catalog = catalog
        self.social = social
        self.feedback = feedback
        self.reviews = reviews
        self.venueReviews = venueReviews
        self.submissions = submissions
        self.community = community
        self.drafts = drafts
        self.favorites = favorites
        self.history = history
        self.inbox = inbox
        self.messages = messages
        self.notifications = notifications
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
            social: environment.social,
            feedback: environment.feedback,
            reviews: environment.reviews,
            venueReviews: environment.venueReviews,
            submissions: environment.submissions,
            community: environment.community,
            drafts: environment.drafts,
            favorites: environment.favorites,
            history: environment.history,
            inbox: environment.inbox,
            messages: environment.messages,
            notifications: environment.notifications,
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

    func sendPasswordResetCode(email: String) async throws -> EmailCodeReceipt {
        try await auth.sendPasswordResetCode(email: email)
    }

    func verifyPasswordResetCode(
        email: String,
        verificationCode: String
    ) async throws -> PasswordResetGrant {
        try await auth.verifyPasswordResetCode(email: email, verificationCode: verificationCode)
    }

    func resetPassword(resetToken: String, newPassword: String) async throws {
        try await auth.resetPassword(resetToken: resetToken, newPassword: newPassword)
    }

    func changePassword(oldPassword: String, newPassword: String) async throws {
        try await auth.changePassword(oldPassword: oldPassword, newPassword: newPassword)
        await clearLocalSession()
        capabilities = .empty
        state = .signedOut
    }

    /// Best-effort after a successful detail load. Epoch-stale events are never
    /// retried with a new epoch; the next real detail visit creates a new event.
    func recordHistory(kind: HistoryKind, targetID: String) async {
        do {
            let settings = try await history.settings()
            guard settings.enabled else { return }
            try await history.record(
                kind: kind,
                targetID: targetID,
                epoch: settings.epoch(for: kind),
                visitEventID: UUID().uuidString
            )
        } catch {
            // History failure must not block or fail detail browsing.
        }
    }

    func currentProfile() async throws -> UserProfile {
        try await auth.currentProfile()
    }

    func updateProfile(displayName: String, avatarUrl: String?) async throws -> UserProfile {
        let updated = try await auth.updateProfile(
            displayName: displayName,
            avatarUrl: avatarUrl
        )
        state = .signedIn(updated.asUser)
        return updated
    }

    func accountLifecycle() async throws -> AccountLifecycleSummary {
        try await auth.accountLifecycle()
    }

    func sendAccountLifecycleCode(_ action: AccountLifecycleAction) async throws -> AccountActionReceipt {
        try await auth.sendAccountLifecycleCode(action)
    }

    func unbindSchoolEmail(verificationCode: String) async throws -> SchoolEmailUnbindResult {
        let result = try await auth.unbindSchoolEmail(verificationCode: verificationCode)
        state = .signedIn(result.profile.asUser)
        return result
    }

    func deleteAccount(verificationCode: String) async throws -> AccountDeletionResult {
        let deletingUserID = user?.id
        let result = try await auth.deleteAccount(verificationCode: verificationCode)
        if let deletingUserID {
            drafts.clear(accountID: deletingUserID)
        }
        await clearLocalSession()
        capabilities = .empty
        if let reusableAt = result.emailsReusableAt {
            accountDeletionNotice = "账号已注销。登录邮箱与学校邮箱可在 \(DisplayFormat.dateTime(reusableAt)) 后重新使用；新账号不继承旧数据。"
        } else {
            accountDeletionNotice = "账号已注销。旧内容显示为已注销用户，新账号不继承旧数据。"
        }
        state = .signedOut
        return result
    }

    func sendSchoolEmailCode(email: String) async throws -> EmailCodeReceipt {
        try await auth.sendSchoolEmailCode(email: email)
    }

    func bindSchoolEmail(email: String, verificationCode: String) async throws -> UserProfile {
        let profile = try await auth.bindSchoolEmail(
            email: email,
            verificationCode: verificationCode
        )
        state = .signedIn(profile.asUser)
        return profile
    }

    func clearAccountDeletionNotice() {
        accountDeletionNotice = nil
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
