import Foundation

/// 目录纠错提案；整单通过或拒绝，审核时同时校验提案与目录基线修订号。
struct AdminCorrection: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let targetType: String
    let targetId: String
    let targetSummary: String
    let baseRevision: Int
    let originalName: String?
    let originalDescription: String?
    let originalPrice: Decimal?
    let proposedName: String?
    let proposedDescription: String?
    let proposedPrice: Decimal?
    let changedFields: [String]
    let reason: String
    let status: String
    let reviewNote: String?
    let createdAt: Date?
    let reviewedAt: Date?
    let revision: Int
    let evidenceUrls: [String]
    let originalPriceUnit: String?
    let proposedPriceUnit: String?
}

struct AdminCorrectionRow: Codable, Identifiable, Equatable, Sendable {
    let correction: AdminCorrection
    let submitterId: String?
    let submitterName: String?
    let submitterEmail: String?

    var id: String { correction.id }
}

enum AdminCorrectionTarget: String, CaseIterable, Identifiable {
    case diningHall = "dining_hall"
    case stall
    case dish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diningHall: return "食堂"
        case .stall: return "档口"
        case .dish: return "菜品"
        }
    }
}
