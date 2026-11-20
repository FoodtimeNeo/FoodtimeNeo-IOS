import SwiftUI

@MainActor
struct AdminHomeView: View {
    @StateObject private var model: AdminHomeViewModel

    init(service: AdminService) {
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
