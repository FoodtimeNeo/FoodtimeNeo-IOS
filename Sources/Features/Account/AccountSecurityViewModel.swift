import Combine
import Foundation

@MainActor
final class AccountSecurityViewModel: ObservableObject {
    @Published private(set) var summary: AccountLifecycleSummary?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    @Published var schoolEmail = ""
    @Published var bindCode = ""
    @Published private(set) var isSendingBind = false
    @Published private(set) var bindResendRemaining = 0
    @Published private(set) var isBinding = false

    @Published var unbindCode = ""
    @Published private(set) var isSendingUnbind = false
    @Published private(set) var unbindResendRemaining = 0
    @Published private(set) var isUnbinding = false
    @Published var acceptedUnbind = false

    @Published var deleteCode = ""
    @Published private(set) var isSendingDelete = false
    @Published private(set) var isDeleting = false
    @Published var acceptedDeletion = false
    @Published private(set) var deleteCodeSent = false
    @Published private(set) var deletionReceipt: AccountDeletionResult?
    @Published private(set) var unbindReceipt: SchoolEmailUnbindResult?

    private let session: AppSession
    private var bindCountdown: Task<Void, Never>?
    private var unbindCountdown: Task<Void, Never>?

    init(session: AppSession) {
        self.session = session
    }

    var canBind: Bool {
        summary?.schoolEmail == nil && summary?.canDelete == true
    }

    var canUnbind: Bool {
        summary?.canUnbind == true
    }

    var bindResendLabel: String {
        if isSendingBind { return "发送中…" }
        if bindResendRemaining > 0 { return "\(bindResendRemaining) 秒后重发" }
        return "发送验证码"
    }

    var unbindResendLabel: String {
        if isSendingUnbind { return "发送中…" }
        if unbindResendRemaining > 0 { return "\(unbindResendRemaining) 秒后重发" }
        return "发送验证码"
    }

    var deleteSendDisabled: Bool {
        if isSendingDelete || deleteCodeSent { return true }
        if let date = summary?.deletionCodeAvailableAt, date > Date() { return true }
        return false
    }

    var deleteAvailabilityText: String {
        if deleteCodeSent {
            return "今天已发送注销验证码，不能在今天再次发送；请检查邮箱，验证码 15 分钟内有效。"
        }
        if let date = summary?.deletionCodeAvailableAt, date > Date() {
            return "今天已申请注销验证码，可再次发送时间：\(DisplayFormat.dateTime(date))。"
        }
        return "注销验证码每天只能成功发送一次（UTC+8 00:00 重置），15 分钟内有效。"
    }

    func loadSummary() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let summary = try await session.accountLifecycle()
            self.summary = summary
            if !summary.canDelete {
                infoMessage = "此账号不能注销或变更学校邮箱。管理员与超级管理员需保留账号。"
            }
            if let date = summary.deletionCodeAvailableAt, date > Date() {
                deleteCodeSent = true
            }
        } catch let error as AppError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendBindCode() async {
        guard !isSendingBind, bindResendRemaining == 0 else { return }
        if let error = SchoolEmailValidation.error(schoolEmail) {
            errorMessage = error
            return
        }
        isSendingBind = true
        errorMessage = nil
        infoMessage = nil
        defer { isSendingBind = false }
        do {
            let receipt = try await session.sendSchoolEmailCode(email: schoolEmail)
            infoMessage = "验证码已发送到学校邮箱，15 分钟内有效。"
            startBindCountdown(max(1, receipt.resendAfterSeconds))
        } catch let error as AppError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func bindSchoolEmail() async {
        guard !isBinding else { return }
        if let error = SchoolEmailValidation.error(schoolEmail) {
            errorMessage = error
            return
        }
        if let error = RegistrationValidation.emailCodeError(bindCode) {
            errorMessage = error
            return
        }
        isBinding = true
        errorMessage = nil
        infoMessage = nil
        defer { isBinding = false }
        do {
            _ = try await session.bindSchoolEmail(email: schoolEmail, verificationCode: bindCode)
            infoMessage = "学校邮箱绑定成功。"
            schoolEmail = ""
            bindCode = ""
            await loadSummary()
        } catch let error as AppError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendUnbindCode() async {
        guard canUnbind, !isSendingUnbind, unbindResendRemaining == 0 else { return }
        isSendingUnbind = true
        errorMessage = nil
        infoMessage = nil
        defer { isSendingUnbind = false }
        do {
            let receipt = try await session.sendAccountLifecycleCode(.unbind)
            if let school = summary?.schoolEmail, receipt.verificationEmail != school {
                errorMessage = "验证邮箱已变化，请重新读取账号状态"
                return
            }
            infoMessage = "验证码已发送到当前学校邮箱，15 分钟内有效，60 秒后可重发。"
            startUnbindCountdown(60)
        } catch let error as AppError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unbindSchoolEmail() async {
        guard canUnbind, acceptedUnbind, !isUnbinding else { return }
        if let error = RegistrationValidation.emailCodeError(unbindCode) {
            errorMessage = error
            return
        }
        isUnbinding = true
        errorMessage = nil
        infoMessage = nil
        defer { isUnbinding = false }
        do {
            let result = try await session.unbindSchoolEmail(verificationCode: unbindCode)
            unbindReceipt = result
            unbindCode = ""
            acceptedUnbind = false
            infoMessage = "学校邮箱已解绑。"
            await loadSummary()
        } catch let error as AppError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendDeleteCode() async {
        guard summary?.canDelete == true, !isSendingDelete, !deleteSendDisabled else { return }
        isSendingDelete = true
        errorMessage = nil
        infoMessage = nil
        defer { isSendingDelete = false }
        do {
            let receipt = try await session.sendAccountLifecycleCode(.delete)
            if let expected = summary?.verificationEmail, receipt.verificationEmail != expected {
                errorMessage = "验证邮箱已变化，请重新读取账号状态"
                return
            }
            deleteCodeSent = true
            infoMessage = "注销验证码已发送，今天不能再次发送；请在 15 分钟内验证。"
            if let next = receipt.nextSendAt {
                infoMessage = "注销验证码已发送；可再次发送时间：\(DisplayFormat.dateTime(next))。"
            }
        } catch let error as AppError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAccount() async {
        guard summary?.canDelete == true, acceptedDeletion, !isDeleting else { return }
        if let error = RegistrationValidation.emailCodeError(deleteCode) {
            errorMessage = error
            return
        }
        isDeleting = true
        errorMessage = nil
        infoMessage = nil
        defer { isDeleting = false }
        do {
            let result = try await session.deleteAccount(verificationCode: deleteCode)
            deletionReceipt = result
            deleteCode = ""
            acceptedDeletion = false
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
        case .rateLimited:
            errorMessage = error.localizedDescription
        default:
            switch error.code {
            case "ACCOUNT_ACTION_FORBIDDEN":
                errorMessage = "管理员和超级管理员不能注销、绑定或解绑学校邮箱"
            case "ACCOUNT_ACTION_CODE_INVALID":
                errorMessage = "验证码错误或已过期，请重新获取"
            case "ACCOUNT_ACTION_IN_PROGRESS":
                errorMessage = "操作正在处理中，请稍后重试"
            case "DELETION_CODE_DAILY_LIMIT":
                deleteCodeSent = true
                errorMessage = "今天已申请注销验证码，请检查邮箱或明天再试"
            case "SCHOOL_EMAIL_ALREADY_BOUND":
                errorMessage = "当前账号已绑定学校邮箱"
            case "SCHOOL_EMAIL_TAKEN":
                errorMessage = "该学校邮箱已被其他账号绑定"
            case "SCHOOL_EMAIL_NOT_BOUND":
                errorMessage = "当前未绑定学校邮箱"
            default:
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startBindCountdown(_ seconds: Int) {
        bindCountdown?.cancel()
        bindResendRemaining = seconds
        bindCountdown = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.bindResendRemaining = max(0, self.bindResendRemaining - 1)
                if self.bindResendRemaining == 0 { return }
            }
        }
    }

    private func startUnbindCountdown(_ seconds: Int) {
        unbindCountdown?.cancel()
        unbindResendRemaining = seconds
        unbindCountdown = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.unbindResendRemaining = max(0, self.unbindResendRemaining - 1)
                if self.unbindResendRemaining == 0 { return }
            }
        }
    }
}
