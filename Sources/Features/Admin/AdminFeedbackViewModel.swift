import Combine
import Foundation

@MainActor
final class AdminFeedbackViewModel: ObservableObject {
    @Published var archived = false {
        didSet { Task { await load(page: 1) } }
    }
    @Published private(set) var rows: [AdminFeedbackRow] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isExporting = false
    @Published private(set) var isImporting = false
    @Published private(set) var importResult: AdminFeedbackImportResult?
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
            let result = try await service.feedbackList(
                archived: archived,
                page: max(1, page),
                size: pageSize
            )
            rows = result.items
            self.page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func export() async -> AdminFeedbackExport? {
        guard !isExporting else { return nil }
        isExporting = true
        errorMessage = nil
        infoMessage = nil
        defer { isExporting = false }
        do {
            let result = try await service.exportFeedback()
            infoMessage = "已生成 CSV（\(result.count) 条）。待处理反馈已在服务端转为处理中，取消保存不会回滚。"
            await load(page: page)
            return result
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func importCSV(_ csv: String) async {
        guard !isImporting else { return }
        isImporting = true
        errorMessage = nil
        infoMessage = nil
        importResult = nil
        defer { isImporting = false }
        do {
            let result = try await service.importFeedback(csv: csv)
            importResult = result
            infoMessage = "导入完成：更新 \(result.updated)，跳过 \(result.skipped)。"
            await load(page: page)
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
final class AdminFeedbackDetailViewModel: ObservableObject {
    @Published private(set) var row: AdminFeedbackRow
    @Published private(set) var replies: [AdminFeedbackReply] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let service: AdminService
    let id: String

    init(service: AdminService, row: AdminFeedbackRow) {
        self.service = service
        self.row = row
        self.id = row.id
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let detail = service.feedbackDetail(id: id)
            async let replyPage = service.feedbackReplies(id: id, page: 1, size: 50)
            let current = try await detail
            let page = try await replyPage
            row = current
            replies = page.items
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(reply: String?, status: String?) async -> Bool {
        guard !isSubmitting else { return false }
        let trimmed = reply?.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed?.isEmpty ?? true) && status == nil {
            errorMessage = "请填写处理建议或选择状态"
            return false
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            row = try await service.updateFeedback(
                id: id,
                reply: trimmed?.isEmpty == true ? nil : trimmed,
                status: status,
                clientRequestID: UUID().uuidString
            )
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
}
