import Foundation

struct DishSearchRow: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let price: Decimal?
    let stallId: String
    let stallName: String
    let diningHallId: String
    let diningHallName: String
    let averageScore: Double?
    let reviewCount: Int
}

enum DishSort: String, CaseIterable, Identifiable, Hashable, Sendable {
    case relevance
    case priceAsc = "price_asc"
    case priceDesc = "price_desc"
    case ratingDesc = "rating_desc"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .relevance: return "综合"
        case .priceAsc: return "价格从低到高"
        case .priceDesc: return "价格从高到低"
        case .ratingDesc: return "评分优先"
        }
    }
}

enum DishRatingFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case none
    case threePointZero
    case threePointFive
    case fourPointZero
    case fourPointFive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "不限评分"
        case .threePointZero: return "3.0 分以上"
        case .threePointFive: return "3.5 分以上"
        case .fourPointZero: return "4.0 分以上"
        case .fourPointFive: return "4.5 分以上"
        }
    }

    var value: Double? {
        switch self {
        case .none: return nil
        case .threePointZero: return 3.0
        case .threePointFive: return 3.5
        case .fourPointZero: return 4.0
        case .fourPointFive: return 4.5
        }
    }
}

struct DishSearchFilters: Equatable, Sendable {
    var query: String = ""
    var diningHallIDs: [String] = []
    var minPrice: Decimal?
    var maxPrice: Decimal?
    var minRating: Double?
    var sort: DishSort = .relevance
    var page: Int = 1
    var size: Int = 20
}
