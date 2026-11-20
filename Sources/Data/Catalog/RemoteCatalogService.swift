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

    func searchDishes(_ filters: DishSearchFilters) async throws -> Page<DishSearchRow> {
        var query: [URLQueryItem] = []
        let keyword = filters.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            query.append(URLQueryItem(name: "q", value: keyword))
        }
        for hallID in filters.diningHallIDs {
            query.append(URLQueryItem(name: "diningHallIds", value: hallID))
        }
        if let minPrice = filters.minPrice {
            query.append(URLQueryItem(name: "minPrice", value: decimalString(minPrice)))
        }
        if let maxPrice = filters.maxPrice {
            query.append(URLQueryItem(name: "maxPrice", value: decimalString(maxPrice)))
        }
        if let minRating = filters.minRating {
            query.append(URLQueryItem(name: "minRating", value: String(format: "%.1f", minRating)))
        }
        query.append(URLQueryItem(name: "sort", value: filters.sort.rawValue))
        query.append(URLQueryItem(name: "page", value: String(max(1, filters.page))))
        query.append(URLQueryItem(name: "size", value: String(min(100, max(1, filters.size)))))

        return try await api.send(
            .get("dishes/search", query: query),
            as: Page<DishSearchRow>.self
        )
    }

    private func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func percentEncoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
