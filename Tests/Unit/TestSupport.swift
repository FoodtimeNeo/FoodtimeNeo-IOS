import Foundation
@testable import FoodtimeNeo

final class StubHTTPTransport: HTTPTransporting {
    struct Reply {
        let status: Int
        let body: String
        let headers: [String: String]

        init(status: Int, body: String = "", headers: [String: String] = [:]) {
            self.status = status
            self.body = body
            self.headers = headers
        }
    }

    var replies: [Reply] = []
    var error: Error?
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if let error { throw error }
        guard !replies.isEmpty else {
            throw AppError.network(message: "No stubbed reply")
        }
        let reply = replies.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: reply.status,
            httpVersion: "HTTP/1.1",
            headerFields: reply.headers
        )!
        return (Data(reply.body.utf8), response)
    }
}

final class MemoryCookieJar: CookieJar {
    var stored: [HTTPCookie] = []
    var sessionCookiePresent = false

    func cookies(for url: URL) -> [HTTPCookie] {
        stored
    }

    func setCookie(_ cookie: HTTPCookie) {
        stored.append(cookie)
        if cookie.name == "FOODTIME_SESSION" {
            sessionCookiePresent = true
        }
    }

    func deleteCookie(_ cookie: HTTPCookie) {
        stored.removeAll { $0.name == cookie.name && $0.value == cookie.value }
        if cookie.name == "FOODTIME_SESSION" {
            sessionCookiePresent = false
        }
    }

    func hasSessionCookie(for url: URL) -> Bool {
        sessionCookiePresent
    }

    func clearSessionCookies(for url: URL) {
        stored.removeAll { $0.name == "FOODTIME_SESSION" }
        sessionCookiePresent = false
    }
}

final class MemoryCookieArchive: CookieArchiving {
    private(set) var saved: [HTTPCookie] = []

    func save(cookies: [HTTPCookie], origin: URL) {
        saved = cookies
    }

    func load(origin: URL) -> [HTTPCookie] {
        saved
    }

    func clearAll() {
        saved = []
    }
}

final class FakeAuthService: AuthService {
    var policy = RegistrationPolicy(
        mode: .open,
        canSendEmailCode: true,
        invitationRequired: false,
        revision: "open:email"
    )
    var challenge = CaptchaChallenge(challengeId: "challenge-1", imageBase64: "", expiresAt: nil)
    var loginResult: Result<LoginOutcome, Error> = .failure(AppError.unauthenticated)
    var registrationCodeResult: Result<EmailCodeReceipt, Error> = .success(
        EmailCodeReceipt(expiresAt: nil, resendAfterSeconds: 60)
    )
    var registerResult: Result<User, Error> = .success(TestFixtures.user)
    var passwordResetCodeResult: Result<EmailCodeReceipt, Error> = .success(
        EmailCodeReceipt(expiresAt: nil, resendAfterSeconds: 60)
    )
    var passwordResetVerifyResult: Result<PasswordResetGrant, Error> = .success(
        PasswordResetGrant(
            resetToken: String(repeating: "a", count: 43),
            expiresAt: Date().addingTimeInterval(300)
        )
    )
    var resetPasswordError: Error?
    var changePasswordError: Error?
    var profileResult: Result<UserProfile, Error> = .success(TestFixtures.profile)
    var updateProfileResult: Result<UserProfile, Error> = .success(TestFixtures.profile)
    var accountLifecycleResult: Result<AccountLifecycleSummary, Error> = .success(TestFixtures.accountSummary)
    var accountActionReceiptResult: Result<AccountActionReceipt, Error> = .success(TestFixtures.accountReceipt)
    var unbindResult: Result<SchoolEmailUnbindResult, Error> = .success(TestFixtures.unbindResult)
    var deleteAccountResult: Result<AccountDeletionResult, Error> = .success(TestFixtures.deletionResult)
    var schoolEmailCodeResult: Result<EmailCodeReceipt, Error> = .success(
        EmailCodeReceipt(expiresAt: nil, resendAfterSeconds: 60)
    )
    var bindSchoolEmailResult: Result<UserProfile, Error> = .success(TestFixtures.profile)
    var sessionResult: Result<SessionSnapshot, Error> = .failure(AppError.unauthenticated)
    var capabilitiesResult: Result<CapabilitySnapshot, Error> = .success(.empty)
    var logoutError: Error?
    private(set) var loginCalls = 0
    private(set) var registrationCodeEmails: [String] = []
    private(set) var registerCalls = 0
    private(set) var passwordResetCodeEmails: [String] = []
    private(set) var resetPasswordCalls = 0
    private(set) var changePasswordCalls = 0
    private(set) var updateProfileCalls = 0
    private(set) var lastUpdatedDisplayName: String?
    private(set) var accountActionCodes: [AccountLifecycleAction] = []
    private(set) var bindSchoolEmailCalls = 0
    private(set) var deleteAccountCalls = 0

    func registrationPolicy() async throws -> RegistrationPolicy {
        policy
    }

    func captcha() async throws -> CaptchaChallenge {
        challenge
    }

    func login(
        account: String,
        password: String,
        captcha: CaptchaAnswer?
    ) async throws -> LoginOutcome {
        loginCalls += 1
        return try loginResult.get()
    }

    func sendRegistrationCode(email: String) async throws -> EmailCodeReceipt {
        registrationCodeEmails.append(email)
        return try registrationCodeResult.get()
    }

    func register(
        email: String,
        password: String,
        verificationCode: String,
        invitationCode: String?
    ) async throws -> User {
        registerCalls += 1
        return try registerResult.get()
    }

    func sendPasswordResetCode(email: String) async throws -> EmailCodeReceipt {
        passwordResetCodeEmails.append(email)
        return try passwordResetCodeResult.get()
    }

    func verifyPasswordResetCode(
        email: String,
        verificationCode: String
    ) async throws -> PasswordResetGrant {
        try passwordResetVerifyResult.get()
    }

    func resetPassword(resetToken: String, newPassword: String) async throws {
        resetPasswordCalls += 1
        if let resetPasswordError { throw resetPasswordError }
    }

    func changePassword(oldPassword: String, newPassword: String) async throws {
        changePasswordCalls += 1
        if let changePasswordError { throw changePasswordError }
    }

    func currentProfile() async throws -> UserProfile {
        try profileResult.get()
    }

    func updateProfile(displayName: String, avatarUrl: String?) async throws -> UserProfile {
        updateProfileCalls += 1
        lastUpdatedDisplayName = displayName
        return try updateProfileResult.get()
    }

    func accountLifecycle() async throws -> AccountLifecycleSummary {
        try accountLifecycleResult.get()
    }

    func sendAccountLifecycleCode(
        _ action: AccountLifecycleAction
    ) async throws -> AccountActionReceipt {
        accountActionCodes.append(action)
        return try accountActionReceiptResult.get()
    }

    func unbindSchoolEmail(verificationCode: String) async throws -> SchoolEmailUnbindResult {
        try unbindResult.get()
    }

    func deleteAccount(verificationCode: String) async throws -> AccountDeletionResult {
        deleteAccountCalls += 1
        return try deleteAccountResult.get()
    }

    func sendSchoolEmailCode(email: String) async throws -> EmailCodeReceipt {
        try schoolEmailCodeResult.get()
    }

    func bindSchoolEmail(email: String, verificationCode: String) async throws -> UserProfile {
        bindSchoolEmailCalls += 1
        return try bindSchoolEmailResult.get()
    }

    func currentSession() async throws -> SessionSnapshot {
        try sessionResult.get()
    }

    func capabilities() async throws -> CapabilitySnapshot {
        try capabilitiesResult.get()
    }

    func logout() async throws {
        if let logoutError {
            throw logoutError
        }
    }
}

final class FakeSocialService: SocialService {
    var searchUsersResult: [SocialUser] = []
    var followingResult: [SocialUser] = []
    var followersResult: [SocialUser] = []
    var blockedUsersResult: [BlockedUser] = []
    var followResult = FollowState(followed: true, followerCount: 1)
    var unfollowResult = FollowState(followed: false, followerCount: 0)
    var blockResult = BlockState(blocked: true)
    var unblockResult = BlockState(blocked: false)
    private(set) var followCalls: [String] = []
    private(set) var unfollowCalls: [String] = []
    private(set) var blockCalls: [String] = []
    private(set) var unblockCalls: [String] = []

    func searchUsers(query: String, page: Int, size: Int) async throws -> Page<SocialUser> {
        makePage(searchUsersResult, number: page, size: size)
    }

    func following(userID: String, page: Int, size: Int) async throws -> Page<SocialUser> {
        makePage(followingResult, number: page, size: size)
    }

    func followers(userID: String, page: Int, size: Int) async throws -> Page<SocialUser> {
        makePage(followersResult, number: page, size: size)
    }

    func follow(userID: String) async throws -> FollowState {
        followCalls.append(userID)
        return followResult
    }

    func unfollow(userID: String) async throws -> FollowState {
        unfollowCalls.append(userID)
        return unfollowResult
    }

    func blockedUsers(page: Int, size: Int) async throws -> Page<BlockedUser> {
        Page(
            items: blockedUsersResult,
            total: blockedUsersResult.count,
            page: page,
            size: size
        )
    }

    func block(userID: String) async throws -> BlockState {
        blockCalls.append(userID)
        return blockResult
    }

    func unblock(userID: String) async throws -> BlockState {
        unblockCalls.append(userID)
        return unblockResult
    }

    private func makePage(_ items: [SocialUser], number: Int, size: Int) -> Page<SocialUser> {
        Page(items: items, total: items.count, page: number, size: size)
    }
}

final class FakeFeedbackService: FeedbackService {
    var createResult: Result<Feedback, Error> = .success(TestFixtures.feedback)
    var listResult: Result<Page<Feedback>, Error> = .success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var detailResult: Result<Feedback, Error> = .success(TestFixtures.feedback)
    var repliesResult: Result<Page<FeedbackReply>, Error> = .success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    private(set) var createCalls = 0
    private(set) var lastRequestID: String?

    func create(type: FeedbackType, content: String, requestID: String) async throws -> Feedback {
        createCalls += 1
        lastRequestID = requestID
        return try createResult.get()
    }

    func list(archived: Bool, page: Int, size: Int) async throws -> Page<Feedback> {
        try listResult.get()
    }

    func detail(id: String) async throws -> Feedback {
        try detailResult.get()
    }

    func replies(id: String, page: Int, size: Int) async throws -> Page<FeedbackReply> {
        try repliesResult.get()
    }
}

final class FakeCatalogService: CatalogService {
    let mediaBaseURL = TestFixtures.baseURL
    var halls: [DiningHall] = []
    var stallsByHall: [String: [Stall]] = [:]
    var dishesByStall: [String: [DishSummary]] = [:]
    var searchResult = Page<DishSearchRow>(items: [], total: 0, page: 1, size: 20)
    var detailResult = DishDetail(
        id: "d-1",
        stallId: "s-1",
        stallName: "三号档口",
        diningHallId: "h-1",
        diningHallName: "学苑食堂",
        name: "鸡腿饭",
        description: "好吃",
        price: Decimal(string: "15"),
        revision: 1
    )
    var imagesResult = Page<DishImage>(items: [], total: 0, page: 1, size: 20)
    var ratingResult = DishRatingSummary(averageScore: 4.5, reviewCount: 2)
    var priceHistoryResult = DishPriceHistory(
        dishId: "d-1",
        dishName: "鸡腿饭",
        currentPrice: Decimal(string: "15"),
        priceUnit: "serving",
        revision: 1,
        windowStart: Date(),
        windowEnd: Date(),
        canManage: false,
        totalRecords: 0,
        records: []
    )
    var recommendationsResult = DailyRecommendations(
        date: "2026-11-21",
        algorithmVersion: "FT-HybridRec-v2",
        total: 0,
        items: []
    )
    private(set) var lastSearchFilters: DishSearchFilters?

    func diningHalls() async throws -> [DiningHall] {
        halls
    }

    func stalls(diningHallID: String) async throws -> [Stall] {
        stallsByHall[diningHallID] ?? []
    }

    func dishes(stallID: String) async throws -> [DishSummary] {
        dishesByStall[stallID] ?? []
    }

    func searchDishes(_ filters: DishSearchFilters) async throws -> Page<DishSearchRow> {
        lastSearchFilters = filters
        return searchResult
    }

    func dishDetail(id: String) async throws -> DishDetail {
        detailResult
    }

    func dishImages(id: String, page: Int, size: Int) async throws -> Page<DishImage> {
        imagesResult
    }

    func dishRating(id: String) async throws -> DishRatingSummary {
        ratingResult
    }

    func priceHistory(dishID: String, days: Int) async throws -> DishPriceHistory {
        priceHistoryResult
    }

    func dailyRecommendations() async throws -> DailyRecommendations {
        recommendationsResult
    }
}

enum TestFixtures {
    static let baseURL = URL(string: "https://example.test/api/v1/")!
    static let user = User(
        id: "9e55b67f-f051-4019-bafd-a4082c95f2a6",
        email: "20260001@bjtu.edu.cn",
        displayName: "干饭人012345",
        role: "user"
    )

    static let profile = UserProfile(
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        role: user.role,
        avatarUrl: nil,
        followingCount: 3,
        followerCount: 5,
        schoolEmail: nil,
        schoolEmailVerified: false
    )

    static let accountSummary = AccountLifecycleSummary(
        verificationEmail: user.email,
        schoolEmail: nil,
        canDelete: true,
        canUnbind: false,
        deletionCodeAvailableAt: nil
    )

    static let accountReceipt = AccountActionReceipt(
        expiresAt: Date().addingTimeInterval(900),
        nextSendAt: Date().addingTimeInterval(86400),
        verificationEmail: user.email
    )

    static let unbindResult = SchoolEmailUnbindResult(
        profile: profile,
        schoolEmailReusableAt: Date().addingTimeInterval(3600)
    )

    static let deletionResult = AccountDeletionResult(
        deleted: true,
        emailsReusableAt: Date().addingTimeInterval(3600)
    )

    static let feedback = Feedback(
        id: "fb-1",
        type: "suggestion",
        content: "希望增加收藏分组排序",
        status: "pending",
        createdAt: Date(),
        updatedAt: Date(),
        userDisplayName: user.displayName,
        latestReply: nil
    )

    static func envelope(_ data: String, code: String = "OK", message: String = "success") -> String {
        """
        {"code":"\(code)","message":"\(message)","data":\(data),"timestamp":"2026-11-20T00:00:00Z","requestId":"test-request"}
        """
    }

    static func makeClient(
        transport: StubHTTPTransport,
        jar: MemoryCookieJar
    ) -> APIClient {
        APIClient(baseURL: baseURL, transport: transport, cookieJar: jar)
    }
}

final class FlagBox: @unchecked Sendable {
    var value = false
}
