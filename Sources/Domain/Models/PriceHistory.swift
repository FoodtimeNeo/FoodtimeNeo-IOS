import Foundation

struct PriceHistoryEntry: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let price: Decimal?
    let priceUnit: String
    let recordedAt: Date?
    let origin: String
    let revision: Int
    let carriedForward: Bool
}

struct DishPriceHistory: Codable, Equatable, Sendable {
    let dishId: String
    let dishName: String
    let currentPrice: Decimal?
    let priceUnit: String
    let revision: Int
    let windowStart: Date?
    let windowEnd: Date?
    let canManage: Bool
    let totalRecords: Int
    let records: [PriceHistoryEntry]
}

struct PriceHistoryPoint: Equatable, Sendable {
    let entry: PriceHistoryEntry
    let time: Date
}

struct PriceHistoryRun: Equatable, Sendable {
    let unit: String?
    let start: Date
    let end: Date
    let points: [PriceHistoryPoint]
}

enum PriceUnit {
    static func label(_ raw: String) -> String {
        switch raw {
        case "serving": return "份"
        case "piece": return "个"
        case "bowl": return "碗"
        case "jin": return "斤"
        case "100g": return "100克"
        case "kg": return "公斤"
        case "unspecified", "": return "未注明"
        default: return raw
        }
    }
}

enum PriceHistoryBuilder {
    /// Mirrors the server/Android renderer: a unit change or a null price ends
    /// the current run; consecutive equal prices collapse; a run starts at the
    /// first point and ends at the query window end.
    static func runs(_ history: DishPriceHistory) -> [PriceHistoryRun] {
        let windowStart = history.windowStart ?? Date(timeIntervalSince1970: 0)
        let windowEnd = history.windowEnd ?? Date()
        var result: [PriceHistoryRun] = []
        var points: [PriceHistoryPoint] = []
        var unit: String?
        var start = windowStart

        for row in history.records {
            let time = max(windowStart, row.recordedAt ?? windowStart)
            if !points.isEmpty, row.price == nil || unit != row.priceUnit {
                result.append(PriceHistoryRun(unit: unit, start: start, end: time, points: points))
                points = []
            }
            guard let price = row.price else { continue }
            if points.isEmpty {
                unit = row.priceUnit
                start = time
            }
            if points.last?.entry.price != price {
                points.append(PriceHistoryPoint(entry: row, time: time))
            }
        }
        if !points.isEmpty {
            result.append(PriceHistoryRun(unit: unit, start: start, end: windowEnd, points: points))
        }
        return result
    }
}
