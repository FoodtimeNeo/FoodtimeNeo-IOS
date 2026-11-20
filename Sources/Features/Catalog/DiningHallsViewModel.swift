import Combine
import Foundation

@MainActor
final class DiningHallsViewModel: ObservableObject {
    @Published private(set) var halls: [DiningHall] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var recommendations: DailyRecommendations?
    @Published private(set) var isLoadingRecommendations = false
    @Published var recommendationError: String?

    private let catalog: CatalogService
    private var hasLoaded = false
    private var hasLoadedRecommendations = false

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

    func loadRecommendationsIfNeeded() async {
        guard !hasLoadedRecommendations else { return }
        await loadRecommendations()
    }

    func loadRecommendations() async {
        guard !isLoadingRecommendations else { return }
        isLoadingRecommendations = true
        recommendationError = nil
        defer { isLoadingRecommendations = false }
        do {
            recommendations = try await catalog.dailyRecommendations()
            hasLoadedRecommendations = true
        } catch let error as AppError {
            recommendationError = error.localizedDescription
        } catch {
            recommendationError = error.localizedDescription
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
