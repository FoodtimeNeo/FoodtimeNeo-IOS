import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    let code: String
    let message: String
    let data: T?
    let timestamp: String?
    let requestId: String?
}

struct ErrorEnvelope: Decodable {
    let code: String
    let message: String
    let requestId: String?
}

struct ValidationEnvelope: Decodable {
    let code: String
    let message: String
    let data: [FieldError]?
    let requestId: String?
}

struct EmptyPayload: Decodable {}

enum FoodtimeDate {
    static func parse(_ raw: String) -> Date? {
        fractional.date(from: raw) ?? plain.date(from: raw)
    }

    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
