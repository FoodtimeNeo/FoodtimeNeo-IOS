import Foundation

final class RemoteCatalogService: CatalogService {
    let mediaBaseURL: URL
    private let api: APIClient

    init(api: APIClient, baseURL: URL) {
        self.api = api
        self.mediaBaseURL = baseURL
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

    func dishDetail(id: String) async throws -> DishDetail {
        try await api.send(.get("dishes/\(percentEncoded(id))"), as: DishDetail.self)
    }

    func dishImages(id: String, page: Int, size: Int) async throws -> Page<DishImage> {
        try await api.send(
            .get(
                "dishes/\(percentEncoded(id))/images",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<DishImage>.self
        )
    }

    func dishRating(id: String) async throws -> DishRatingSummary {
        try await api.send(
            .get("dishes/\(percentEncoded(id))/rating"),
            as: DishRatingSummary.self
        )
    }

    func priceHistory(dishID: String, days: Int) async throws -> DishPriceHistory {
        let window = [0, 30, 90].contains(days) ? days : 0
        return try await api.send(
            .get(
                "dishes/\(percentEncoded(dishID))/price-history",
                query: [URLQueryItem(name: "days", value: String(window))]
            ),
            as: DishPriceHistory.self
        )
    }

    private func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func percentEncoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
