import Combine
import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var kind: HistoryKind = .dish
    @Published private(set) var settings: BrowsingHistorySettings?
    @Published private(set) var items: [BrowsingHistoryItem] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isSavingSettings = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: HistoryService

    init(service: HistoryService) {
        self.service = service
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / 50.0)))
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            settings = try await service.settings()
            let result = try await service.list(kind: kind, page: 1, size: 50)
            items = result.items
            page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectKind(_ next: HistoryKind) async {
        kind = next
        await load()
    }

    func setEnabled(_ enabled: Bool) async {
        guard let settings, !isSavingSettings else { return }
        isSavingSettings = true
        errorMessage = nil
        infoMessage = nil
        defer { isSavingSettings = false }
        do {
            self.settings = try await service.updateSettings(
                enabled: enabled,
                expectedRevision: settings.revision
            )
            infoMessage = enabled ? "已开始记录浏览历史。" : "已停止新增记录，已有历史保留。"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: BrowsingHistoryItem) async {
        errorMessage = nil
        infoMessage = nil
        do {
            try await service.deleteOne(kind: kind, targetID: item.targetId)
            items.removeAll { $0.id == item.id }
            total = max(0, total - 1)
            settings = try? await service.settings()
            infoMessage = "已删除该条历史。"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() async {
        errorMessage = nil
        infoMessage = nil
        do {
            try await service.clear(kind: kind)
            items = []
            total = 0
            settings = try? await service.settings()
            infoMessage = "已清空\(kind.label)浏览历史。"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPage(_ number: Int) async {
        guard !isLoading, number >= 1 else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.list(kind: kind, page: number, size: 50)
            items = result.items
            page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
