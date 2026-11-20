import SwiftUI
import UIKit

@MainActor
struct LoginView: View {
    @ObservedObject var session: AppSession
    @StateObject private var model: LoginViewModel
    @State private var showRoadmapAlert = false

    init(session: AppSession) {
        self.session = session
        _model = StateObject(wrappedValue: LoginViewModel(session: session))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("北交干饭吧")
                            .font(.system(size: 36, weight: .black, design: .serif))
                            .foregroundStyle(Zine.ink)
                        Text("今天也要好好吃饭。")
                            .font(Zine.noteFont)
                            .foregroundStyle(Zine.muted)
                    }
                    .padding(.top, 24)

                    PaperCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("登录")
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundStyle(Zine.ink)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("邮箱")
                                    .font(.footnote)
                                    .foregroundStyle(Zine.muted)
                                TextField("QQ / 163 / Gmail / 学校邮箱", text: $model.email)
                                    .textContentType(.username)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                                            .stroke(Zine.border, lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("密码")
                                    .font(.footnote)
                                    .foregroundStyle(Zine.muted)
                                SecureField("请输入密码", text: $model.password)
                                    .textContentType(.password)
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                                            .stroke(Zine.border, lineWidth: 1)
                                    )
                            }

                            if let image = model.captchaImage {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("登录验证码")
                                        .font(.footnote)
                                        .foregroundStyle(Zine.muted)
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 220, maxHeight: 96)
                                        .accessibilityLabel("登录验证码图片")
                                    TextField("验证码答案", text: $model.captchaAnswer)
                                        .keyboardType(.numberPad)
                                        .padding(12)
                                        .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Zine.smallRadius)
                                                .stroke(Zine.border, lineWidth: 1)
                                        )
                                    Text(model.captchaHint)
                                        .font(.footnote)
                                        .foregroundStyle(Zine.muted)
                                    Button("换一题") {
                                        Task { await model.loadCaptcha() }
                                    }
                                    .buttonStyle(LinkButtonStyle())
                                }
                            }

                            if let error = model.errorMessage, !error.isEmpty {
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundStyle(Zine.red)
                                    .accessibilityLabel("登录错误：\(error)")
                            }

                            Button {
                                Task { await model.submit() }
                            } label: {
                                if model.isSubmitting {
                                    ProgressView().tint(Zine.onRed)
                                } else {
                                    Text("登录")
                                }
                            }
                            .buttonStyle(InkButtonStyle(primary: true))
                            .disabled(model.isSubmitting)
                        }
                    }

                    HStack {
                        Button("注册账号") { showRoadmapAlert = true }
                        Spacer()
                        Button("忘记密码？") { showRoadmapAlert = true }
                    }
                    .buttonStyle(LinkButtonStyle())

                    Text("当前为开发底座：已接入登录与食堂只读浏览。注册、找回密码、社区与管理功能按审计报告的波次继续接入，不把占位入口当作已完成。")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, Zine.pagePadding)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert("功能接入中", isPresented: $showRoadmapAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("注册与找回密码将在下一阶段接入；当前请使用已有账号登录。")
        }
    }
}
