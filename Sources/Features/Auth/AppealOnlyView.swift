import SwiftUI

@MainActor
struct AppealOnlyView: View {
    let user: User
    @ObservedObject var session: AppSession
    @State private var confirmLogout = false

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeading(
                        index: "!",
                        title: "受限申诉会话",
                        subtitle: "该账号当前只能查看本人处理决定并提交申诉。"
                    )
                    PaperCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(user.displayName)
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundStyle(Zine.ink)
                            Text(user.email)
                                .font(.footnote)
                                .foregroundStyle(Zine.muted)
                            Text("会话自登录成功起 45 分钟绝对到期；普通食堂、社区、私信和管理功能均不可用。申诉入口将在后续波次接入，本页只确认受限状态，避免把普通导航错误地当成可用。")
                                .font(.subheadline)
                                .foregroundStyle(Zine.muted)
                        }
                    }
                    Button("退出登录") { confirmLogout = true }
                        .buttonStyle(InkButtonStyle())
                }
                .padding(Zine.pagePadding)
            }
        }
        .alert("退出登录？", isPresented: $confirmLogout) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                Task { await session.logout() }
            }
        }
    }
}
