import Combine
import Foundation

@MainActor
final class PriceHistoryViewModel: ObservableObject {
    @Published private(set) var history: DishPriceHistory?
    @Published private(set) var days = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let dishID: String
    private let catalog: CatalogService

    init(dishID: String, catalog: CatalogService) {
        self.dishID = dishID
        self.catalog = catalog
    }

    var runs: [PriceHistoryRun] {
        guard let history else { return [] }
        return PriceHistoryBuilder.runs(history)
    }

    func load(days: Int) async {
        guard !isLoading else { return }
        self.days = [0, 30, 90].contains(days) ? days : 0
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            history = try await catalog.priceHistory(dishID: dishID, days: self.days)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
