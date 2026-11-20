import SwiftUI

@MainActor
struct AccountSecurityView: View {
    private enum Confirmation: String, Identifiable {
        case unbind
        case delete

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AccountSecurityViewModel
    @State private var confirmation: Confirmation?

    init(session: AppSession) {
        _model = StateObject(wrappedValue: AccountSecurityViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 16) {
                        SectionHeading(
                            index: "03.2",
                            title: "账号安全与注销",
                            subtitle: "验证码只用于当前账号和当前邮箱；管理员不能执行这些操作。"
                        )
                        content
                        if let info = model.infoMessage, !info.isEmpty {
                            message(info, color: Zine.green)
                        }
                        if let error = model.errorMessage, !error.isEmpty {
                            message(error, color: Zine.red)
                        }
                    }
                    .padding(Zine.pagePadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("账号安全")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await model.loadSummary()
            }
            .alert(item: $confirmation) { kind in
                switch kind {
                case .unbind:
                    return Alert(
                        title: Text("确认解绑学校邮箱？"),
                        message: Text("账号保留，移除学校邮箱认证；学校邮箱冷却 1 小时后可重新绑定。"),
                        primaryButton: .destructive(Text("解绑")) {
                            Task { await model.unbindSchoolEmail() }
                        },
                        secondaryButton: .cancel(Text("取消"))
                    )
                case .delete:
                    return Alert(
                        title: Text("确认注销账号？"),
                        message: Text("立即注销且不可撤销。旧内容显示为已注销用户，新账号不继承旧数据；登录邮箱与学校邮箱冷却 1 小时后可重新使用。"),
                        primaryButton: .destructive(Text("注销")) {
                            Task { await model.deleteAccount() }
                        },
                        secondaryButton: .cancel(Text("取消"))
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.summary == nil {
            LoadingStateView(message: "正在读取账号状态…")
        } else if let error = model.errorMessage, model.summary == nil {
            ErrorStateView(message: error) {
                Task { await model.loadSummary() }
            }
        } else if let summary = model.summary {
            summaryCard(summary)
            if summary.canDelete {
                if summary.schoolEmail == nil {
                    bindCard
                } else {
                    unbindCard(summary)
                }
                deleteCard(summary)
            } else {
                PaperCard {
                    Text("此账号不能注销或变更学校邮箱。管理员与超级管理员需保留账号。")
                        .font(.subheadline)
                        .foregroundStyle(Zine.red)
                }
            }
        }
    }

    private func summaryCard(_ summary: AccountLifecycleSummary) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("当前账号")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("注销验证邮箱：\(summary.verificationEmail)")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                if let school = summary.schoolEmail {
                    Text("学校邮箱：\(school)")
                        .font(.subheadline)
                        .foregroundStyle(Zine.muted)
                } else {
                    Text("学校邮箱：未绑定")
                        .font(.subheadline)
                        .foregroundStyle(Zine.muted)
                }
                if let date = model.unbindReceipt?.schoolEmailReusableAt {
                    Text("学校邮箱可重新绑定时间：\(DisplayFormat.dateTime(date))")
                        .font(.caption)
                        .foregroundStyle(Zine.green)
                }
            }
        }
    }

    private var bindCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("绑定学校邮箱")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("仅接受数字@bjtu.edu.cn。绑定后按平台当前权限策略生效；绑定是可选的认证，不改变登录邮箱。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)

                labeledField("学校邮箱")
                TextField("20260001@bjtu.edu.cn", text: $model.schoolEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .modifier(FormInputStyle())

                labeledField("邮箱验证码")
                HStack(spacing: 10) {
                    TextField("6 位数字", text: $model.bindCode)
                        .keyboardType(.numberPad)
                        .modifier(FormInputStyle())
                        .onChange(of: model.bindCode) { _, value in
                            let filtered = String(value.filter(\.isNumber).prefix(6))
                            if filtered != value { model.bindCode = filtered }
                        }
                    Button(model.bindResendLabel) {
                        Task { await model.sendBindCode() }
                    }
                    .buttonStyle(InkButtonStyle())
                    .fixedSize(horizontal: true, vertical: false)
                    .disabled(model.isSendingBind || model.bindResendRemaining > 0)
                }

                Button {
                    Task { await model.bindSchoolEmail() }
                } label: {
                    if model.isBinding {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("绑定学校邮箱")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isBinding)
            }
        }
    }

    private func unbindCard(_ summary: AccountLifecycleSummary) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("解绑学校邮箱")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("解绑后账号保留，移除学校邮箱认证；学校邮箱冷却 1 小时后可重新绑定。验证码发送到 \(summary.schoolEmail ?? "当前学校邮箱")。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)

                labeledField("邮箱验证码")
                HStack(spacing: 10) {
                    TextField("6 位数字", text: $model.unbindCode)
                        .keyboardType(.numberPad)
                        .modifier(FormInputStyle())
                        .onChange(of: model.unbindCode) { _, value in
                            let filtered = String(value.filter(\.isNumber).prefix(6))
                            if filtered != value { model.unbindCode = filtered }
                        }
                    Button(model.unbindResendLabel) {
                        Task { await model.sendUnbindCode() }
                    }
                    .buttonStyle(InkButtonStyle())
                    .fixedSize(horizontal: true, vertical: false)
                    .disabled(!model.canUnbind || model.isSendingUnbind || model.unbindResendRemaining > 0)
                }

                Toggle("我已知晓解绑会移除学校邮箱认证及 1 小时冷却规则", isOn: $model.acceptedUnbind)
                    .tint(Zine.red)
                    .font(.footnote)

                Button("解绑学校邮箱") {
                    confirmation = .unbind
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(!model.acceptedUnbind || model.isUnbinding || model.unbindCode.count != 6)
            }
        }
    }

    private func deleteCard(_ summary: AccountLifecycleSummary) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("注销账号")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.red)
                Text("注销立即生效且不可撤销。已发布的帖子、评论、点评和反馈保留并显示“已注销用户”；所有设备旧登录失效。登录邮箱与学校邮箱冷却 1 小时后可重新注册/绑定，新账号不继承旧数据。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                Text(model.deleteAvailabilityText)
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)

                Button("发送注销验证码") {
                    Task { await model.sendDeleteCode() }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(model.deleteSendDisabled || model.isSendingDelete)

                labeledField("注销验证码")
                TextField("6 位数字", text: $model.deleteCode)
                    .keyboardType(.numberPad)
                    .modifier(FormInputStyle())
                    .onChange(of: model.deleteCode) { _, value in
                        let filtered = String(value.filter(\.isNumber).prefix(6))
                        if filtered != value { model.deleteCode = filtered }
                    }

                Toggle("我已知晓注销不可撤销、新账号不继承旧数据及邮箱 1 小时冷却规则", isOn: $model.acceptedDeletion)
                    .tint(Zine.red)
                    .font(.footnote)

                Button("注销账号") {
                    confirmation = .delete
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(!model.acceptedDeletion || model.isDeleting || model.deleteCode.count != 6)
            }
        }
    }

    private func message(_ text: String, color: Color) -> some View {
        PaperCard {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(color)
        }
    }

    private func labeledField(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Zine.muted)
    }
}
