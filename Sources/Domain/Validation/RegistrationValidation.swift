import Foundation

/// Client-side shape checks only. The server remains the authority for the
/// email-domain whitelist, invitation validity, rate limits and account state.
enum RegistrationValidation {
    static func normalizedEmail(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func emailError(_ raw: String) -> String? {
        let email = normalizedEmail(raw)
        guard !email.isEmpty else { return "请输入邮箱" }
        guard email.count <= 254 else { return "邮箱不能超过 254 位" }
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        guard email.range(of: pattern, options: .regularExpression) != nil else {
            return "请输入有效的邮箱地址"
        }
        return nil
    }

    static func passwordError(_ raw: String) -> String? {
        let scalars = raw.unicodeScalars
        guard (8...128).contains(scalars.count) else {
            return "密码长度须为 8 至 128 位"
        }
        guard scalars.allSatisfy({ (33...126).contains($0.value) }) else {
            return "密码只能使用英文字母、数字和 ASCII 半角符号，不能包含空格或中文"
        }
        let hasLetter = scalars.contains { (65...90).contains($0.value) || (97...122).contains($0.value) }
        let hasDigit = scalars.contains { (48...57).contains($0.value) }
        guard hasLetter, hasDigit else {
            return "密码至少包含一个英文字母和一个数字"
        }
        return nil
    }

    static func emailCodeError(_ raw: String) -> String? {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 6, code.unicodeScalars.allSatisfy({ (48...57).contains($0.value) }) else {
            return "请输入 6 位邮箱验证码"
        }
        return nil
    }

    static func normalizedInvitationCode(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func invitationError(_ raw: String, required: Bool) -> String? {
        let code = normalizedInvitationCode(raw)
        if code.isEmpty {
            return required ? "当前注册需要平台发放的 12 位邀请码" : nil
        }
        let pattern = #"^[A-HJ-NP-Z2-9]{12}$"#
        guard code.range(of: pattern, options: .regularExpression) != nil else {
            return "邀请码为 12 位发放字符"
        }
        return nil
    }
}
