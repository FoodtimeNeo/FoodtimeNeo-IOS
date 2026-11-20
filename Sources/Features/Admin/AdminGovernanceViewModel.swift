import Combine
import Foundation

@MainActor
final class AdminReportsViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case pending
        case decisions

        var id: String { rawValue }
        var title: String { self == .pending ? "待处理" : "已决定" }
    }

    @Published var mode: Mode = .pending {
        didSet { Task { await load(page: 1) } }
    }
    @Published private(set) var pending: [AdminReportRow] = []
    @Published private(set) var decisions: [AdminReportDecision] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: AdminService
    private let pageSize = 20

    init(service: AdminService) {
        self.service = service
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / Double(pageSize))))
    }

    func load(page: Int = 1) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch mode {
            case .pending:
                let result = try await service.reportsPending(page: max(1, page), size: pageSize)
                pending = result.items
                self.page = result.page
                total = result.total
            case .decisions:
                let result = try await service.reportDecisions(page: max(1, page), size: pageSize)
                decisions = result.items
                self.page = result.page
                total = result.total
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changed(_ message: String) {
        infoMessage = message
        Task { await load(page: page) }
    }
}

@MainActor
final class AdminReportDetailViewModel: ObservableObject {
    let report: AdminReportRow
    @Published private(set) var followUps: [AdminReportFollowUp] = []
    @Published private(set) var actions: [AdminReportAction] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: AdminService

    init(service: AdminService, report: AdminReportRow) {
        self.service = service
        self.report = report
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let followUpPage = service.reportFollowUps(
                id: report.id,
                page: 1,
                size: 50
            )
            async let actionList = service.reportActions(id: report.id)
            let page = try await followUpPage
            let list = try await actionList
            followUps = page.items
            actions = list
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func decide(
        outcome: String,
        publicReason: String,
        internalNote: String?
    ) async -> Bool {
        guard !isSubmitting else { return false }
        let reason = publicReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else {
            errorMessage = "公开理由不能为空"
            return false
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let receipt = try await service.decideReport(
                id: report.id,
                outcome: outcome,
                publicReason: reason,
                internalNote: internalNote
            )
            infoMessage = "已作出决定：\(AdminReportOutcome.label(receipt.outcome))。"
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func addFollowUp(content: String, internalNote: String?) async -> Bool {
        guard !isSubmitting else { return false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "追问内容不能为空"
            return false
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await service.addReportFollowUp(
                id: report.id,
                content: trimmed,
                internalNote: internalNote,
                evidenceUrls: [],
                clientRequestID: UUID().uuidString
            )
            infoMessage = "已发送追问。"
            await load()
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func performAction(
        type: AdminReportActionType,
        targetID: String?,
        note: String?
    ) async -> Bool {
        guard !isSubmitting else { return false }
        if type.requiresTargetID,
           targetID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            errorMessage = "该动作需要目标 ID"
            return false
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await service.performReportAction(
                id: report.id,
                actionType: type.rawValue,
                targetID: targetID,
                note: note
            )
            infoMessage = "已执行：\(type.title)。"
            await load()
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func markReviewed() async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await service.markReportReviewed(id: report.id)
            infoMessage = "已标记为已读。"
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class AdminAppealsViewModel: ObservableObject {
    @Published var status = "" {
        didSet { Task { await load(page: 1) } }
    }
    @Published private(set) var appeals: [AdminAppeal] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: AdminService
    private let pageSize = 20

    init(service: AdminService) {
        self.service = service
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / Double(pageSize))))
    }

    func load(page: Int = 1) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.appeals(
                status: status.isEmpty ? nil : status,
                page: max(1, page),
                size: pageSize
            )
            appeals = result.items
            self.page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changed(_ message: String) {
        infoMessage = message
        Task { await load(page: page) }
    }
}

@MainActor
final class AdminAppealDetailViewModel: ObservableObject {
    @Published private(set) var appeal: AdminAppeal
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let service: AdminService
    private let id: String

    init(service: AdminService, appeal: AdminAppeal) {
        self.service = service
        self.appeal = appeal
        self.id = appeal.id
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            appeal = try await service.appealDetail(id: id)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func start() async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            appeal = try await service.startAppeal(
                id: id,
                expectedRevision: appeal.revision
            )
            return true
        } catch let error as AppError {
            errorMessage = error.code == "APPEAL_REVISION_CONFLICT"
                ? "申诉已被他人处理，请重新载入。"
                : error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func resolve(
        outcome: String,
        publicReason: String,
        internalNote: String?
    ) async -> Bool {
        guard !isSubmitting else { return false }
        let reason = publicReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else {
            errorMessage = "公开理由不能为空"
            return false
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            appeal = try await service.resolveAppeal(
                id: id,
                outcome: outcome,
                publicReason: reason,
                internalNote: internalNote,
                expectedRevision: appeal.revision
            )
            return true
        } catch let error as AppError {
            errorMessage = error.code == "APPEAL_REVISION_CONFLICT"
                ? "申诉已被他人处理，请重新载入。"
                : error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
