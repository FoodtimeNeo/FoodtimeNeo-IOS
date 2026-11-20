import Foundation

final class RemoteAdminService: AdminService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func dashboard(days: Int) async throws -> AdminDashboard {
        try await api.send(
            .get(
                "admin/dashboard",
                query: [URLQueryItem(name: "days", value: String(min(31, max(1, days))))]
            ),
            as: AdminDashboard.self
        )
    }

    func users(query: String, page: Int, size: Int) async throws -> Page<AdminUser> {
        var items = [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "q", value: trimmed))
        }
        return try await api.send(
            .get("admin/users", query: items),
            as: Page<AdminUser>.self
        )
    }

    func updateUser(id: String, role: String, status: String) async throws {
        struct Body: Encodable {
            let role: String
            let status: String
        }
        let request = try APIRequest.json(
            .put,
            "admin/users/\(encoded(id))",
            body: Body(role: role, status: status),
            requiresAuth: true,
            requiresCSRF: true
        )
        try await api.sendVoid(request)
    }

    func moderationQueue(
        status: String,
        type: String?,
        page: Int,
        size: Int
    ) async throws -> Page<ModerationItem> {
        var query = [
            URLQueryItem(name: "status", value: status),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
        if let type, !type.isEmpty {
            query.append(URLQueryItem(name: "type", value: type))
        }
        return try await api.send(
            .get("admin/moderation", query: query),
            as: Page<ModerationItem>.self
        )
    }

    func moderate(
        type: String,
        submissionID: String,
        action: String,
        reason: String?,
        price: Decimal?,
        contentRevision: Int?
    ) async throws -> ModerationResult {
        struct Body: Encodable {
            let action: String
            let reason: String?
            let price: Decimal?
            let contentRevision: Int?
        }
        let request = try APIRequest.json(
            .post,
            "admin/moderation/\(encoded(type))/\(encoded(submissionID))",
            body: Body(
                action: action,
                reason: reason,
                price: price,
                contentRevision: contentRevision
            ),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: ModerationResult.self)
    }

    func moderationLogs(page: Int, size: Int) async throws -> Page<ModerationLog> {
        try await api.send(
            .get(
                "admin/moderation/logs",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<ModerationLog>.self
        )
    }

    func communityQueue(
        kind: String,
        status: String,
        page: Int,
        size: Int
    ) async throws -> Page<ModerationItem> {
        try await api.send(
            .get(
                "admin/community/\(encoded(kind))",
                query: [
                    URLQueryItem(name: "status", value: status),
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<ModerationItem>.self
        )
    }

    func moderateCommunity(
        kind: String,
        id: String,
        action: String,
        reason: String?,
        contentRevision: Int?
    ) async throws -> ModerationResult {
        struct Body: Encodable {
            let action: String
            let reason: String?
            let contentRevision: Int?
        }
        let request = try APIRequest.json(
            .post,
            "admin/community/\(encoded(kind))/\(encoded(id))",
            body: Body(action: action, reason: reason, contentRevision: contentRevision),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: ModerationResult.self)
    }

    func communityModerationDetail(
        kind: String,
        id: String
    ) async throws -> CommunityModerationDetail {
        try await api.send(
            .get("admin/community/\(encoded(kind))/\(encoded(id))"),
            as: CommunityModerationDetail.self
        )
    }

    func deleteCommunityContent(kind: String, id: String) async throws {
        try await api.sendVoid(
            .delete("admin/community/\(encoded(kind))/\(encoded(id))")
        )
    }

    func reportsPending(page: Int, size: Int) async throws -> Page<AdminReportRow> {
        try await api.send(
            .get(
                "admin/reports",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<AdminReportRow>.self
        )
    }

    func decideReport(
        id: String,
        outcome: String,
        publicReason: String,
        internalNote: String?
    ) async throws -> AdminReportDecisionReceipt {
        struct Body: Encodable {
            let outcome: String
            let publicReason: String
            let internalNote: String?
        }
        let request = try APIRequest.json(
            .post,
            "admin/reports/\(encoded(id))/decision",
            body: Body(
                outcome: outcome,
                publicReason: publicReason,
                internalNote: internalNote
            ),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: AdminReportDecisionReceipt.self)
    }

    func reportDecisions(page: Int, size: Int) async throws -> Page<AdminReportDecision> {
        try await api.send(
            .get(
                "admin/reports/decisions",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<AdminReportDecision>.self
        )
    }

    func reportFollowUps(
        id: String,
        page: Int,
        size: Int
    ) async throws -> Page<AdminReportFollowUp> {
        try await api.send(
            .get(
                "admin/reports/\(encoded(id))/follow-ups",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<AdminReportFollowUp>.self
        )
    }

    func addReportFollowUp(
        id: String,
        content: String,
        internalNote: String?,
        evidenceUrls: [String],
        clientRequestID: String
    ) async throws -> AdminReportFollowUp {
        struct Body: Encodable {
            let content: String
            let internalNote: String?
            let evidenceUrls: [String]
            let clientRequestId: String
        }
        let request = try APIRequest.json(
            .post,
            "admin/reports/\(encoded(id))/follow-ups",
            body: Body(
                content: content,
                internalNote: internalNote,
                evidenceUrls: evidenceUrls,
                clientRequestId: clientRequestID
            ),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: AdminReportFollowUp.self)
    }

    func reportActions(id: String) async throws -> [AdminReportAction] {
        try await api.send(
            .get("admin/reports/\(encoded(id))/actions"),
            as: [AdminReportAction].self
        )
    }

    func performReportAction(
        id: String,
        actionType: String,
        targetID: String?,
        note: String?
    ) async throws -> AdminReportAction {
        struct Body: Encodable {
            let actionType: String
            let targetId: String?
            let note: String?
        }
        let request = try APIRequest.json(
            .post,
            "admin/reports/\(encoded(id))/actions",
            body: Body(actionType: actionType, targetId: targetID, note: note),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: AdminReportAction.self)
    }

    func markReportReviewed(id: String) async throws {
        try await api.sendVoid(
            .put("admin/reports/\(encoded(id))/review")
        )
    }

    func appeals(
        status: String?,
        page: Int,
        size: Int
    ) async throws -> Page<AdminAppeal> {
        var query = [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
        if let status, !status.isEmpty {
            query.append(URLQueryItem(name: "status", value: status))
        }
        return try await api.send(
            .get("admin/appeals", query: query),
            as: Page<AdminAppeal>.self
        )
    }

    func appealDetail(id: String) async throws -> AdminAppeal {
        try await api.send(
            .get("admin/appeals/\(encoded(id))"),
            as: AdminAppeal.self
        )
    }

    func startAppeal(id: String, expectedRevision: Int) async throws -> AdminAppeal {
        let request = APIRequest(
            method: .post,
            path: "admin/appeals/\(encoded(id))/start",
            query: [
                URLQueryItem(name: "expectedRevision", value: String(expectedRevision))
            ],
            body: nil,
            requiresAuth: true,
            requiresCSRF: true,
            contentType: nil
        )
        return try await api.send(request, as: AdminAppeal.self)
    }

    func resolveAppeal(
        id: String,
        outcome: String,
        publicReason: String,
        internalNote: String?,
        expectedRevision: Int
    ) async throws -> AdminAppeal {
        struct Body: Encodable {
            let outcome: String
            let publicReason: String
            let internalNote: String?
            let expectedRevision: Int
        }
        let request = try APIRequest.json(
            .post,
            "admin/appeals/\(encoded(id))/resolve",
            body: Body(
                outcome: outcome,
                publicReason: publicReason,
                internalNote: internalNote,
                expectedRevision: expectedRevision
            ),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: AdminAppeal.self)
    }

    func catalogList(
        type: String,
        parentID: String?,
        page: Int,
        size: Int
    ) async throws -> Page<AdminCatalogItem> {
        var query = [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
        if let parentID, !parentID.isEmpty {
            query.append(URLQueryItem(name: "parentId", value: parentID))
        }
        return try await api.send(
            .get("admin/catalog/\(encoded(type))", query: query),
            as: Page<AdminCatalogItem>.self
        )
    }

    func catalogItem(type: String, id: String) async throws -> AdminCatalogItem {
        try await api.send(
            .get("admin/catalog/\(encoded(type))/\(encoded(id))"),
            as: AdminCatalogItem.self
        )
    }

    func createCatalogItem(
        type: String,
        edit: AdminCatalogEdit
    ) async throws -> AdminCatalogItem {
        let request = try APIRequest.json(
            .post,
            "admin/catalog/\(encoded(type))",
            body: edit,
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: AdminCatalogItem.self)
    }

    func updateCatalogItem(
        type: String,
        id: String,
        edit: AdminCatalogEdit
    ) async throws -> AdminCatalogItem {
        let request = try APIRequest.json(
            .put,
            "admin/catalog/\(encoded(type))/\(encoded(id))",
            body: edit,
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: AdminCatalogItem.self)
    }

    func deleteCatalogItem(type: String, id: String) async throws {
        try await api.sendVoid(
            .delete("admin/catalog/\(encoded(type))/\(encoded(id))")
        )
    }

    func adminReviews(
        query: String,
        page: Int,
        size: Int
    ) async throws -> Page<AdminReviewItem> {
        var items = [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "q", value: trimmed))
        }
        return try await api.send(
            .get("admin/reviews", query: items),
            as: Page<AdminReviewItem>.self
        )
    }

    func removeReview(id: String, reason: String) async throws {
        struct Body: Encodable {
            let reason: String
        }
        let request = try APIRequest.json(
            .delete,
            "admin/reviews/\(encoded(id))",
            body: Body(reason: reason),
            requiresAuth: true,
            requiresCSRF: true
        )
        try await api.sendVoid(request)
    }

    func corrections(
        status: String?,
        targetType: String?,
        page: Int,
        size: Int
    ) async throws -> Page<AdminCorrectionRow> {
        var query = [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
        if let status, !status.isEmpty {
            query.append(URLQueryItem(name: "status", value: status))
        }
        if let targetType, !targetType.isEmpty {
            query.append(URLQueryItem(name: "targetType", value: targetType))
        }
        return try await api.send(
            .get("admin/catalog-corrections", query: query),
            as: Page<AdminCorrectionRow>.self
        )
    }

    func correctionDetail(id: String) async throws -> AdminCorrectionRow {
        try await api.send(
            .get("admin/catalog-corrections/\(encoded(id))"),
            as: AdminCorrectionRow.self
        )
    }

    func decideCorrection(
        id: String,
        decision: String,
        reviewNote: String?,
        expectedRevision: Int
    ) async throws -> AdminCorrectionRow {
        struct Body: Encodable {
            let decision: String
            let reviewNote: String?
            let expectedRevision: Int
        }
        let request = try APIRequest.json(
            .post,
            "admin/catalog-corrections/\(encoded(id))/decision",
            body: Body(
                decision: decision,
                reviewNote: reviewNote,
                expectedRevision: expectedRevision
            ),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: AdminCorrectionRow.self)
    }

    func notices(query: String, page: Int, size: Int) async throws -> Page<AdminNotice> {
        var items = [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "size", value: String(min(100, max(1, size))))
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let path: String
        if trimmed.isEmpty {
            path = "admin/notices"
        } else {
            path = "admin/notices/search"
            items.append(URLQueryItem(name: "q", value: trimmed))
        }
        return try await api.send(
            .get(path, query: items),
            as: Page<AdminNotice>.self
        )
    }

    func noticeDetail(id: String) async throws -> AdminNotice {
        try await api.send(
            .get("admin/notices/\(encoded(id))"),
            as: AdminNotice.self
        )
    }

    func saveNotice(
        id: String?,
        content: String,
        schedule: AdminNoticeScheduleRequest?
    ) async throws -> AdminNotice {
        struct Body: Encodable {
            let content: String
            let schedule: AdminNoticeScheduleRequest?
        }
        let request: APIRequest
        if let id {
            request = try APIRequest.json(
                .put,
                "admin/notices/\(encoded(id))/markdown",
                body: Body(content: content, schedule: schedule),
                requiresAuth: true,
                requiresCSRF: true
            )
        } else {
            request = try APIRequest.json(
                .post,
                "admin/notices/markdown",
                body: Body(content: content, schedule: schedule),
                requiresAuth: true,
                requiresCSRF: true
            )
        }
        return try await api.send(request, as: AdminNotice.self)
    }

    func scheduleNotice(
        id: String,
        schedule: AdminNoticeScheduleRequest
    ) async throws -> AdminNotice {
        let request = try APIRequest.json(
            .put,
            "admin/notices/\(encoded(id))/schedule",
            body: schedule,
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: AdminNotice.self)
    }

    func deleteNotice(id: String) async throws {
        try await api.sendVoid(
            .delete("admin/notices/\(encoded(id))")
        )
    }

    func noticeSettings() async throws -> AdminNoticeSettings {
        try await api.send(
            .get("admin/notices/settings"),
            as: AdminNoticeSettings.self
        )
    }

    func updateNoticeSettings(noticeID: String?) async throws -> AdminNoticeSettings {
        struct Body: Encodable {
            let noticeId: String?
        }
        let request = try APIRequest.json(
            .put,
            "admin/notices/settings",
            body: Body(noticeId: noticeID),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: AdminNoticeSettings.self)
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
