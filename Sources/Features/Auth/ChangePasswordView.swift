import SwiftUI

@MainActor
struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ChangePasswordViewModel

    init(session: AppSession) {
        _model = StateObject(wrappedValue: ChangePasswordViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 16) {
                        SectionHeading(
                            index: "03.1",
                            title: "修改密码",
                            subtitle: "修改成功后当前会话与其它设备都需要重新登录。"
                        )
                        card
                    }
                    .padding(Zine.pagePadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("修改密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var card: some View {
        PaperCard {
            if model.didSucceed {
                VStack(alignment: .leading, spacing: 10) {
                    Text("密码已修改")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Text("当前会话已失效，请使用新密码重新登录。")
                        .font(.subheadline)
                        .foregroundStyle(Zine.muted)
                    Button("返回登录") { dismiss() }
                        .buttonStyle(InkButtonStyle(primary: true))
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    labeledField("旧密码")
                    SecureField("当前密码", text: $model.oldPassword)
                        .textContentType(.password)
                        .modifier(FormInputStyle())

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
                        Task { await model.submit() }
                    } label: {
                        if model.isSubmitting {
                            ProgressView().tint(Zine.onRed)
                        } else {
                            Text("确认修改")
                        }
                    }
                    .buttonStyle(InkButtonStyle(primary: true))
                    .disabled(model.isSubmitting)
                }
            }
        }
    }

    private func labeledField(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Zine.muted)
    }
}
