import Foundation

final class RemoteCatalogService: CatalogService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func diningHalls() async throws -> [DiningHall] {
        try await api.send(.get("dining-halls"), as: [DiningHall].self)
    }

    func stalls(diningHallID: String) async throws -> [Stall] {
        let path = "dining-halls/\(percentEncoded(diningHallID))/stalls"
        return try await api.send(.get(path), as: [Stall].self)
    }

    func dishes(stallID: String) async throws -> [DishSummary] {
        let path = "stalls/\(percentEncoded(stallID))/dishes"
        return try await api.send(.get(path), as: [DishSummary].self)
    }

    private func percentEncoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
