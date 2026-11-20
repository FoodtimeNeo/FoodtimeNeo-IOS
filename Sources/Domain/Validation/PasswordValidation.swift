import Foundation

enum PasswordValidation {
    /// Old/current passwords only keep the transport shape rule; login never
    /// re-runs registration complexity rules.
    static func currentPasswordError(_ raw: String) -> String? {
        let scalars = raw.unicodeScalars
        guard (8...128).contains(scalars.count) else {
            return "密码长度须为 8 至 128 位"
        }
        guard scalars.allSatisfy({ (33...126).contains($0.value) }) else {
            return "密码只能使用英文字母、数字和 ASCII 半角符号，不能包含空格或中文"
        }
        return nil
    }

    /// New passwords for registration, reset and change share the same rules.
    static func newPasswordError(_ raw: String) -> String? {
        RegistrationValidation.passwordError(raw)
    }

    static func resetTokenError(_ raw: String) -> String? {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.range(of: #"^[A-Za-z0-9_-]{43}$"#, options: .regularExpression) != nil else {
            return "验证已失效，请重新验证邮箱"
        }
        return nil
    }
}
