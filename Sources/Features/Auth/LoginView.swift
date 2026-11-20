import SwiftUI
import UIKit

@MainActor
struct LoginView: View {
    @ObservedObject var session: AppSession
    private enum AuthSheet: String, Identifiable {
        case registration
        case passwordRecovery

        var id: String { rawValue }
    }

    @StateObject private var model: LoginViewModel
    @State private var activeSheet: AuthSheet?

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
                            .font(.system(.largeTitle, design: .serif).weight(.black))
                            .foregroundStyle(Zine.ink)
                        Text("今天也要好好吃饭。")
                            .font(Zine.noteFont)
                            .foregroundStyle(Zine.muted)
                    }
                    .padding(.top, 24)

                    PaperCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("登录")
                                .font(Zine.sectionFont)
                                .foregroundStyle(Zine.ink)
                                .accessibilityAddTraits(.isHeader)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("邮箱")
                                    .font(.footnote)
                                    .foregroundStyle(Zine.muted)
                                TextField("QQ / 163 / Gmail / 学校邮箱", text: $model.email)
                                    .accessibilityLabel("邮箱")
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
                                    .accessibilityLabel("密码")
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
                                        .accessibilityLabel("正在登录")
                                } else {
                                    Text("登录")
                                }
                            }
                            .buttonStyle(InkButtonStyle(primary: true))
                            .disabled(model.isSubmitting)
                        }
                    }

                    HStack {
                        Button("注册账号") { activeSheet = .registration }
                        Spacer()
                        Button("忘记密码？") { activeSheet = .passwordRecovery }
                    }
                    .buttonStyle(LinkButtonStyle())

                    Text("遇见好吃的，就记一笔。")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, Zine.pagePadding)
                .readableWidth(560)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .registration:
                RegistrationView(session: session) { email in
                    model.email = email
                }
            case .passwordRecovery:
                PasswordRecoveryView(session: session) { email in
                    model.email = email
                }
            }
        }
        .alert("账号已注销", isPresented: Binding(
            get: { session.accountDeletionNotice != nil },
            set: { if !$0 { session.clearAccountDeletionNotice() } }
        )) {
            Button("知道了", role: .cancel) {
                session.clearAccountDeletionNotice()
            }
        } message: {
            Text(session.accountDeletionNotice ?? "")
        }
    }
}
