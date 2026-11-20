import Foundation

/// 管理端目录项：包含停用记录；parentId 是真实外键，编辑时不可改所属。
struct AdminCatalogItem: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let parentId: String?
    let name: String
    let description: String?
    let price: Decimal?
    let coverImageUrl: String?
    let status: String
    let sortOrder: Int?
    let revision: Int
    let priceUnit: String?
}

/// 目录新增/编辑载荷；`parentId` 只在新增时生效，编辑时服务端保持不变。
struct AdminCatalogEdit: Encodable, Equatable, Sendable {
    var parentId: String?
    var name: String
    var description: String?
    var price: Decimal?
    var coverImageUrl: String?
    var status: String
    var sortOrder: Int?
    var priceUnit: String?
}

/// 管理端正式点评；作者邮箱只在该受保护接口返回。
struct AdminReviewItem: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let dishId: String
    let userId: String
    let userDisplayName: String
    let rating: Int
    let content: String
    let createdAt: Date?
    let updatedAt: Date?
    let dishName: String
    let stallId: String?
    let stallName: String?
    let diningHallId: String?
    let diningHallName: String?
    let aiRiskLevel: String?
    let aiConfidence: Double?
    let aiLabels: [String]?
    let aiReason: String?
    let aiCheckedAt: Date?
    let userEmail: String?
}

struct AdminCatalogImage: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let imageUrl: String
}

enum AdminCatalogKind: String, CaseIterable, Identifiable {
    case diningHalls = "dining-halls"
    case stalls = "stalls"
    case dishes = "dishes"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diningHalls: return "食堂"
        case .stalls: return "档口"
        case .dishes: return "菜品"
        }
    }

    var parentKind: AdminCatalogKind? {
        switch self {
        case .diningHalls: return nil
        case .stalls: return .diningHalls
        case .dishes: return .stalls
        }
    }

    var requiresPrice: Bool {
        self == .dishes
    }
}
