import Foundation

/// 举报、回执、追问与申诉。所有方法只操作当前登录账号本人的数据。
protocol ReportService: AnyObject {
    func submitReport(targetType: String, targetID: String, reason: String) async throws

    func myReports(page: Int, size: Int) async throws -> Page<UserReport>
    func myReport(id: String) async throws -> UserReport

    func myDecisions(page: Int, size: Int) async throws -> Page<ModerationDecision>
    func myDecision(id: String) async throws -> ModerationDecision
    func decisionActions(decisionID: String) async throws -> [ReportAction]

    func followUps(reportID: String, page: Int, size: Int) async throws -> Page<ReportFollowUp>
    func addFollowUp(
        reportID: String,
        content: String,
        evidenceURLs: [String],
        requestID: String
    ) async throws -> ReportFollowUp

    func submitAppeal(
        decisionID: String,
        content: String,
        evidenceURLs: [String],
        requestID: String
    ) async throws -> ReportAppeal
    func myAppeals(page: Int, size: Int) async throws -> Page<ReportAppeal>
    func myAppeal(id: String) async throws -> ReportAppeal
}
