import Foundation

@MainActor
final class MyCorrectionsViewModel: ObservableObject {
    @Published private(set) var items: [CatalogCorrection] = []
    @Published private(set) var total = 0
    @Published private(set) var page = 1
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: CorrectionService
    private let pageSize = 20

    init(service: CorrectionService) {
        self.service = service
    }

    var hasMore: Bool {
        page * pageSize < total
    }

    var statusText: String {
        if isLoading && items.isEmpty { return "正在加载…" }
        return items.isEmpty ? "还没有纠错提案。" : "共 \(total) 条"
    }

    func load(page target: Int = 1) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.mine(page: max(1, target), size: pageSize)
            items = target <= 1 ? result.items : merged(items, result.items)
            total = result.total
            page = max(1, target)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        await load(page: page + 1)
    }

    private func merged(_ current: [CatalogCorrection], _ next: [CatalogCorrection]) -> [CatalogCorrection] {
        var seen = Set(current.map(\.id))
        var result = current
        for item in next where seen.insert(item.id).inserted {
            result.append(item)
        }
        return result
    }
}
