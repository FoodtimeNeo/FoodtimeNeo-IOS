import SwiftUI

@MainActor
struct ProfileView: View {
    private enum ProfileSheet: String, Identifiable {
        case editProfile
        case changePassword
        case accountSecurity
        case social
        case feedback
        case myReviews

        var id: String { rawValue }
    }

    let user: User
    @ObservedObject var session: AppSession
    @State private var confirmLogout = false
    @State private var activeSheet: ProfileSheet?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 16) {
                        SectionHeading(
                            index: "03",
                            title: "我的",
                            subtitle: "认真吃饭，就是今日份的小确幸。"
                        )
                        profileCard
                        capabilityCard
                        roadmapCard
                        Button("编辑资料") { activeSheet = .editProfile }
                            .buttonStyle(InkButtonStyle())
                        Button("关注与黑名单") { activeSheet = .social }
                            .buttonStyle(InkButtonStyle())
                        Button("我的点评") { activeSheet = .myReviews }
                            .buttonStyle(InkButtonStyle())
                        Button("建议与反馈") { activeSheet = .feedback }
                            .buttonStyle(InkButtonStyle())
                        Button("修改密码") { activeSheet = .changePassword }
                            .buttonStyle(InkButtonStyle())
                        if !user.isAdmin {
                            Button("账号安全与注销") { activeSheet = .accountSecurity }
                                .buttonStyle(InkButtonStyle())
                        }
                        Button("退出登录") { confirmLogout = true }
                            .buttonStyle(InkButtonStyle())
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .editProfile:
                ProfileEditView(session: session)
            case .changePassword:
                ChangePasswordView(session: session)
            case .accountSecurity:
                AccountSecurityView(session: session)
            case .social:
                SocialView(session: session, currentUserID: user.id)
            case .feedback:
                FeedbackView(session: session)
            case .myReviews:
                MyReviewsView(session: session)
            }
        }
        .alert("退出登录？", isPresented: $confirmLogout) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                Task { await session.logout() }
            }
        } message: {
            Text("本机会保留安装设备标识；再次登录后可继续使用。")
        }
    }

    private var profileCard: some View {
        PaperCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Zine.alt)
                    Text(String(user.displayName.prefix(1)))

                        .font(.system(size: 28, weight: .black, design: .serif))
                        .foregroundStyle(Zine.red)
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Text(user.email)
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                    Text(roleLabel)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Zine.alt))
                        .foregroundStyle(Zine.ink)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var capabilityCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("当前有效能力")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                if session.capabilities.capabilities.isEmpty {
                    Text("该账号没有管理能力。能力以服务器返回为准，不在客户端按角色推断。")
                        .font(.subheadline)
                        .foregroundStyle(Zine.muted)
                } else {
                    Text(session.capabilities.capabilities.joined(separator: " · "))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Zine.ink)
                    if !session.capabilities.revision.isEmpty {
                        Text("策略版本：\(session.capabilities.revision)")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    }
                }
            }
        }
    }

    private var roadmapCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("开发状态")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("当前已接入登录、注册、找回/修改密码、资料昵称编辑、关注/粉丝/用户搜索/黑名单、菜品点评/点赞/我的点评、建议与反馈、学校邮箱绑定/解绑、账号注销入口、会话恢复、能力读取和食堂目录/搜菜/详情/价格/地图。头像、点评回复、社区、通知与管理端按审计报告的波次继续接入；占位页和未接入入口不会当作已完成。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    private var roleLabel: String {
        switch user.role {
        case "superadmin": return "超级管理员"
        case "admin": return "管理员"
        case "visitor": return "访客"
        default: return "普通用户"
        }
    }
}
