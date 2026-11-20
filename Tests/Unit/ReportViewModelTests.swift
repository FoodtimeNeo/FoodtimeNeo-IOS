import XCTest
import UIKit
@testable import FoodtimeNeo

@MainActor
final class ReportReceiptsViewModelTests: XCTestCase {
    func testReportsPagingAndDecisionsSwitch() async {
        let service = FakeReportService()
        let first = (0..<20).map { ReportViewModelFixtures.pendingReport(id: "r-\($0)") }
        let second = (20..<25).map { ReportViewModelFixtures.pendingReport(id: "r-\($0)") }
        service.myReportsResult = .success(Page(items: first, total: 25, page: 1, size: 20))
        let model = ReportReceiptsViewModel(service: service)

        await model.load()
        XCTAssertEqual(model.reports.count, 20)
        XCTAssertTrue(model.canLoadMore)

        service.myReportsResult = .success(Page(items: second, total: 25, page: 2, size: 20))
        await model.loadMore()
        XCTAssertEqual(model.reports.count, 25)
        XCTAssertFalse(model.canLoadMore)

        service.myDecisionsResult = .success(
            Page(items: [ReportViewModelFixtures.decision], total: 1, page: 1, size: 20)
        )
        await model.switchSegment(.decisions)
        XCTAssertEqual(model.decisions.count, 1)
        XCTAssertEqual(model.statusText, "共 1 条")
    }

    func testActionsAreCachedPerDecision() async {
        let service = FakeReportService()
        service.actionsResult = .success([ReportViewModelFixtures.action])
        let model = ReportReceiptsViewModel(service: service)

        await model.loadActions(decisionID: "d-1")
        await model.loadActions(decisionID: "d-1")

        XCTAssertEqual(model.actions(decisionID: "d-1")?.count, 1)
    }
}

@MainActor
final class FollowUpThreadViewModelTests: XCTestCase {
    func testBlankFollowUpIsRejected() async {
        let model = FollowUpThreadViewModel(
            reportID: "r-1",
            service: FakeReportService(),
            submissions: FakeSubmissionService()
        )

        await model.send()

        XCTAssertEqual(model.errorMessage, "请填写追问内容")
    }

    func testSendTrimsAndAppendsCreatedFollowUp() async throws {
        let service = FakeReportService()
        service.addFollowUpResult = .success(ReportViewModelFixtures.followUp)
        let model = FollowUpThreadViewModel(
            reportID: "r-1",
            service: service,
            submissions: FakeSubmissionService()
        )
        model.content = "  请再核对菜单  "

        await model.send()

        XCTAssertEqual(service.followUpCalls.first?.content, "请再核对菜单")
        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.content, "")
    }

    func testRetryReusesRequestID() async {
        let service = FakeReportService()
        service.addFollowUpResult = .failure(AppError.network(message: "offline"))
        let model = FollowUpThreadViewModel(
            reportID: "r-1",
            service: service,
            submissions: FakeSubmissionService()
        )
        model.content = "补充说明"

        await model.send()
        service.addFollowUpResult = .success(ReportViewModelFixtures.followUp)
        await model.send()

        XCTAssertEqual(service.followUpCalls.count, 2)
        XCTAssertEqual(service.followUpCalls[0].requestID, service.followUpCalls[1].requestID)
    }

    func testEvidenceUploadFailureBlocksSend() async {
        let submissions = FakeSubmissionService()
        submissions.uploadResult = .failure(AppError.network(message: "offline"))
        let service = FakeReportService()
        let model = FollowUpThreadViewModel(
            reportID: "r-1",
            service: service,
            submissions: submissions
        )
        model.content = "补充说明"
        await model.addEvidence([testImage()])

        await model.send()

        XCTAssertTrue(service.followUpCalls.isEmpty)
        XCTAssertEqual(model.errorMessage, "证据图片上传失败，请重试")
    }

    private func testImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
}

@MainActor
final class AppealComposeViewModelTests: XCTestCase {
    func testRestoresDraftForOpenDecision() async {
        let service = FakeReportService()
        service.myDecisionResult = .success(ReportViewModelFixtures.decision)
        let store = FakeAppealDraftStore()
        store.drafts["d-1"] = AppealDraft(content: "已写好的申诉", evidence: [])
        let model = AppealComposeViewModel(
            decisionID: "d-1",
            service: service,
            submissions: FakeSubmissionService(),
            drafts: store
        )

        await model.load()

        XCTAssertEqual(model.content, "已写好的申诉")
    }

    func testExpiredDeadlineCannotSubmit() async throws {
        let service = FakeReportService()
        service.myDecisionResult = .success(ReportViewModelFixtures.expiredDecision)
        let model = AppealComposeViewModel(
            decisionID: "d-1",
            service: service,
            submissions: FakeSubmissionService(),
            drafts: FakeAppealDraftStore()
        )
        await model.load()
        model.content = "逾期申诉"

        await model.submit()

        XCTAssertEqual(model.errorMessage, "申诉期限已过。")
        XCTAssertTrue(service.appealCalls.isEmpty)
    }

    func testExistingAppealCannotSubmitAgain() async {
        let service = FakeReportService()
        service.myDecisionResult = .success(ReportViewModelFixtures.submittedDecision)
        let model = AppealComposeViewModel(
            decisionID: "d-1",
            service: service,
            submissions: FakeSubmissionService(),
            drafts: FakeAppealDraftStore()
        )
        await model.load()
        model.content = "再次申诉"

        await model.submit()

        XCTAssertEqual(model.errorMessage, "同一决定只能提交一次申诉")
        XCTAssertTrue(service.appealCalls.isEmpty)
    }

    func testSubmitClearsDraftAndStoresReceipt() async {
        let service = FakeReportService()
        service.myDecisionResult = .success(ReportViewModelFixtures.decision)
        service.submitAppealResult = .success(ReportViewModelFixtures.appeal)
        let store = FakeAppealDraftStore()
        let model = AppealComposeViewModel(
            decisionID: "d-1",
            service: service,
            submissions: FakeSubmissionService(),
            drafts: store
        )
        await model.load()
        model.content = "  请复核  "
        model.persistDraft()

        await model.submit()

        XCTAssertEqual(service.appealCalls.first?.content, "请复核")
        XCTAssertEqual(model.submittedAppeal?.id, "ap-1")
        XCTAssertEqual(store.cleared, ["d-1"])
    }

    func testEvidenceFailureBlocksSubmit() async {
        let submissions = FakeSubmissionService()
        submissions.uploadResult = .failure(AppError.network(message: "offline"))
        let service = FakeReportService()
        service.myDecisionResult = .success(ReportViewModelFixtures.decision)
        let model = AppealComposeViewModel(
            decisionID: "d-1",
            service: service,
            submissions: submissions,
            drafts: FakeAppealDraftStore()
        )
        await model.load()
        model.content = "请复核"
        await model.addEvidence([testImage()])

        await model.submit()

        XCTAssertTrue(service.appealCalls.isEmpty)
        XCTAssertEqual(model.errorMessage, "证据图片上传失败，请重试")
    }

    private func testImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
}

final class FakeAppealDraftStore: AppealDraftStoring {
    var drafts: [String: AppealDraft] = [:]
    private(set) var cleared: [String] = []

    func load(decisionID: String) -> AppealDraft? {
        drafts[decisionID]
    }

    func save(_ draft: AppealDraft, decisionID: String) {
        drafts[decisionID] = draft
    }

    func clear(decisionID: String) {
        drafts[decisionID] = nil
        cleared.append(decisionID)
    }
}

enum ReportViewModelFixtures {
    static let completedReport = UserReport(
        id: "r-1",
        targetType: "post",
        targetId: "post-1",
        postId: "post-1",
        reason: "内容违规",
        excerpt: "这段内容",
        status: "completed",
        createdAt: Date(),
        decisionId: "d-1",
        outcome: "upheld",
        publicReason: "违反社区规范",
        decidedAt: Date()
    )

    static func pendingReport(id: String) -> UserReport {
        UserReport(
            id: id,
            targetType: "post",
            targetId: "post-1",
            postId: "post-1",
            reason: "内容违规",
            excerpt: nil,
            status: "pending",
            createdAt: Date(),
            decisionId: nil,
            outcome: nil,
            publicReason: nil,
            decidedAt: nil
        )
    }

    static let decision = ModerationDecision(
        decisionId: "d-1",
        reportId: "r-1",
        side: "reporter",
        targetType: "post",
        outcome: "upheld",
        publicReason: "违反社区规范",
        deliveredAt: Date(),
        appealDeadline: Date().addingTimeInterval(7 * 24 * 3_600),
        appealId: nil,
        appealStatus: nil,
        appealOutcome: nil
    )

    static let expiredDecision = ModerationDecision(
        decisionId: "d-1",
        reportId: "r-1",
        side: "reporter",
        targetType: "post",
        outcome: "upheld",
        publicReason: "违反社区规范",
        deliveredAt: Date().addingTimeInterval(-8 * 24 * 3_600),
        appealDeadline: Date().addingTimeInterval(-3_600),
        appealId: nil,
        appealStatus: nil,
        appealOutcome: nil
    )

    static let submittedDecision = ModerationDecision(
        decisionId: "d-1",
        reportId: "r-1",
        side: "reporter",
        targetType: "post",
        outcome: "upheld",
        publicReason: "违反社区规范",
        deliveredAt: Date(),
        appealDeadline: Date().addingTimeInterval(7 * 24 * 3_600),
        appealId: "ap-1",
        appealStatus: "submitted",
        appealOutcome: nil
    )

    static let action = ReportAction(
        id: "a-1",
        decisionId: "d-1",
        actionType: "remove_post",
        targetType: "post",
        targetId: "post-1",
        performedBy: "admin-1",
        note: "已下架",
        createdAt: Date()
    )

    static let followUp = ReportFollowUp(
        id: "f-1",
        reportId: "r-1",
        authorRole: "reporter",
        authorName: "我",
        content: "补充说明",
        internalNote: nil,
        evidenceUrls: [],
        createdAt: Date()
    )

    static let appeal = ReportAppeal(
        id: "ap-1",
        decisionId: "d-1",
        appellantId: "u-1",
        appellantName: "我",
        side: "reporter",
        content: "请复核",
        status: "submitted",
        outcome: nil,
        publicReason: nil,
        internalNote: nil,
        revision: 1,
        createdAt: Date(),
        resolvedAt: nil,
        evidenceUrls: []
    )
}
