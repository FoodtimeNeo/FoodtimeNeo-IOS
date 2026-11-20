import Foundation

struct DiningHall: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let coverImageUrl: String?
    let description: String?
    let latitude: Double?
    let longitude: Double?
    let revision: Int
}

struct Stall: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let diningHallId: String
    let name: String
    let coverImageUrl: String?
    let description: String?
    let revision: Int
}

struct DishSummary: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let stallId: String
    let name: String
    let price: Decimal?
    let averageScore: Double?
    let reviewCount: Int
}
