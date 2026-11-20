import Combine
import Foundation

@MainActor
final class ChangePasswordViewModel: ObservableObject {
    @Published var oldPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var didSucceed = false

    private let session: AppSession

    init(session: AppSession) {
        self.session = session
    }

    func submit() async {
        guard !isSubmitting else { return }
        if let error = PasswordValidation.currentPasswordError(oldPassword) {
            errorMessage = error
            return
        }
        if let error = PasswordValidation.newPasswordError(newPassword) {
            errorMessage = error
            return
        }
        guard newPassword != oldPassword else {
            errorMessage = "新密码不能与旧密码相同"
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的新密码不一致"
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await session.changePassword(oldPassword: oldPassword, newPassword: newPassword)
            oldPassword = ""
            newPassword = ""
            confirmPassword = ""
            didSucceed = true
        } catch let error as AppError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handle(_ error: AppError) {
        switch error {
        case .validation(let fields):
            errorMessage = fields.isEmpty
                ? error.localizedDescription
                : fields.map(\.message).joined(separator: "；")
        case .rateLimited(let retryAfter):
            errorMessage = error.localizedDescription
            _ = retryAfter
        default:
            switch error.code {
            case "OLD_PASSWORD_INCORRECT":
                errorMessage = "旧密码不正确"
            case "PASSWORD_UNCHANGED":
                errorMessage = "新密码不能与旧密码相同"
            case "PASSWORD_CHANGE_CONFLICT":
                errorMessage = "账号或密码已变化，请重新登录后重试"
            case "PASSWORD_CHANGE_UNAVAILABLE":
                errorMessage = error.localizedDescription
            default:
                errorMessage = error.localizedDescription
            }
        }
    }
}
