import Combine
import Foundation

@MainActor
final class DiningHallsViewModel: ObservableObject {
    @Published private(set) var halls: [DiningHall] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let catalog: CatalogService
    private var hasLoaded = false

    init(catalog: CatalogService) {
        self.catalog = catalog
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            halls = try await catalog.diningHalls()
            hasLoaded = true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class StallsViewModel: ObservableObject {
    @Published private(set) var stalls: [Stall] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let hallID: String
    private let catalog: CatalogService
    private var hasLoaded = false

    init(hallID: String, catalog: CatalogService) {
        self.hallID = hallID
        self.catalog = catalog
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            stalls = try await catalog.stalls(diningHallID: hallID)
            hasLoaded = true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class DishesViewModel: ObservableObject {
    @Published private(set) var dishes: [DishSummary] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let stallID: String
    private let catalog: CatalogService
    private var hasLoaded = false

    init(stallID: String, catalog: CatalogService) {
        self.stallID = stallID
        self.catalog = catalog
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            dishes = try await catalog.dishes(stallID: stallID)
            hasLoaded = true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
