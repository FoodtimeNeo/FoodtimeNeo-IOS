import Combine
import Foundation

@MainActor
final class PasswordRecoveryViewModel: ObservableObject {
    enum Step {
        case verifyEmail
        case setPassword
        case done
    }

    @Published var email = ""
    @Published var emailCode = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published private(set) var step: Step = .verifyEmail
    @Published private(set) var isSendingCode = false
    @Published private(set) var isVerifying = false
    @Published private(set) var isResetting = false
    @Published private(set) var resendRemaining = 0
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let session: AppSession
    private var grant: PasswordResetGrant?
    private var countdownTask: Task<Void, Never>?

    init(session: AppSession) {
        self.session = session
    }

    var canSendCode: Bool {
        !isSendingCode && resendRemaining == 0
    }

    var resendLabel: String {
        if isSendingCode { return "发送中…" }
        if resendRemaining > 0 { return "\(resendRemaining) 秒后重发" }
        return "发送验证码"
    }

    func sendCode() async {
        guard canSendCode else { return }
        if let error = RegistrationValidation.emailError(email) {
            errorMessage = error
            return
        }
        isSendingCode = true
        errorMessage = nil
        infoMessage = nil
        defer { isSendingCode = false }
        do {
            let receipt = try await session.sendPasswordResetCode(email: email)
            infoMessage = "请求已受理。若该邮箱已注册且账号可用，将收到 6 位数字验证码，10 分钟内有效。"
            startCountdown(max(1, receipt.resendAfterSeconds))
        } catch let error as AppError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyCode() async {
        guard !isVerifying else { return }
        if let error = RegistrationValidation.emailError(email) {
            errorMessage = error
            return
        }
        if let error = RegistrationValidation.emailCodeError(emailCode) {
            errorMessage = error
            return
        }
        isVerifying = true
        errorMessage = nil
        infoMessage = nil
        defer { isVerifying = false }
        do {
            let grant = try await session.verifyPasswordResetCode(
                email: email,
                verificationCode: emailCode
            )
            guard !grant.isExpired else {
                throw AppError.business(code: "PASSWORD_RESET_TOKEN_INVALID", message: "验证已过期，请重新验证邮箱")
            }
            self.grant = grant
            emailCode = ""
            step = .setPassword
            infoMessage = "邮箱验证已通过。重置后所有设备需要重新登录。"
        } catch let error as AppError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword() async {
        guard !isResetting else { return }
        guard let grant else {
            errorMessage = "验证已失效，请重新验证邮箱"
            step = .verifyEmail
            return
        }
        guard !grant.isExpired else {
            self.grant = nil
            step = .verifyEmail
            errorMessage = "验证已过期，请重新验证邮箱"
            return
        }
        if let error = PasswordValidation.newPasswordError(newPassword) {
            errorMessage = error
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的新密码不一致"
            return
        }
        isResetting = true
        errorMessage = nil
        defer { isResetting = false }
        do {
            try await session.resetPassword(resetToken: grant.resetToken, newPassword: newPassword)
            self.grant = nil
            newPassword = ""
            confirmPassword = ""
            step = .done
            stopCountdown()
        } catch let error as AppError {
            if error.code == "PASSWORD_RESET_TOKEN_INVALID" {
                self.grant = nil
                step = .verifyEmail
            }
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func backToEmail() {
        grant = nil
        step = .verifyEmail
        newPassword = ""
        confirmPassword = ""
        emailCode = ""
        errorMessage = nil
        infoMessage = nil
    }

    private func handle(_ error: AppError) {
        switch error {
        case .validation(let fields):
            errorMessage = fields.isEmpty
                ? error.localizedDescription
                : fields.map(\.message).joined(separator: "；")
        case .rateLimited(let retryAfter):
            if let retryAfter, retryAfter > 0 {
                startCountdown(retryAfter)
            }
            errorMessage = error.localizedDescription
        default:
            switch error.code {
            case "PASSWORD_RESET_CODE_INVALID":
                errorMessage = "验证码错误、已过期或尝试次数过多，请重新获取"
            case "PASSWORD_RESET_TOKEN_INVALID":
                errorMessage = "重置凭证已失效，请重新验证邮箱"
            case "PASSWORD_RESET_UNAVAILABLE":
                errorMessage = error.localizedDescription
            default:
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startCountdown(_ seconds: Int) {
        countdownTask?.cancel()
        resendRemaining = seconds
        countdownTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.resendRemaining = max(0, self.resendRemaining - 1)
                if self.resendRemaining == 0 { return }
            }
        }
    }

    private func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        resendRemaining = 0
    }
}
