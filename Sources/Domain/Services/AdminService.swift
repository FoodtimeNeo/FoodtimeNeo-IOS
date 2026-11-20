import Foundation

protocol AdminService: AnyObject {
    func dashboard(days: Int) async throws -> AdminDashboard
    func users(query: String, page: Int, size: Int) async throws -> Page<AdminUser>
    func updateUser(id: String, role: String, status: String) async throws
    func moderationQueue(
        status: String,
        type: String?,
        page: Int,
        size: Int
    ) async throws -> Page<ModerationItem>
    func moderate(
        type: String,
        submissionID: String,
        action: String,
        reason: String?,
        price: Decimal?,
        contentRevision: Int?
    ) async throws -> ModerationResult
    func moderationLogs(page: Int, size: Int) async throws -> Page<ModerationLog>
    func communityQueue(
        kind: String,
        status: String,
        page: Int,
        size: Int
    ) async throws -> Page<ModerationItem>
    func moderateCommunity(
        kind: String,
        id: String,
        action: String,
        reason: String?,
        contentRevision: Int?
    ) async throws -> ModerationResult
    func communityModerationDetail(
        kind: String,
        id: String
    ) async throws -> CommunityModerationDetail
    func deleteCommunityContent(kind: String, id: String) async throws
}
