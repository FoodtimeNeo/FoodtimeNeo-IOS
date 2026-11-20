import Foundation

final class RemoteReportService: ReportService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func submitReport(targetType: String, targetID: String, reason: String) async throws {
        struct Body: Encodable {
            let targetType: String
            let targetId: String
            let reason: String
        }
        let request = try APIRequest.json(
            .post,
            "reports",
            body: Body(targetType: targetType, targetId: targetID, reason: reason),
            requiresAuth: true,
            requiresCSRF: true
        )
        try await api.sendVoid(request)
    }

    func myReports(page: Int, size: Int) async throws -> Page<UserReport> {
        try await api.send(
            .get("users/me/reports", query: paging(page: page, size: size)),
            as: Page<UserReport>.self
        )
    }

    func myReport(id: String) async throws -> UserReport {
        try await api.send(
            .get("users/me/reports/\(encoded(id))"),
            as: UserReport.self
        )
    }

    func myDecisions(page: Int, size: Int) async throws -> Page<ModerationDecision> {
        try await api.send(
            .get("users/me/moderation-decisions", query: paging(page: page, size: size)),
            as: Page<ModerationDecision>.self
        )
    }

    func myDecision(id: String) async throws -> ModerationDecision {
        try await api.send(
            .get("users/me/moderation-decisions/\(encoded(id))"),
            as: ModerationDecision.self
        )
    }

    func decisionActions(decisionID: String) async throws -> [ReportAction] {
        try await api.send(
            .get("users/me/moderation-decisions/\(encoded(decisionID))/actions"),
            as: [ReportAction].self
        )
    }

    func followUps(reportID: String, page: Int, size: Int) async throws -> Page<ReportFollowUp> {
        try await api.send(
            .get(
                "users/me/reports/\(encoded(reportID))/follow-ups",
                query: paging(page: page, size: size)
            ),
            as: Page<ReportFollowUp>.self
        )
    }

    func addFollowUp(
        reportID: String,
        content: String,
        evidenceURLs: [String],
        requestID: String
    ) async throws -> ReportFollowUp {
        struct Body: Encodable {
            let content: String
            let evidenceUrls: [String]
            let clientRequestId: String
        }
        let request = try APIRequest.json(
            .post,
            "users/me/reports/\(encoded(reportID))/follow-ups",
            body: Body(
                content: content,
                evidenceUrls: evidenceURLs,
                clientRequestId: requestID
            )
        )
        return try await api.send(request, as: ReportFollowUp.self)
    }

    func submitAppeal(
        decisionID: String,
        content: String,
        evidenceURLs: [String],
        requestID: String
    ) async throws -> ReportAppeal {
        struct Body: Encodable {
            let content: String
            let evidenceUrls: [String]
            let clientRequestId: String
        }
        let request = try APIRequest.json(
            .post,
            "users/me/moderation-decisions/\(encoded(decisionID))/appeals",
            body: Body(
                content: content,
                evidenceUrls: evidenceURLs,
                clientRequestId: requestID
            )
        )
        return try await api.send(request, as: ReportAppeal.self)
    }

    func myAppeals(page: Int, size: Int) async throws -> Page<ReportAppeal> {
        try await api.send(
            .get("users/me/appeals", query: paging(page: page, size: size)),
            as: Page<ReportAppeal>.self
        )
    }

    func myAppeal(id: String) async throws -> ReportAppeal {
        try await api.send(
            .get("users/me/appeals/\(encoded(id))"),
            as: ReportAppeal.self
        )
    }

    private func paging(page: Int, size: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
