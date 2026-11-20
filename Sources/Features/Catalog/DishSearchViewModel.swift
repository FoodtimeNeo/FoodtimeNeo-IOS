import Combine
import Foundation

@MainActor
final class DishSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var selectedHallIDs: Set<String> = []
    @Published var minPriceText = ""
    @Published var maxPriceText = ""
    @Published var rating: DishRatingFilter = .none
    @Published var sort: DishSort = .relevance
    @Published private(set) var halls: [DiningHall] = []
    @Published private(set) var results: [DishSearchRow] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var hallsError: String?

    private let catalog: CatalogService
    private let pageSize = 20
    private var queryTask: Task<Void, Never>?

    init(catalog: CatalogService) {
        self.catalog = catalog
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / Double(pageSize))))
    }

    var activeFilterCount: Int {
        var count = selectedHallIDs.count
        if minPriceText.trimmingCharacters(in: .whitespaces).isEmpty == false { count += 1 }
        if maxPriceText.trimmingCharacters(in: .whitespaces).isEmpty == false { count += 1 }
        if rating != .none { count += 1 }
        if sort != .relevance { count += 1 }
        return count
    }

    func loadHalls() async {
        guard halls.isEmpty else { return }
        hallsError = nil
        do {
            halls = try await catalog.diningHalls()
        } catch let error as AppError {
            hallsError = error.localizedDescription
        } catch {
            hallsError = error.localizedDescription
        }
    }

    func queryChanged() {
        queryTask?.cancel()
        queryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.search(reset: true)
        }
    }

    func toggleHall(_ id: String) {
        if selectedHallIDs.contains(id) {
            selectedHallIDs.remove(id)
        } else {
            selectedHallIDs.insert(id)
        }
    }

    func resetFilters() {
        selectedHallIDs = []
        minPriceText = ""
        maxPriceText = ""
        rating = .none
        sort = .relevance
        errorMessage = nil
    }

    func search(reset: Bool = true) async {
        guard !isLoading else { return }
        guard let filters = filters(page: reset ? 1 : page + 1) else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await catalog.searchDishes(filters)
            results = result.items
            page = result.page
            total = result.total
        } catch let error as AppError {
            if case .validation(let fields) = error {
                errorMessage = fields.isEmpty
                    ? error.localizedDescription
                    : fields.map(\.message).joined(separator: "；")
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func previousPage() async {
        guard page > 1 else { return }
        await load(page: page - 1)
    }

    func nextPage() async {
        guard page < totalPages else { return }
        await load(page: page + 1)
    }

    private func load(page: Int) async {
        guard !isLoading, let filters = filters(page: page) else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await catalog.searchDishes(filters)
            results = result.items
            self.page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func filters(page: Int) -> DishSearchFilters? {
        let minPrice = parsePrice(minPriceText)
        let maxPrice = parsePrice(maxPriceText)
        if minPriceText.trimmingCharacters(in: .whitespaces).isEmpty == false, minPrice == nil {
            errorMessage = "最低价格式不正确"
            return nil
        }
        if maxPriceText.trimmingCharacters(in: .whitespaces).isEmpty == false, maxPrice == nil {
            errorMessage = "最高价格式不正确"
            return nil
        }
        if let minPrice, minPrice < 0 {
            errorMessage = "最低价不能为负数"
            return nil
        }
        if let maxPrice, maxPrice < 0 {
            errorMessage = "最高价不能为负数"
            return nil
        }
        if let minPrice, let maxPrice, minPrice > maxPrice {
            errorMessage = "最低价不能高于最高价"
            return nil
        }
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if keyword.count > 50 {
            errorMessage = "搜索关键词不能超过 50 个字符"
            return nil
        }
        return DishSearchFilters(
            query: keyword,
            diningHallIDs: selectedHallIDs.sorted(),
            minPrice: minPrice,
            maxPrice: maxPrice,
            minRating: rating.value,
            sort: sort,
            page: page,
            size: pageSize
        )
    }

    private func parsePrice(_ text: String) -> Decimal? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}
