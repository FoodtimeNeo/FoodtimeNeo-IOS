import SwiftUI

@MainActor
struct SocialView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: SocialViewModel
    @State private var blockTarget: SocialUser?

    init(session: AppSession, currentUserID: String) {
        _model = StateObject(
            wrappedValue: SocialViewModel(session: session, currentUserID: currentUserID)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                VStack(spacing: 12) {
                    Picker("范围", selection: $model.segment) {
                        ForEach(SocialViewModel.Segment.allCases) { segment in
                            Text(segment.title).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Zine.pagePadding)
                    .onChange(of: model.segment) { _, _ in
                        Task { await model.reload() }
                    }

                    if model.segment == .search {
                        TextField("搜索用户名", text: $model.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .modifier(FormInputStyle())
                            .padding(.horizontal, Zine.pagePadding)
                            .onSubmit {
                                Task { await model.reload() }
                            }
                            .onChange(of: model.query) { _, _ in
                                model.searchQueryChanged()
                            }
                    }

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            content
                        }
                        .padding(.horizontal, Zine.pagePadding)
                        .padding(.bottom, 24)
                    }
                    .refreshable { await model.reload() }

                    if let info = model.infoMessage, !info.isEmpty {
                        Text(info)
                            .font(.footnote)
                            .foregroundStyle(Zine.green)
                            .padding(.horizontal, Zine.pagePadding)
                    }
                    if let error = model.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Zine.red)
                            .padding(.horizontal, Zine.pagePadding)
                    }
                }
            }
            .navigationTitle("关注与黑名单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await model.reload()
            }
            .alert("拉黑该用户？", isPresented: Binding(
                get: { blockTarget != nil },
                set: { if !$0 { blockTarget = nil } }
            )) {
                Button("取消", role: .cancel) { blockTarget = nil }
                Button("拉黑", role: .destructive) {
                    if let target = blockTarget {
                        Task { await model.block(target) }
                    }
                    blockTarget = nil
                }
            } message: {
                Text("拉黑主要影响私信；不会删除对方已有的公开内容。可随时在黑名单中解除。")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.users.isEmpty && model.blockedUsers.isEmpty {
            LoadingStateView(message: "正在读取…")
        } else if model.segment == .blocks {
            if model.blockedUsers.isEmpty {
                EmptyStateView(title: "黑名单为空", message: "拉黑后可以在这里解除。")
            } else {
                ForEach(model.blockedUsers) { user in
                    blockedRow(user)
                        .task { await model.loadMoreBlockedIfNeeded(currentUser: user) }
                }
            }
        } else if model.segment == .search && !model.isSearching {
            EmptyStateView(title: "搜索用户", message: "输入昵称查看其他活跃用户。")
        } else if model.users.isEmpty {
            EmptyStateView(
                title: model.segment == .following ? "还没有关注" : model.segment == .followers ? "还没有粉丝" : "没有匹配用户",
                message: nil
            )
        } else {
            ForEach(model.users) { user in
                userRow(user)
                    .task { await model.loadMoreIfNeeded(currentUser: user) }
            }
        }
    }

    private func userRow(_ user: SocialUser) -> some View {
        PaperCard {
            HStack(spacing: 12) {
                avatar(user.displayName)
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayName)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    if model.blockedIDs.contains(user.id) {
                        Text("已拉黑")
                            .font(.caption)
                            .foregroundStyle(Zine.red)
                    }
                }
                Spacer(minLength: 8)
                Button(user.followedByMe ? "已关注" : "关注") {
                    Task { await model.toggleFollow(user) }
                }
                .buttonStyle(InkButtonStyle(primary: !user.followedByMe))
                .frame(width: 92)
                .disabled(model.blockedIDs.contains(user.id))

                if !model.blockedIDs.contains(user.id) {
                    Button("拉黑") { blockTarget = user }
                        .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }

    private func blockedRow(_ user: BlockedUser) -> some View {
        PaperCard {
            HStack(spacing: 12) {
                avatar(user.displayName)
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayName)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    if let date = user.blockedAt {
                        Text("拉黑于 \(DisplayFormat.dateTime(date))")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    }
                }
                Spacer(minLength: 8)
                Button("解除拉黑") {
                    Task { await model.unblock(user) }
                }
                .buttonStyle(InkButtonStyle())
                .frame(width: 102)
            }
        }
    }

    private func avatar(_ name: String) -> some View {
        ZStack {
            Circle().fill(Zine.alt)
            Text(String(name.prefix(1)))
                .font(.system(size: 20, weight: .black, design: .serif))
                .foregroundStyle(Zine.red)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}
