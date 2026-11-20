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

    func catalogList(
        type: String,
        parentID: String?,
        page: Int,
        size: Int
    ) async throws -> Page<AdminCatalogItem>
    func catalogItem(type: String, id: String) async throws -> AdminCatalogItem
    func createCatalogItem(
        type: String,
        edit: AdminCatalogEdit
    ) async throws -> AdminCatalogItem
    func updateCatalogItem(
        type: String,
        id: String,
        edit: AdminCatalogEdit
    ) async throws -> AdminCatalogItem
    func deleteCatalogItem(type: String, id: String) async throws
    func adminReviews(
        query: String,
        page: Int,
        size: Int
    ) async throws -> Page<AdminReviewItem>
    func removeReview(id: String, reason: String) async throws

    func corrections(
        status: String?,
        targetType: String?,
        page: Int,
        size: Int
    ) async throws -> Page<AdminCorrectionRow>
    func correctionDetail(id: String) async throws -> AdminCorrectionRow
    func decideCorrection(
        id: String,
        decision: String,
        reviewNote: String?,
        expectedRevision: Int
    ) async throws -> AdminCorrectionRow

    func notices(query: String, page: Int, size: Int) async throws -> Page<AdminNotice>
    func noticeDetail(id: String) async throws -> AdminNotice
    func saveNotice(
        id: String?,
        content: String,
        schedule: AdminNoticeScheduleRequest?
    ) async throws -> AdminNotice
    func scheduleNotice(
        id: String,
        schedule: AdminNoticeScheduleRequest
    ) async throws -> AdminNotice
    func deleteNotice(id: String) async throws
    func noticeSettings() async throws -> AdminNoticeSettings
    func updateNoticeSettings(noticeID: String?) async throws -> AdminNoticeSettings

    func feedbackList(
        archived: Bool,
        page: Int,
        size: Int
    ) async throws -> Page<AdminFeedbackRow>
    func feedbackDetail(id: String) async throws -> AdminFeedbackRow
    func feedbackReplies(
        id: String,
        page: Int,
        size: Int
    ) async throws -> Page<AdminFeedbackReply>
    func updateFeedback(
        id: String,
        reply: String?,
        status: String?,
        clientRequestID: String
    ) async throws -> AdminFeedbackRow
    func exportFeedback() async throws -> AdminFeedbackExport
    func importFeedback(csv: String) async throws -> AdminFeedbackImportResult
}
