import Combine
import Foundation

@MainActor
final class RegistrationViewModel: ObservableObject {
    @Published var email = ""
    @Published var emailCode = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var invitationCode = ""
    @Published private(set) var policy: RegistrationPolicy?
    @Published private(set) var isLoadingPolicy = false
    @Published private(set) var isSendingCode = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var resendRemaining = 0
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published private(set) var registeredUser: User?

    private let session: AppSession
    private var countdownTask: Task<Void, Never>?

    init(session: AppSession) {
        self.session = session
    }

    var isClosed: Bool {
        policy?.mode == .closed
    }

    var invitationRequired: Bool {
        policy?.invitationRequired ?? false
    }

    var canSendCode: Bool {
        guard let policy, policy.mode != .closed, policy.canSendEmailCode else { return false }
        return !isSendingCode && resendRemaining == 0
    }

    var policyText: String {
        guard let policy else { return "正在读取注册策略…" }
        switch policy.mode {
        case .open:
            return "邀请码可选；学校邮箱可在注册后绑定。"
        case .invitation:
            return "当前注册需要平台发放的 12 位邀请码，大小写均可。"
        case .closed:
            return "注册暂未开放：当前部署已关闭注册与邮箱验证码发送。"
        }
    }

    var resendLabel: String {
        if isSendingCode { return "发送中…" }
        if resendRemaining > 0 { return "\(resendRemaining) 秒后重发" }
        return "获取验证码"
    }

    func loadPolicy() async {
        guard !isLoadingPolicy else { return }
        isLoadingPolicy = true
        errorMessage = nil
        defer { isLoadingPolicy = false }
        do {
            policy = try await session.registrationPolicy()
            if policy?.mode == .closed {
                infoMessage = "当前部署已关闭注册与邮箱验证码发送。"
            }
        } catch {
            policy = nil
            errorMessage = "无法读取注册策略：\(error.localizedDescription)"
        }
    }

    func sendCode() async {
        guard !isSendingCode, resendRemaining == 0 else { return }
        guard let policy, policy.mode != .closed else {
            errorMessage = "当前暂未开放注册"
            return
        }
        guard policy.canSendEmailCode else {
            errorMessage = "当前邮箱验证码发送未启用，请联系管理员"
            return
        }
        if let error = RegistrationValidation.emailError(email) {
            errorMessage = error
            return
        }

        isSendingCode = true
        errorMessage = nil
        infoMessage = nil
        defer { isSendingCode = false }
        do {
            let receipt = try await session.sendRegistrationCode(email: email)
            infoMessage = "验证码已发送到 \(RegistrationValidation.normalizedEmail(email))，请检查收件箱和垃圾邮件。"
            startCountdown(max(1, receipt.resendAfterSeconds))
        } catch let error as AppError {
            handleCodeSendError(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submit() async {
        guard !isSubmitting else { return }
        guard let policy else {
            errorMessage = "注册策略尚未读取，请稍后重试"
            return
        }
        guard policy.mode != .closed else {
            errorMessage = "注册暂未开放"
            return
        }

        if let error = RegistrationValidation.emailError(email) {
            errorMessage = error
            return
        }
        if let error = RegistrationValidation.emailCodeError(emailCode) {
            errorMessage = error
            return
        }
        if let error = RegistrationValidation.passwordError(password) {
            errorMessage = error
            return
        }
        guard password == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            return
        }
        if let error = RegistrationValidation.invitationError(
            invitationCode,
            required: policy.invitationRequired
        ) {
            errorMessage = error
            return
        }

        isSubmitting = true
        errorMessage = nil
        infoMessage = nil
        defer { isSubmitting = false }
        do {
            let normalizedInvitation = RegistrationValidation.normalizedInvitationCode(invitationCode)
            let user = try await session.register(
                email: email,
                password: password,
                verificationCode: emailCode,
                invitationCode: normalizedInvitation.isEmpty ? nil : normalizedInvitation
            )
            registeredUser = user
            infoMessage = "注册成功，请使用该邮箱登录。"
            stopCountdown()
        } catch let error as AppError {
            handleRegistrationError(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleCodeSendError(_ error: AppError) {
        switch error {
        case .rateLimited(let retryAfter):
            if let retryAfter, retryAfter > 0 {
                startCountdown(retryAfter)
            }
            errorMessage = error.localizedDescription
        default:
            errorMessage = error.localizedDescription
        }
    }

    private func handleRegistrationError(_ error: AppError) {
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
            case "EMAIL_ALREADY_REGISTERED":
                errorMessage = "该邮箱已注册，请直接登录或找回密码"
            case "EMAIL_CODE_INVALID":
                errorMessage = "邮箱验证码错误、已过期或尝试次数过多，请重新获取"
            case "REGISTRATION_CLOSED":
                errorMessage = "注册暂未开放，正在重新读取服务器策略"
                Task { await loadPolicy() }
            case "INVITATION_REQUIRED":
                errorMessage = "当前注册需要平台发放的邀请码"
            case "INVITATION_CODE_INVALID":
                errorMessage = "邀请码无效、过期或次数已用尽"
            case "REGISTRATION_IN_PROGRESS":
                errorMessage = "该邮箱的注册正在处理中，请稍后重试"
            case "CLIENT_UNKNOWN":
                errorMessage = "客户端未获服务端授权（CLIENT_UNKNOWN）；需要后端把 ios 加入客户端白名单"
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
