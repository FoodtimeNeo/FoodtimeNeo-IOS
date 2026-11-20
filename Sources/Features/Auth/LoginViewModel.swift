import Combine
import Foundation
import UIKit

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var captchaAnswer = ""
    @Published private(set) var captchaImage: UIImage?
    @Published private(set) var captchaHint = ""
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let session: AppSession
    private var challengeId: String?

    init(session: AppSession) {
        self.session = session
    }

    func submit() async {
        guard !isSubmitting else { return }
        errorMessage = nil

        let account = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty, !password.isEmpty else {
            errorMessage = "请输入邮箱和密码"
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let answer = captchaAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        let captcha = challengeId.map { CaptchaAnswer(challengeId: $0, answer: answer) }
        do {
            try await session.login(account: account, password: password, captcha: captcha)
            password = ""
            captchaAnswer = ""
            challengeId = nil
            captchaImage = nil
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            if error.code == "CAPTCHA_REQUIRED" || error.code == "CAPTCHA_INVALID" {
                await loadCaptcha()
                captchaAnswer = ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCaptcha() async {
        do {
            let challenge = try await session.requestCaptcha()
            guard let data = Data(base64Encoded: challenge.imageBase64),
                  let image = UIImage(data: data) else {
                throw AppError.invalidResponse(message: "验证码图片无法解析")
            }
            challengeId = challenge.challengeId
            captchaImage = image
            captchaHint = "请输入图片中的答案；2 分钟内有效。"
        } catch let error as AppError {
            challengeId = nil
            captchaImage = nil
            captchaHint = error.localizedDescription
        } catch {
            challengeId = nil
            captchaImage = nil
            captchaHint = error.localizedDescription
        }
    }
}
