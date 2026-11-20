import Combine
import Foundation

@MainActor
final class AdminCorrectionsViewModel: ObservableObject {
    @Published var status = "pending" {
        didSet { Task { await load(page: 1) } }
    }
    @Published var targetType = "" {
        didSet { Task { await load(page: 1) } }
    }
    @Published private(set) var rows: [AdminCorrectionRow] = []
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
            let result = try await service.corrections(
                status: status.isEmpty ? nil : status,
                targetType: targetType.isEmpty ? nil : targetType,
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

    func changed(_ message: String) {
        infoMessage = message
        Task { await load(page: page) }
    }
}

@MainActor
final class AdminCorrectionDetailViewModel: ObservableObject {
    @Published private(set) var row: AdminCorrectionRow
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let service: AdminService
    let id: String

    init(service: AdminService, row: AdminCorrectionRow) {
        self.service = service
        self.row = row
        self.id = row.correction.id
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            row = try await service.correctionDetail(id: id)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func decide(decision: String, reviewNote: String?) async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            row = try await service.decideCorrection(
                id: id,
                decision: decision,
                reviewNote: reviewNote,
                expectedRevision: row.correction.revision
            )
            return true
        } catch let error as AppError {
            errorMessage = Self.message(for: error)
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func message(for error: AppError) -> String {
        switch error.code {
        case "CORRECTION_ALREADY_DECIDED":
            return "该提案已被处理，请刷新队列。"
        case "CORRECTION_REVISION_CONFLICT":
            return "提案已被修改，请重新载入详情。"
        case "CATALOG_REVISION_CONFLICT":
            return "目录资料已更新，无法应用旧提案；请刷新后重新核对。"
        case "CATALOG_TARGET_GONE":
            return "目标资料已删除，无法应用。"
        case "CATALOG_TARGET_UNAVAILABLE":
            return "目标资料已停用，无法应用。"
        default:
            return error.localizedDescription
        }
    }
}
