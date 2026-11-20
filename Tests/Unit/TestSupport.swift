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
    var blockStateResult = BlockState(blocked: false)
    private(set) var followCalls: [String] = []
    private(set) var unfollowCalls: [String] = []
    private(set) var blockCalls: [String] = []
    private(set) var unblockCalls: [String] = []
    private(set) var blockStateCalls: [String] = []

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

    func blockState(userID: String) async throws -> BlockState {
        blockStateCalls.append(userID)
        return blockStateResult
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

final class FakeReviewService: ReviewService {
    var reviewsResult: Result<Page<Review>, Error> = .success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var submitResult: Result<ReviewCreatedReceipt, Error> = .success(TestFixtures.reviewReceipt)
    var myReviewsResult: Result<Page<Review>, Error> = .success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var mySubmissionsResult: Result<Page<ReviewSubmission>, Error> = .success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var deleteError: Error?
    var likeResult = ReviewLikeState(likedByMe: true, likeCount: 1, counterVersion: 1)
    var repliesResult = ReviewReplyPage(items: [], total: 0, hasMore: false, nextCursor: nil)
    var submitReplyResult: Result<ReviewReplyCreatedReceipt, Error> = .success(
        ReviewReplyCreatedReceipt(id: "rr-1", status: "pending", createdAt: Date())
    )
    var myRepliesResult: Result<Page<ReviewReply>, Error> = .success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var deleteReplyError: Error?
    private(set) var submitCalls = 0
    private(set) var likeCalls: [String] = []
    private(set) var replyLikeCalls: [String] = []

    func reviews(dishID: String, page: Int, size: Int) async throws -> Page<Review> {
        try reviewsResult.get()
    }

    func submitReview(dishID: String, rating: Int, content: String) async throws -> ReviewCreatedReceipt {
        submitCalls += 1
        return try submitResult.get()
    }

    func myReviews(page: Int, size: Int) async throws -> Page<Review> {
        try myReviewsResult.get()
    }

    func myReviewSubmissions(page: Int, size: Int) async throws -> Page<ReviewSubmission> {
        try mySubmissionsResult.get()
    }

    func deleteMyReview(id: String) async throws {
        if let deleteError { throw deleteError }
    }

    func setReviewLike(id: String, liked: Bool) async throws -> ReviewLikeState {
        likeCalls.append(id)
        return likeResult
    }

    func replies(reviewID: String, size: Int, cursor: String?) async throws -> ReviewReplyPage {
        repliesResult
    }

    func submitReply(
        reviewID: String,
        content: String,
        replyToID: String?,
        requestID: String
    ) async throws -> ReviewReplyCreatedReceipt {
        try submitReplyResult.get()
    }

    func myReplies(page: Int, size: Int) async throws -> Page<ReviewReply> {
        try myRepliesResult.get()
    }

    func deleteReply(id: String) async throws {
        if let deleteReplyError { throw deleteReplyError }
    }

    func setReplyLike(id: String, liked: Bool) async throws -> ReviewLikeState {
        replyLikeCalls.append(id)
        return likeResult
    }
}

final class FakeAdminService: AdminService {
    var dashboardResult = Result<AdminDashboard, Error>.success(
        AdminDashboard(
            totalUsers: 1,
            registeredUsers: 1,
            onlineUsers: 1,
            reviews: 0,
            replies: 0,
            posts: 0,
            halls: 1,
            stalls: 1,
            dishes: 1,
            generatedAt: Date(),
            trend: []
        )
    )
    var usersResult = Result<Page<AdminUser>, Error>.success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var updateError: Error?
    private(set) var updateCalls = 0

    func dashboard(days: Int) async throws -> AdminDashboard {
        try dashboardResult.get()
    }

    func users(query: String, page: Int, size: Int) async throws -> Page<AdminUser> {
        try usersResult.get()
    }

    func updateUser(id: String, role: String, status: String) async throws {
        updateCalls += 1
        if let updateError { throw updateError }
    }
}

final class FakeHistoryService: HistoryService {
    var settingsResult = Result<BrowsingHistorySettings, Error>.success(
        BrowsingHistorySettings(enabled: true, revision: 1, dishEpoch: 0, postEpoch: 0)
    )
    var updateResult = Result<BrowsingHistorySettings, Error>.success(
        BrowsingHistorySettings(enabled: false, revision: 2, dishEpoch: 1, postEpoch: 1)
    )
    var listResult = Result<Page<BrowsingHistoryItem>, Error>.success(
        Page(items: [], total: 0, page: 1, size: 50)
    )
    var deleteError: Error?
    var clearError: Error?
    var recordError: Error?
    private(set) var recordCalls: [(HistoryKind, String, Int)] = []

    func settings() async throws -> BrowsingHistorySettings {
        try settingsResult.get()
    }

    func updateSettings(enabled: Bool, expectedRevision: Int) async throws -> BrowsingHistorySettings {
        try updateResult.get()
    }

    func list(kind: HistoryKind, page: Int, size: Int) async throws -> Page<BrowsingHistoryItem> {
        try listResult.get()
    }

    func record(
        kind: HistoryKind,
        targetID: String,
        epoch: Int,
        visitEventID: String
    ) async throws {
        recordCalls.append((kind, targetID, epoch))
        if let recordError { throw recordError }
    }

    func deleteOne(kind: HistoryKind, targetID: String) async throws {
        if let deleteError { throw deleteError }
    }

    func clear(kind: HistoryKind) async throws {
        if let clearError { throw clearError }
    }
}

final class FakeFavoriteService: FavoriteService {
    var groupsResult: Result<[FavoriteGroup], Error> = .success([])
    var createResult = Result<FavoriteGroup, Error>.success(
        FavoriteGroup(id: "g-1", kind: "dish", name: "默认分组", sortOrder: 0, revision: 1, itemCount: 0)
    )
    var updateResult = Result<FavoriteGroup, Error>.success(
        FavoriteGroup(id: "g-1", kind: "dish", name: "默认分组", sortOrder: 0, revision: 2, itemCount: 0)
    )
    var deleteError: Error?
    var membership: [String] = []
    var dishFavoritesResult = Result<Page<DishSearchRow>, Error>.success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var communityFavoritesResult = Result<Page<CommunityPost>, Error>.success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var savedState = true

    func groups(kind: FavoriteKind) async throws -> [FavoriteGroup] {
        try groupsResult.get()
    }

    func createGroup(kind: FavoriteKind, name: String, sortOrder: Int?) async throws -> FavoriteGroup {
        try createResult.get()
    }

    func updateGroup(
        id: String,
        name: String?,
        sortOrder: Int?,
        expectedRevision: Int?
    ) async throws -> FavoriteGroup {
        try updateResult.get()
    }

    func deleteGroup(id: String) async throws {
        if let deleteError { throw deleteError }
    }

    func memberships(kind: FavoriteKind, targetID: String) async throws -> [String] {
        membership
    }

    func addMember(groupID: String, targetID: String) async throws -> [String] {
        membership.append(groupID)
        return membership
    }

    func removeMember(groupID: String, targetID: String) async throws -> [String] {
        membership.removeAll { $0 == groupID }
        return membership
    }

    func dishFavorites(
        groupID: String?,
        unfiled: Bool,
        page: Int,
        size: Int
    ) async throws -> Page<DishSearchRow> {
        try dishFavoritesResult.get()
    }

    func communityFavorites(
        groupID: String?,
        unfiled: Bool,
        page: Int,
        size: Int
    ) async throws -> Page<CommunityPost> {
        try communityFavoritesResult.get()
    }

    func dishFavoriteState(dishID: String) async throws -> Bool {
        savedState
    }

    func setDishFavorite(dishID: String, favorited: Bool) async throws -> Bool {
        savedState = favorited
        return savedState
    }
}

final class MemoryDraftStore: CommunityDraftStore {
    private var drafts: [String: CommunityDraft] = [:]
    private var images: [String: Data] = [:]

    func load(accountID: String) -> CommunityDraft? {
        drafts[accountID]
    }

    func save(_ draft: CommunityDraft, accountID: String) {
        drafts[accountID] = draft
    }

    func saveImage(_ data: Data, accountID: String) -> String? {
        let name = UUID().uuidString
        images["\(accountID):\(name)"] = data
        return name
    }

    func imageData(named: String, accountID: String) -> Data? {
        images["\(accountID):\(named)"]
    }

    func clear(accountID: String) {
        drafts[accountID] = nil
        images = images.filter { !$0.key.hasPrefix("\(accountID):") }
    }
}

final class FakeCommunityService: CommunityService {
    var feedResult = CommunityFeedPage(
        items: [],
        total: 0,
        hasMore: false,
        nextCursor: nil,
        pins: nil
    )
    var detailResult = TestFixtures.communityPost
    var rootsResult = CommunityCommentPage(items: [], total: 0, hasMore: false, nextCursor: nil)
    var repliesResult = CommunityCommentPage(items: [], total: 0, hasMore: false, nextCursor: nil)
    var commentResult = TestFixtures.communityComment
    var likeResult = CommunityLikeState(
        liked: nil, likedByMe: true, likeCount: 1, favorited: nil,
        favoritedByMe: nil, favoriteCount: nil, counterVersion: 1
    )
    var viewCount = 1
    var createPostResult = CommunityPostReceipt(id: "post-2")
    var editPostResult = CommunityEditReceipt(id: "post-1", revision: 2, changed: true)
    var pinsResult = CommunityPinSnapshot(revision: 1, items: [], canManage: false)
    private(set) var commentCalls = 0
    private(set) var createPostCalls = 0
    private(set) var editPostCalls = 0
    private(set) var likeCalls: [String] = []

    func feed(
        size: Int,
        cursor: String?,
        following: Bool,
        query: String,
        pinRevision: Int?
    ) async throws -> CommunityFeedPage {
        feedResult
    }

    func detail(id: String) async throws -> CommunityPost {
        detailResult
    }

    func roots(postID: String, size: Int, cursor: String?) async throws -> CommunityCommentPage {
        rootsResult
    }

    func replies(
        postID: String,
        rootID: String,
        size: Int,
        cursor: String?
    ) async throws -> CommunityCommentPage {
        repliesResult
    }

    func submitComment(
        postID: String,
        content: String,
        rootID: String?,
        replyToID: String?,
        requestID: String
    ) async throws -> CommunityComment {
        commentCalls += 1
        return commentResult
    }

    func likePost(id: String, liked: Bool) async throws -> CommunityLikeState {
        likeCalls.append(id)
        return likeResult
    }

    func favoritePost(id: String, favorited: Bool) async throws -> CommunityLikeState {
        likeResult
    }

    func likeComment(id: String, liked: Bool) async throws -> CommunityLikeState {
        likeResult
    }

    func recordView(postID: String, requestID: String) async throws -> Int {
        viewCount
    }

    func createPost(
        title: String,
        content: String,
        imageURLs: [String],
        requestID: String
    ) async throws -> CommunityPostReceipt {
        createPostCalls += 1
        return createPostResult
    }

    func editPost(
        id: String,
        expectedRevision: Int,
        title: String,
        content: String,
        imageURLs: [String],
        requestID: String
    ) async throws -> CommunityEditReceipt {
        editPostCalls += 1
        return editPostResult
    }

    func pins(manage: Bool) async throws -> CommunityPinSnapshot {
        pinsResult
    }

    func pin(postID: String, expectedRevision: Int) async throws -> CommunityPinSnapshot {
        pinsResult
    }

    func unpin(postID: String, expectedRevision: Int) async throws -> CommunityPinSnapshot {
        pinsResult
    }

    func reorderPins(postIDs: [String], expectedRevision: Int) async throws -> CommunityPinSnapshot {
        pinsResult
    }
}

final class FakeSubmissionService: SubmissionService {
    var uploadResult = Result<UploadedImage, Error>.success(TestFixtures.uploadedImage)
    var submitResult = Result<ImageSubmission, Error>.success(TestFixtures.imageSubmission)
    var myResult = Result<Page<ImageSubmission>, Error>.success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var dishSubmitResult = Result<CatalogSubmissionReceipt, Error>.success(
        CatalogSubmissionReceipt(id: "ds-1", status: "pending", createdAt: Date())
    )
    var stallSubmitResult = Result<CatalogSubmissionReceipt, Error>.success(
        CatalogSubmissionReceipt(id: "ss-1", status: "pending", createdAt: Date())
    )
    var myDishResult = Result<Page<DishSubmission>, Error>.success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var myStallResult = Result<Page<StallSubmission>, Error>.success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    private(set) var uploadCalls = 0
    private(set) var submitCalls = 0
    private(set) var dishSubmitCalls = 0
    private(set) var stallSubmitCalls = 0

    func uploadImage(_ jpegData: Data) async throws -> UploadedImage {
        uploadCalls += 1
        return try uploadResult.get()
    }

    func submitDishImage(dishID: String, imageURL: String) async throws -> ImageSubmission {
        submitCalls += 1
        return try submitResult.get()
    }

    func myImageSubmissions(page: Int, size: Int) async throws -> Page<ImageSubmission> {
        try myResult.get()
    }

    func submitDish(
        stallID: String,
        name: String,
        description: String?,
        price: Decimal?,
        imageURL: String
    ) async throws -> CatalogSubmissionReceipt {
        dishSubmitCalls += 1
        return try dishSubmitResult.get()
    }

    func submitStall(
        hallID: String,
        name: String,
        description: String?,
        coverImageURL: String
    ) async throws -> CatalogSubmissionReceipt {
        stallSubmitCalls += 1
        return try stallSubmitResult.get()
    }

    func myDishSubmissions(page: Int, size: Int) async throws -> Page<DishSubmission> {
        try myDishResult.get()
    }

    func myStallSubmissions(page: Int, size: Int) async throws -> Page<StallSubmission> {
        try myStallResult.get()
    }
}

final class FakeVenueReviewService: VenueReviewService {
    var targetResult = VenueRatingTarget(
        type: "hall",
        targetId: "h-1",
        name: "学苑食堂",
        diningHallId: "h-1",
        stallId: nil,
        averageScore: 4.5,
        reviewCount: 2
    )
    var reviewsResult = VenueReviewPage(items: [], total: 0, hasMore: false, nextCursor: nil)
    var mineResult = VenueReviewMine(publicVersion: nil, privateSubmission: nil)
    var submitResult = TestFixtures.venueReview
    var likeResult = ReviewLikeState(likedByMe: true, likeCount: 1, counterVersion: 1)
    private(set) var submitCalls = 0

    func target(type: VenueTargetType, id: String) async throws -> VenueRatingTarget {
        targetResult
    }

    func reviews(
        type: VenueTargetType,
        id: String,
        rating: String,
        cursor: String?,
        size: Int
    ) async throws -> VenueReviewPage {
        reviewsResult
    }

    func mine(type: VenueTargetType, id: String) async throws -> VenueReviewMine {
        mineResult
    }

    func submit(
        type: VenueTargetType,
        id: String,
        rating: Int,
        content: String,
        requestID: String
    ) async throws -> VenueReview {
        submitCalls += 1
        return submitResult
    }

    func setLike(reviewID: String, liked: Bool) async throws -> ReviewLikeState {
        likeResult
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

final class FakeInboxService: InboxService {
    var noticesResult = Result<Page<Notice>, Error>.success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var messagesResult = Result<Page<InboxMessage>, Error>.success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var noticeUnread = 0
    var messageUnread = 0
    private(set) var readNoticeIDs: [String] = []
    private(set) var readMessageIDs: [String] = []
    private(set) var markAllCalls = 0

    func notices(page: Int, size: Int) async throws -> Page<Notice> {
        try noticesResult.get()
    }

    func markNoticeRead(id: String) async throws {
        readNoticeIDs.append(id)
    }

    func unreadNoticeCount() async throws -> Int {
        noticeUnread
    }

    func messages(page: Int, size: Int) async throws -> Page<InboxMessage> {
        try messagesResult.get()
    }

    func markMessageRead(id: String) async throws {
        readMessageIDs.append(id)
    }

    func markAllMessagesRead() async throws {
        markAllCalls += 1
    }

    func unreadMessageCount() async throws -> Int {
        messageUnread
    }
}

final class FakeMessageService: MessageService {
    var conversationsResult = Result<Page<Conversation>, Error>.success(
        Page(items: [], total: 0, page: 1, size: 20)
    )
    var unread = 0
    var conversationResult = Result<Conversation, Error>.success(TestFixtures.conversation)
    var messagePageResult = Result<DirectMessagePage, Error>.success(
        DirectMessagePage(items: [], hasMore: false, nextCursor: nil)
    )
    var startResult = Result<Conversation, Error>.success(TestFixtures.conversation)
    var sendHandler: (String, String, String) throws -> DirectMessage = { _, content, requestID in
        DirectMessage(
            id: "dm-\(requestID)",
            conversationId: TestFixtures.conversation.id,
            senderId: TestFixtures.user.id,
            content: content,
            createdAt: Date()
        )
    }
    private(set) var sent: [(conversationID: String, content: String, requestID: String)] = []
    private(set) var readConversationIDs: [String] = []
    private(set) var hiddenConversationIDs: [String] = []
    private(set) var startCalls: [String] = []

    func conversations(page: Int, size: Int) async throws -> Page<Conversation> {
        try conversationsResult.get()
    }

    func unreadCount() async throws -> Int {
        unread
    }

    func conversation(id: String) async throws -> Conversation {
        try conversationResult.get()
    }

    func startConversation(userID: String) async throws -> Conversation {
        startCalls.append(userID)
        return try startResult.get()
    }

    func messages(
        conversationID: String,
        size: Int,
        cursor: String?
    ) async throws -> DirectMessagePage {
        try messagePageResult.get()
    }

    func send(conversationID: String, content: String, requestID: String) async throws -> DirectMessage {
        sent.append((conversationID, content, requestID))
        return try sendHandler(conversationID, content, requestID)
    }

    func markRead(conversationID: String) async throws {
        readConversationIDs.append(conversationID)
    }

    func hide(conversationID: String) async throws {
        hiddenConversationIDs.append(conversationID)
    }
}

final class FakeNotificationService: NotificationService {
    var preferencesResult = Result<NotificationPreferences, Error>.success(
        NotificationPreferences(items: [])
    )
    var updateResult: Result<NotificationPreference, Error>?
    var updateHandler: (String, Bool, Int) throws -> NotificationPreference = { category, enabled, revision in
        NotificationPreference(category: category, enabled: enabled, revision: revision + 1)
    }
    private(set) var updates: [(category: String, enabled: Bool, revision: Int)] = []
    private(set) var preferenceCalls = 0

    func preferences() async throws -> NotificationPreferences {
        preferenceCalls += 1
        return try preferencesResult.get()
    }

    func update(
        category: String,
        enabled: Bool,
        expectedRevision: Int
    ) async throws -> NotificationPreference {
        updates.append((category, enabled, expectedRevision))
        if let updateResult {
            return try updateResult.get()
        }
        return try updateHandler(category, enabled, expectedRevision)
    }
}

@MainActor
final class FakeNotificationAuthorizer: NotificationAuthorizing {
    var currentStatus: NotificationPermissionStatus = .authorized
    var requestResult = Result<Bool, Error>.success(true)
    var statusAfterRequest: NotificationPermissionStatus?
    private(set) var requestCalls = 0
    private(set) var settingsOpened = 0

    func status() async -> NotificationPermissionStatus {
        currentStatus
    }

    func requestAuthorization() async throws -> Bool {
        requestCalls += 1
        let granted = try requestResult.get()
        if granted, let statusAfterRequest {
            currentStatus = statusAfterRequest
        }
        return granted
    }

    func openSystemSettings() {
        settingsOpened += 1
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

    static let reviewReceipt = ReviewCreatedReceipt(
        id: "sub-1",
        dishId: "d-1",
        rating: 5,
        content: "好吃",
        status: "pending",
        submittedAt: Date()
    )

    static let communityPost = CommunityPost(
        id: "post-1",
        userId: user.id,
        userDisplayName: user.displayName,
        title: "今天吃什么",
        content: "食堂新菜",
        imageUrls: [],
        images: [],
        likeCount: 1,
        commentCount: 0,
        repostCount: 0,
        repostOfId: nil,
        repost: nil,
        likedByMe: false,
        favoritedByMe: false,
        favoriteCount: 0,
        status: "approved",
        reviewReason: nil,
        createdAt: Date(),
        editedAt: nil,
        viewCount: 3,
        contentRevision: 1,
        userAvatarUrl: nil,
        linkedDish: nil
    )

    static let communityComment = CommunityComment(
        id: "comment-1",
        postId: "post-1",
        userId: user.id,
        userDisplayName: user.displayName,
        content: "看起来不错",
        likeCount: 0,
        status: "approved",
        createdAt: Date(),
        rootCommentId: nil,
        replyToCommentId: nil,
        replyToUserId: nil,
        replyToDisplayName: nil,
        replyCount: 0,
        likedByMe: false,
        deleted: false,
        userAvatarUrl: nil
    )

    static let uploadedImage = UploadedImage(
        id: "media-1",
        imageUrl: "/api/v1/media/media-1",
        width: 1600,
        height: 1200
    )

    static let imageSubmission = ImageSubmission(
        id: "is-1",
        dishId: "d-1",
        dishName: "鸡腿饭",
        stallId: "s-1",
        stallName: "三号档口",
        diningHallId: "h-1",
        diningHallName: "学苑食堂",
        imageUrl: "/api/v1/media/media-1",
        status: "pending",
        reviewedAt: nil,
        reviewReason: nil,
        createdAt: Date()
    )

    static let venueReview = VenueReview(
        id: "vr-1",
        reviewId: "vr-1",
        submissionId: nil,
        userId: user.id,
        userDisplayName: user.displayName,
        targetType: "hall",
        targetId: "h-1",
        name: "学苑食堂",
        rating: 5,
        content: "环境不错",
        status: "approved",
        reviewReason: nil,
        createdAt: Date(),
        updatedAt: Date(),
        ownedByMe: false,
        likedByMe: false,
        likeCount: 0,
        counterVersion: 1,
        replyCount: 0
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

    static let conversation = Conversation(
        id: "conv-1",
        other: ChatParticipant(id: "u-2", displayName: "饭搭子", avatarUrl: nil),
        lastMessage: "中午吃什么",
        lastSenderId: "u-2",
        lastMessageAt: Date(),
        unreadCount: 1,
        updatedAt: Date()
    )

    static let directMessage = DirectMessage(
        id: "dm-1",
        conversationId: "conv-1",
        senderId: "u-2",
        content: "中午吃什么",
        createdAt: Date()
    )

    static let notice = Notice(
        id: "notice-1",
        content: "# 假期安排\n\n食堂正常营业。",
        publishedAt: Date(),
        isUpdate: true
    )

    static let inboxMessage = InboxMessage(
        id: "msg-1",
        title: "有人赞了你的食记",
        body: "去看看吧",
        category: "LIKE_POST",
        refType: "community-post",
        refId: "post-1",
        refCommentId: nil,
        refRootCommentId: nil,
        actorCount: 1,
        isRead: false,
        createdAt: Date()
    )

    static let notificationPreference = NotificationPreference(
        category: "message",
        enabled: true,
        revision: 1
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
