import Foundation

enum FeedbackValidation {
    static func normalizedContent(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func contentError(_ raw: String) -> String? {
        let content = normalizedContent(raw)
        guard !content.isEmpty else { return "请填写反馈内容" }
        guard content.count <= 5000 else { return "反馈内容不能超过 5000 字" }
        return nil
    }
}
