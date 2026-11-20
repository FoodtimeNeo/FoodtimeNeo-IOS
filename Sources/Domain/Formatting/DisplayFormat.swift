import Foundation

enum DisplayFormat {
    static func price(_ value: Decimal?) -> String {
        guard let value else { return "价格待补充" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let text = formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0.00"
        return "¥\(text)"
    }

    static func score(_ value: Double?, reviewCount: Int) -> String {
        guard let value else { return "暂无评分（\(reviewCount)）" }
        return String(format: "%.1f 分 · %d 条点评", value, reviewCount)
    }

    static func dateTime(_ value: Date?) -> String {
        guard let value else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: value)
    }

    static func relativeTime(_ value: Date?, now: Date = Date()) -> String {
        guard let value else { return "" }
        let seconds = max(0, now.timeIntervalSince(value))
        if seconds < 60 { return "刚刚" }
        if seconds < 3_600 { return "\(Int(seconds / 60)) 分钟前" }
        if seconds < 86_400 { return "\(Int(seconds / 3_600)) 小时前" }
        if seconds < 604_800 { return "\(Int(seconds / 86_400)) 天前" }
        return dateTime(value)
    }
}
