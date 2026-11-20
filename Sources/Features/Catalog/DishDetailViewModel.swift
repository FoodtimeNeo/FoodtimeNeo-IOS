import Combine
import Foundation

@MainActor
final class DishDetailViewModel: ObservableObject {
    @Published private(set) var detail: DishDetail?
    @Published private(set) var images: [DishImage] = []
    @Published private(set) var rating: DishRatingSummary?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let dishID: String
    private let catalog: CatalogService

    init(dishID: String, catalog: CatalogService) {
        self.dishID = dishID
        self.catalog = catalog
    }

    var imageURLs: [URL] {
        images.compactMap { MediaURL.resolve($0.imageUrl, baseURL: catalog.mediaBaseURL) }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detail = try await catalog.dishDetail(id: dishID)
            images = (try? await catalog.dishImages(id: dishID, page: 1, size: 100))?.items ?? []
            rating = try? await catalog.dishRating(id: dishID)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
