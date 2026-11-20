import SwiftUI

@MainActor
struct AdminHomeView: View {
    @StateObject private var model: AdminHomeViewModel
    private let service: AdminService
    private let submissions: SubmissionService?
    private let mediaBaseURL: URL?
    private let canManageCatalogImages: Bool

    init(
        service: AdminService,
        submissions: SubmissionService? = nil,
        mediaBaseURL: URL? = nil,
        canManageCatalogImages: Bool = false
    ) {
        self.service = service
        self.submissions = submissions
        self.mediaBaseURL = mediaBaseURL
        self.canManageCatalogImages = canManageCatalogImages
        _model = StateObject(wrappedValue: AdminHomeViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    SectionHeading(
                        index: "08",
                        title: "管理",
                        subtitle: "数据看板与用户角色/状态；所有写请求由服务器重新校验。"
                    )
                    dashboardCard
                    moderationLinks
                    userSearch
                    userList
                }
                .padding(Zine.pagePadding)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle("管理")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model.dashboard == nil {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private var dashboardCard: some View {
        if let dashboard = model.dashboard {
            PaperCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("数据看板")
                            .font(.system(size: 19, weight: .bold, design: .serif))
                            .foregroundStyle(Zine.ink)
                        Spacer()
                        Picker("周期", selection: Binding(
                            get: { model.days },
                            set: { value in Task { await model.setDays(value) } }
                        )) {
                            Text("7 天").tag(7)
                            Text("30 天").tag(30)
                            Text("31 天").tag(31)
                        }
                        .pickerStyle(.menu)
                        .tint(Zine.ink)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        metric("用户", "\(dashboard.totalUsers)")
                        metric("活跃", "\(dashboard.registeredUsers)")
                        metric("在线", "\(dashboard.onlineUsers)")
                        metric("点评", "\(dashboard.reviews)")
                        metric("帖子", "\(dashboard.posts)")
                        metric("菜品", "\(dashboard.dishes)")
                        metric("档口", "\(dashboard.stalls)")
                        metric("食堂", "\(dashboard.halls)")
                    }
                    if !dashboard.trend.isEmpty {
                        Text("最近趋势（最后一天）：新增用户 \(dashboard.trend.last?.newUsers ?? 0)，新增点评 \(dashboard.trend.last?.newReviews ?? 0)，新增帖子 \(dashboard.trend.last?.newPosts ?? 0)")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    }
                    if let generatedAt = dashboard.generatedAt {
                        Text("快照时间：\(DisplayFormat.dateTime(generatedAt))")
                            .font(.caption2)
                            .foregroundStyle(Zine.muted)
                    }
                }
            }
        } else if model.isLoadingDashboard {
            LoadingStateView(message: "正在读取看板…")
        }
    }

    private var moderationLinks: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("内容审核")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                NavigationLink {
                    ModerationQueueView(service: service)
                } label: {
                    adminLinkRow("审核队列", detail: "待审提交、AI 风险与通过/驳回")
                }
                NavigationLink {
                    CommunityModerationView(service: service)
                } label: {
                    adminLinkRow("社区审核", detail: "食记/评论队列、详情与删除")
                }
                NavigationLink {
                    AdminCatalogView(
                        service: service,
                        uploader: submissions,
                        mediaBaseURL: mediaBaseURL,
                        canManageImages: canManageCatalogImages
                    )
                } label: {
                    adminLinkRow("目录管理", detail: "食堂/档口/菜品增删改与启停")
                }
                NavigationLink {
                    AdminReviewsView(service: service)
                } label: {
                    adminLinkRow("正式点评", detail: "搜索、作者邮箱与违规移除")
                }
                NavigationLink {
                    AdminCorrectionsView(service: service)
                } label: {
                    adminLinkRow("纠错审核", detail: "目录纠错提案通过与拒绝")
                }
                NavigationLink {
                    AdminNoticesView(service: service)
                } label: {
                    adminLinkRow("公告管理", detail: "Markdown 编辑、排期与登录弹窗")
                }
                NavigationLink {
                    AdminFeedbackView(service: service)
                } label: {
                    adminLinkRow("反馈管理", detail: "处理建议、状态与 CSV 导入导出")
                }
                NavigationLink {
                    AdminReportsView(service: service)
                } label: {
                    adminLinkRow("举报处理", detail: "待处理举报、决定、追问与动作")
                }
                NavigationLink {
                    AdminAppealsView(service: service)
                } label: {
                    adminLinkRow("申诉复核", detail: "开始复核与结束复核")
                }
                NavigationLink {
                    ModerationLogsView(service: service)
                } label: {
                    adminLinkRow("审核日志", detail: "AI 与人工审核记录")
                }
            }
        }
    }

    private func adminLinkRow(_ title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Zine.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Zine.muted)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .serif))
                .foregroundStyle(Zine.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Zine.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.alt))
    }

    private var userSearch: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Zine.muted)
            TextField("搜索邮箱或昵称", text: $model.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { Task { await model.loadUsers(page: 1) } }
                .onChange(of: model.query) { _, _ in
                    model.queryChanged()
                }
        }
        .modifier(FormInputStyle())
    }

    @ViewBuilder
    private var userList: some View {
        if let info = model.infoMessage, !info.isEmpty {
            Text(info)
                .font(.footnote)
                .foregroundStyle(Zine.green)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if let error = model.errorMessage, !error.isEmpty {
            Text(error)
                .font(.subheadline)
                .foregroundStyle(Zine.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if model.isLoadingUsers && model.users.isEmpty {
            LoadingStateView(message: "正在读取用户…")
        } else if model.users.isEmpty {
            EmptyStateView(title: "没有匹配用户", message: nil)
        } else {
            ForEach(model.users) { user in
                PaperCard {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(user.displayName)
                                .font(.system(size: 17, weight: .bold, design: .serif))
                                .foregroundStyle(Zine.ink)
                            Text(user.role)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Zine.alt))
                                .foregroundStyle(Zine.ink)
                            Text(user.status)
                                .font(.caption2)
                                .foregroundStyle(user.status == "active" ? Zine.green : Zine.red)
                            Spacer()
                            if model.updatingUserID == user.id {
                                ProgressView().tint(Zine.red)
                            }
                        }
                        Text("\(user.email) · \(user.reviewCount) 条点评")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                        HStack(spacing: 14) {
                            Menu("角色") {
                                ForEach(["user", "admin", "superadmin"], id: \.self) { role in
                                    Button(role) {
                                        Task { await model.updateUser(user, role: role, status: user.status) }
                                    }
                                }
                            }
                            .font(.caption)
                            Menu(user.status == "active" ? "停用" : "恢复") {
                                Button(user.status == "active" ? "停用账号" : "恢复账号") {
                                    Task {
                                        await model.updateUser(
                                            user,
                                            role: user.role,
                                            status: user.status == "active" ? "disabled" : "active"
                                        )
                                    }
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            if model.totalPages > 1 {
                HStack {
                    Button("上一页") {
                        Task { await model.loadUsers(page: model.page - 1) }
                    }
                    .buttonStyle(InkButtonStyle())
                    .disabled(model.page <= 1 || model.isLoadingUsers)
                    Text("第 \(model.page)/\(model.totalPages) 页")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                    Button("下一页") {
                        Task { await model.loadUsers(page: model.page + 1) }
                    }
                    .buttonStyle(InkButtonStyle())
                    .disabled(model.page >= model.totalPages || model.isLoadingUsers)
                }
            }
        }
    }
}
