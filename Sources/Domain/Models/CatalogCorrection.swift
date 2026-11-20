import Foundation

struct CatalogCorrection: Codable, Identifiable, Equatable, Sendable {
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

    var statusLabel: String {
        switch status {
        case "approved": return "已通过"
        case "rejected": return "未通过"
        default: return "待核对"
        }
    }

    var isPending: Bool { status == "pending" }

    /// 逐字段的“原值 → 提案值”摘要，跟随 `changedFields` 的顺序。
    var changeDescriptions: [String] {
        changedFields.map { field in
            switch field {
            case "name":
                return "名称：\(originalName ?? "（空）") → \(proposedName ?? "（空）")"
            case "description":
                return "介绍：\(text(originalDescription)) → \(text(proposedDescription))"
            case "price":
                return "价格：\(price(originalPrice)) → \(price(proposedPrice))"
            case "priceUnit":
                return "计价单位：\(PriceUnit.label(originalPriceUnit ?? "")) → \(PriceUnit.label(proposedPriceUnit ?? ""))"
            default:
                return field
            }
        }
    }

    private func text(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "（空）" }
        return value
    }

    private func price(_ value: Decimal?) -> String {
        guard let value else { return "未知" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return "¥" + (formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0")
    }
}

/// 提交纠错时的领域输入。未在 `changedFields` 中的值不会应用。
struct CorrectionProposal: Encodable, Equatable, Sendable {
    let targetType: String
    let targetId: String
    let baseRevision: Int
    let changedFields: [String]
    let name: String?
    let description: String?
    let price: Decimal?
    let priceUnit: String?
    let reason: String
    let evidenceUrls: [String]
    let idempotencyKey: String

    /// 用于判断同一幂等键是否被复用于不同内容。
    var fingerprint: String {
        [
            targetType,
            targetId,
            String(baseRevision),
            changedFields.joined(separator: ","),
            name ?? "\u{0}",
            description ?? "\u{0}",
            price.map { "\($0)" } ?? "\u{0}",
            priceUnit ?? "\u{0}",
            reason,
            evidenceUrls.joined(separator: ",")
        ].joined(separator: "\u{1}")
    }
}

enum CorrectionPriceUnits {
    static let values = ["unspecified", "serving", "piece", "bowl", "jin", "100g", "kg"]

    static func label(_ value: String) -> String {
        PriceUnit.label(value)
    }
}
