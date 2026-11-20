import Foundation

protocol AuthService: AnyObject {
    func registrationPolicy() async throws -> RegistrationPolicy
    func captcha() async throws -> CaptchaChallenge
    func login(account: String, password: String, captcha: CaptchaAnswer?) async throws -> LoginOutcome
    func sendRegistrationCode(email: String) async throws -> EmailCodeReceipt
    func register(
        email: String,
        password: String,
        verificationCode: String,
        invitationCode: String?
    ) async throws -> User
    func sendPasswordResetCode(email: String) async throws -> EmailCodeReceipt
    func verifyPasswordResetCode(email: String, verificationCode: String) async throws -> PasswordResetGrant
    func resetPassword(resetToken: String, newPassword: String) async throws
    func changePassword(oldPassword: String, newPassword: String) async throws
    func currentProfile() async throws -> UserProfile
    func updateProfile(displayName: String, avatarUrl: String?) async throws -> UserProfile
    func accountLifecycle() async throws -> AccountLifecycleSummary
    func sendAccountLifecycleCode(_ action: AccountLifecycleAction) async throws -> AccountActionReceipt
    func unbindSchoolEmail(verificationCode: String) async throws -> SchoolEmailUnbindResult
    func deleteAccount(verificationCode: String) async throws -> AccountDeletionResult
    func sendSchoolEmailCode(email: String) async throws -> EmailCodeReceipt
    func bindSchoolEmail(email: String, verificationCode: String) async throws -> UserProfile
    func currentSession() async throws -> SessionSnapshot
    func capabilities() async throws -> CapabilitySnapshot
    func logout() async throws
}

protocol CatalogService: AnyObject {
    func diningHalls() async throws -> [DiningHall]
    func stalls(diningHallID: String) async throws -> [Stall]
    func dishes(stallID: String) async throws -> [DishSummary]
    func searchDishes(_ filters: DishSearchFilters) async throws -> Page<DishSearchRow>
}
