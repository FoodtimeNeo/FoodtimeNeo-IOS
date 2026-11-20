import SwiftUI

@MainActor
struct PasswordRecoveryView: View {
    @ObservedObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: PasswordRecoveryViewModel
    private let onCompleted: (String) -> Void

    init(session: AppSession, onCompleted: @escaping (String) -> Void) {
        self.session = session
        self.onCompleted = onCompleted
        _model = StateObject(wrappedValue: PasswordRecoveryViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 16) {
                        SectionHeading(
                            index: "01.0",
                            title: "找回密码",
                            subtitle: "验证邮箱后设置新密码；重置后所有设备需要重新登录。"
                        )
                        switch model.step {
                        case .verifyEmail:
                            verifyCard
                        case .setPassword:
                            setPasswordCard
                        case .done:
                            doneCard
                        }
                    }
                    .padding(Zine.pagePadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var verifyCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("01 验证邮箱   /   02 设置新密码")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Zine.red)
                    .tracking(0.8)

                labeledField("账号绑定邮箱")
                TextField("QQ / 163 / Gmail / 学校邮箱", text: $model.email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .modifier(FormInputStyle())

                labeledField("邮箱验证码")
                HStack(spacing: 10) {
                    TextField("6 位数字", text: $model.emailCode)
                        .keyboardType(.numberPad)
                        .modifier(FormInputStyle())
                        .onChange(of: model.emailCode) { _, value in
                            let filtered = String(value.filter(\.isNumber).prefix(6))
                            if filtered != value { model.emailCode = filtered }
                        }
                    Button(model.resendLabel) {
                        Task { await model.sendCode() }
                    }
                    .buttonStyle(InkButtonStyle())
                    .frame(width: 126)
                    .disabled(!model.canSendCode)
                }

                messageView

                Button {
                    Task { await model.verifyCode() }
                } label: {
                    if model.isVerifying {
                        ProgressView().tint(Zine.onRed)
                            .accessibilityLabel("正在验证验证码")
                    } else {
                        Text("验证并继续")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isVerifying)
            }
        }
    }

    private var setPasswordCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("01 已验证邮箱   /   02 设置新密码")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Zine.red)
                    .tracking(0.8)

                if let info = model.infoMessage, !info.isEmpty {
                    Text(info)
                        .font(.subheadline)
                        .foregroundStyle(Zine.green)
                }

                labeledField("新密码")
                SecureField("8–128 位 ASCII，至少一个字母和一个数字", text: $model.newPassword)
                    .textContentType(.newPassword)
                    .modifier(FormInputStyle())

                labeledField("确认新密码")
                SecureField("再次输入新密码", text: $model.confirmPassword)
                    .textContentType(.newPassword)
                    .modifier(FormInputStyle())

                if let error = model.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Zine.red)
                }

                Button {
                    Task { await model.resetPassword() }
                } label: {
                    if model.isResetting {
                        ProgressView().tint(Zine.onRed)
                            .accessibilityLabel("正在重置密码")
                    } else {
                        Text("确认重置密码")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isResetting)

                Button("更换邮箱 / 重新验证") {
                    model.backToEmail()
                }
                .buttonStyle(LinkButtonStyle())
            }
        }
    }

    private var doneCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("密码已重置")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("请使用新密码登录。此前登录的设备需要重新登录。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                Button("返回登录") {
                    onCompleted(RegistrationValidation.normalizedEmail(model.email))
                    dismiss()
                }
                .buttonStyle(InkButtonStyle(primary: true))
            }
        }
    }

    @ViewBuilder
    private var messageView: some View {
        if let info = model.infoMessage, !info.isEmpty {
            Text(info)
                .font(.footnote)
                .foregroundStyle(Zine.green)
        }
        if let error = model.errorMessage, !error.isEmpty {
            Text(error)
                .font(.subheadline)
                .foregroundStyle(Zine.red)
        }
    }

    private func labeledField(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Zine.muted)
    }
}
