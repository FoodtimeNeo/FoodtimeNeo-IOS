import Combine
import Foundation

@MainActor
final class ModerationQueueViewModel: ObservableObject {
    @Published var status = "pending"
    @Published var type = ""
    @Published private(set) var items: [ModerationItem] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var actingItemID: String?
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: AdminService

    init(service: AdminService) {
        self.service = service
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / 20.0)))
    }

    func load(page: Int = 1) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.moderationQueue(
                status: status,
                type: type.isEmpty ? nil : type,
                page: max(1, page),
                size: 20
            )
            items = result.items
            self.page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moderate(
        _ item: ModerationItem,
        action: String,
        reason: String?,
        price: Decimal?
    ) async -> Bool {
        guard actingItemID == nil else { return false }
        actingItemID = item.id
        errorMessage = nil
        infoMessage = nil
        defer { actingItemID = nil }
        do {
            _ = try await service.moderate(
                type: item.type,
                submissionID: item.id,
                action: action,
                reason: reason,
                price: price,
                contentRevision: item.contentRevision
            )
            infoMessage = action == "approve" ? "已通过并发布。" : "已驳回。"
            await load(page: page)
            return true
        } catch let error as AppError {
            if error.code == "ALREADY_REVIEWED" {
                errorMessage = "该提交已被审核，请刷新队列。"
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class ModerationLogsViewModel: ObservableObject {
    @Published private(set) var logs: [ModerationLog] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: AdminService

    init(service: AdminService) {
        self.service = service
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / 20.0)))
    }

    func load(page: Int = 1) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.moderationLogs(page: max(1, page), size: 20)
            logs = result.items
            self.page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
