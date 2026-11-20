import SwiftUI

@MainActor
struct RegistrationView: View {
    @ObservedObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: RegistrationViewModel
    private let onCompleted: (String) -> Void

    init(session: AppSession, onCompleted: @escaping (String) -> Void) {
        self.session = session
        self.onCompleted = onCompleted
        _model = StateObject(wrappedValue: RegistrationViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 16) {
                        SectionHeading(
                            index: "01.0",
                            title: "注册账号",
                            subtitle: "先验证邮箱，再创建你的干饭手账。"
                        )
                        policyCard

                        if !model.isClosed {
                            formCard
                        }

                        if let user = model.registeredUser {
                            successCard(user)
                        } else {
                            if let info = model.infoMessage, !info.isEmpty {
                                messageCard(info, color: Zine.green)
                            }
                            if let error = model.errorMessage, !error.isEmpty {
                                messageCard(error, color: Zine.red)
                            }
                        }
                    }
                    .padding(Zine.pagePadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await model.loadPolicy()
            }
        }
    }

    private var policyCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                if model.isLoadingPolicy && model.policy == nil {
                    HStack(spacing: 10) {
                        ProgressView().tint(Zine.red)
                        Text("正在读取注册策略…")
                            .font(.subheadline)
                            .foregroundStyle(Zine.muted)
                    }
                } else {
                    Text(model.policyText)
                        .font(.subheadline)
                        .foregroundStyle(model.isClosed ? Zine.red : Zine.muted)
                    if model.policy == nil {
                        Button("重新读取策略") {
                            Task { await model.loadPolicy() }
                        }
                        .buttonStyle(LinkButtonStyle())
                    } else if let policy = model.policy {
                        Text("策略版本：\(policy.revision)")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    }
                }
            }
        }
    }

    private var formCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("邮箱")
                TextField("QQ / 163 / Gmail / 学校邮箱", text: $model.email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .modifier(FormInputStyle())

                fieldLabel("邮箱验证码")
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
                    .frame(width: 128)
                    .disabled(!model.canSendCode)
                }
                if model.policy?.canSendEmailCode == false {
                    Text("当前邮箱验证码发送未启用，请联系管理员。")
                        .font(.caption)
                        .foregroundStyle(Zine.red)
                }

                fieldLabel("密码")
                SecureField("8–128 位，至少一个字母和一个数字", text: $model.password)
                    .textContentType(.newPassword)
                    .modifier(FormInputStyle())

                fieldLabel("确认密码")
                SecureField("再次输入密码", text: $model.confirmPassword)
                    .textContentType(.newPassword)
                    .modifier(FormInputStyle())

                fieldLabel(model.invitationRequired ? "邀请码（必填）" : "邀请码（可选）")
                TextField(model.invitationRequired ? "12 位发放字符" : "没有可不填", text: $model.invitationCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .modifier(FormInputStyle())
                    .onChange(of: model.invitationCode) { _, value in
                        let normalized = String(value.uppercased().prefix(12))
                        if normalized != value { model.invitationCode = normalized }
                    }

                Button {
                    Task { await model.submit() }
                } label: {
                    if model.isSubmitting {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("注册")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isSubmitting)
            }
        }
    }

    private func successCard(_ user: User) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("注册成功")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("账号 \(user.email) 已创建。注册不会自动登录，请返回登录页使用该邮箱登录。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                Button("返回登录") {
                    onCompleted(user.email)
                    dismiss()
                }
                .buttonStyle(InkButtonStyle(primary: true))
            }
        }
    }

    private func messageCard(_ text: String, color: Color) -> some View {
        PaperCard {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(color)
                .accessibilityLabel(text)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Zine.muted)
    }
}

