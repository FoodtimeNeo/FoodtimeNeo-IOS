import SwiftUI

@MainActor
struct CommunityThreadView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: CommunityThreadViewModel

    init(root: CommunityComment, postID: String, service: CommunityService) {
        _model = StateObject(
            wrappedValue: CommunityThreadViewModel(
                root: root,
                postID: postID,
                service: service
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 12) {
                        rootCard
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
                        repliesContent
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("回复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                composer
            }
            .task { await model.load() }
        }
    }

    private var rootCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(model.root.userDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(DisplayFormat.dateTime(model.root.createdAt))
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                Text(model.root.deleted ? "原评论已删除" : model.root.content)
                    .font(.subheadline)
                    .foregroundStyle(model.root.deleted ? Zine.muted : Zine.ink)
            }
        }
    }

    @ViewBuilder
    private var repliesContent: some View {
        if model.isLoading && model.replies.isEmpty {
            LoadingStateView(message: "正在读取回复…")
        } else if model.replies.isEmpty {
            EmptyStateView(title: "还没有楼内回复", message: "在下方回复这条评论。")
        } else {
            ForEach(model.replies) { reply in
                replyRow(reply)
            }
            if model.hasMore {
                Button("加载更多回复") {
                    Task { await model.loadMore() }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(model.isLoadingMore)
            }
        }
    }

    private func replyRow(_ reply: CommunityComment) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(reply.userDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Zine.ink)
                    if reply.deleted {
                        Text("已删除")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    } else if let target = reply.replyToDisplayName, !target.isEmpty {
                        Text("回复 @\(target)")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    }
                    Spacer()
                    Text(DisplayFormat.dateTime(reply.createdAt))
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                Text(reply.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                HStack(spacing: 14) {
                    Button {
                        model.toggleLike(reply)
                    } label: {
                        Label(
                            "\(model.likeCount(reply))",
                            systemImage: model.isLiked(reply) ? "heart.fill" : "heart"
                        )
                        .font(.caption)
                        .foregroundStyle(model.isLiked(reply) ? Zine.red : Zine.muted)
                    }
                    .buttonStyle(.plain)
                    if !reply.deleted {
                        Button("回复") { model.setReplyTarget(reply) }
                            .font(.caption)
                            .foregroundStyle(Zine.blue)
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let target = model.replyTarget {
                HStack {
                    Text("回复 @\(target.userDisplayName)")
                        .font(.caption)
                        .foregroundStyle(Zine.blue)
                    Button("取消") { model.clearReplyTarget() }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(Zine.muted)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $model.content)
                    .frame(minHeight: 44, maxHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                    .overlay(
                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                            .stroke(Zine.border, lineWidth: 1)
                    )
                    .onChange(of: model.content) { _, value in
                        if value.count > 500 {
                            model.content = String(value.prefix(500))
                        }
                    }
                Button {
                    Task { await model.submit() }
                } label: {
                    if model.isSubmitting {
                        ProgressView().tint(Zine.onRed)
                            .accessibilityLabel("正在发送")
                    } else {
                        Text("发送")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .fixedSize(horizontal: true, vertical: false)
                .disabled(model.isSubmitting)
            }
        }
        .padding(.horizontal, Zine.pagePadding)
        .padding(.vertical, 8)
        .background(Zine.bar)
    }
}
