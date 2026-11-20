import Foundation

enum SchoolEmailValidation {
    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func error(_ raw: String) -> String? {
        let email = normalized(raw)
        guard !email.isEmpty else { return "请输入学校邮箱" }
        guard email.count <= 254 else { return "学校邮箱不能超过 254 位" }
        guard email.range(of: #"^[0-9]+@bjtu\.edu\.cn$"#, options: .regularExpression) != nil else {
            return "学校邮箱须为数字@bjtu.edu.cn"
        }
        return nil
    }
}
