import Foundation

struct RecommendedDish: Codable, Identifiable, Equatable, Sendable {
    let dishId: String
    let dishName: String
    let diningHallId: String
    let diningHallName: String
    let stallId: String
    let stallName: String
    let averageRating: Double?
    let reviewCount: Int
    let imageUrl: String?
    let recommendationType: String
    let recommendationScore: Double
    let reasonCode: String
    let reason: String

    var id: String { dishId }
}

struct DailyRecommendations: Codable, Equatable, Sendable {
    let date: String
    let algorithmVersion: String
    let total: Int
    let items: [RecommendedDish]
}
