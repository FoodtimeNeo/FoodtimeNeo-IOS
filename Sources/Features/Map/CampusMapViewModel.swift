import Combine
import Foundation
import UIKit

@MainActor
final class CampusMapViewModel: ObservableObject {
    @Published private(set) var data: CampusMapData?
    @Published private(set) var image: UIImage?
    @Published private(set) var halls: [DiningHall] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var hallsError: String?
    @Published var selectedRegionID: String?

    private let catalog: CatalogService

    init(catalog: CatalogService) {
        self.catalog = catalog
    }

    var selectedRegion: CampusMapRegion? {
        guard let data, let selectedRegionID else { return nil }
        return data.regions.first { $0.id == selectedRegionID }
    }

    func load() async {
        guard data == nil, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            data = try CampusMapAssets.loadData()
            image = try CampusMapAssets.loadImage()
        } catch {
            errorMessage = error.localizedDescription
        }
        await loadHalls()
    }

    func loadHalls() async {
        hallsError = nil
        do {
            halls = try await catalog.diningHalls()
        } catch let error as AppError {
            hallsError = error.localizedDescription
        } catch {
            hallsError = error.localizedDescription
        }
    }

    func select(_ region: CampusMapRegion) {
        selectedRegionID = region.id
    }

    func halls(for region: CampusMapRegion) -> [DiningHall] {
        region.diningHallIds.compactMap { id in
            halls.first { $0.id == id }
        }
    }
}
