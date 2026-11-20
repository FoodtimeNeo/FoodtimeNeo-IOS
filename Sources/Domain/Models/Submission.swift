import Foundation

struct UploadedImage: Codable, Equatable, Sendable {
    let id: String
    let imageUrl: String
    let width: Int
    let height: Int
}

struct CatalogSubmissionReceipt: Codable, Equatable, Sendable {
    let id: String
    let status: String
    let createdAt: Date?
}

struct DishSubmission: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let stallId: String
    let stallName: String
    let diningHallId: String
    let diningHallName: String
    let name: String
    let description: String?
    let price: Decimal?
    let imageUrl: String
    let status: String
    let reviewedAt: Date?
    let reviewReason: String?
    let approvedDishId: String?
    let createdAt: Date?
    let updatedAt: Date?

    var statusLabel: String { SubmissionStatus.label(status) }
}

struct StallSubmission: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let diningHallId: String
    let diningHallName: String
    let name: String
    let description: String?
    let coverImageUrl: String
    let status: String
    let reviewedAt: Date?
    let reviewReason: String?
    let approvedStallId: String?
    let createdAt: Date?
    let updatedAt: Date?

    var statusLabel: String { SubmissionStatus.label(status) }
}

enum SubmissionStatus {
    static func label(_ status: String) -> String {
        switch status {
        case "pending": return "待审核"
        case "approved": return "已通过"
        case "rejected": return "已驳回"
        default: return "状态更新中"
        }
    }
}

struct ImageSubmission: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let dishId: String
    let dishName: String
    let stallId: String
    let stallName: String
    let diningHallId: String
    let diningHallName: String
    let imageUrl: String
    let status: String
    let reviewedAt: Date?
    let reviewReason: String?
    let createdAt: Date?

    var statusLabel: String {
        switch status {
        case "pending": return "待审核"
        case "approved": return "已通过"
        case "rejected": return "已驳回"
        default: return "状态更新中"
        }
    }
}
