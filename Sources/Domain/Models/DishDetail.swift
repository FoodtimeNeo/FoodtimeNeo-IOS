import Foundation

struct DishDetail: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let stallId: String
    let stallName: String
    let diningHallId: String
    let diningHallName: String
    let name: String
    let description: String?
    let price: Decimal?
    let revision: Int
    /// `unspecified` 表示未注明；旧响应没有该字段时为 nil。
    let priceUnit: String? = nil
}

struct DishImage: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let dishId: String
    let imageUrl: String
    let createdAt: Date?
}

struct DishRatingSummary: Codable, Equatable, Sendable {
    let averageScore: Double?
    let reviewCount: Int
}
