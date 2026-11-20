import Foundation

enum ProfileValidation {
    static func normalizedDisplayName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func displayNameError(_ raw: String) -> String? {
        let name = normalizedDisplayName(raw)
        guard !name.isEmpty else { return "昵称不能为空" }
        guard name.count <= 50 else { return "昵称不能超过 50 个字符" }
        return nil
    }
}
