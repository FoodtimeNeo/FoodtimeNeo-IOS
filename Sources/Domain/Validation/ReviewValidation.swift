import Foundation

enum ReviewValidation {
    static func normalizedContent(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func ratingError(_ rating: Int) -> String? {
        (1...5).contains(rating) ? nil : "请选择 1–5 星评分"
    }

    static func contentError(_ raw: String) -> String? {
        let content = normalizedContent(raw)
        guard !content.isEmpty else { return "请填写点评正文" }
        guard content.count <= 500 else { return "点评正文不能超过 500 字" }
        return nil
    }
}
