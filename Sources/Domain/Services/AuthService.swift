import Foundation

protocol AuthService: AnyObject {
    func registrationPolicy() async throws -> RegistrationPolicy
    func captcha() async throws -> CaptchaChallenge
    func login(account: String, password: String, captcha: CaptchaAnswer?) async throws -> LoginOutcome
    func currentSession() async throws -> SessionSnapshot
    func capabilities() async throws -> CapabilitySnapshot
    func logout() async throws
}

protocol CatalogService: AnyObject {
    func diningHalls() async throws -> [DiningHall]
    func stalls(diningHallID: String) async throws -> [Stall]
    func dishes(stallID: String) async throws -> [DishSummary]
}
