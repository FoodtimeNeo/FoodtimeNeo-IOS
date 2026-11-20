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

    func reportsPending(page: Int, size: Int) async throws -> Page<AdminReportRow>
    func decideReport(
        id: String,
        outcome: String,
        publicReason: String,
        internalNote: String?
    ) async throws -> AdminReportDecisionReceipt
    func reportDecisions(page: Int, size: Int) async throws -> Page<AdminReportDecision>
    func reportFollowUps(
        id: String,
        page: Int,
        size: Int
    ) async throws -> Page<AdminReportFollowUp>
    func addReportFollowUp(
        id: String,
        content: String,
        internalNote: String?,
        evidenceUrls: [String],
        clientRequestID: String
    ) async throws -> AdminReportFollowUp
    func reportActions(id: String) async throws -> [AdminReportAction]
    func performReportAction(
        id: String,
        actionType: String,
        targetID: String?,
        note: String?
    ) async throws -> AdminReportAction
    func markReportReviewed(id: String) async throws

    func appeals(
        status: String?,
        page: Int,
        size: Int
    ) async throws -> Page<AdminAppeal>
    func appealDetail(id: String) async throws -> AdminAppeal
    func startAppeal(id: String, expectedRevision: Int) async throws -> AdminAppeal
    func resolveAppeal(
        id: String,
        outcome: String,
        publicReason: String,
        internalNote: String?,
        expectedRevision: Int
    ) async throws -> AdminAppeal
}
