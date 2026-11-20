import SwiftUI

@MainActor
struct ReviewThreadView: View {
    @Environment(\.dismiss) private var dismiss
    let review: Review
    @StateObject private var model: ReviewThreadViewModel

    init(review: Review, service: ReviewService) {
        self.review = review
        _model = StateObject(
            wrappedValue: ReviewThreadViewModel(reviewID: review.id, service: service)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        originalReview
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

    private var originalReview: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(review.userDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Zine.ink)
                    Text(String(repeating: "★", count: review.rating)
                         + String(repeating: "☆", count: max(0, 5 - review.rating)))
                        .font(.caption)
                        .foregroundStyle(Zine.gold)
                    Spacer()
                    Text(DisplayFormat.dateTime(review.createdAt))
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                Text(review.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
            }
        }
    }

    @ViewBuilder
    private var repliesContent: some View {
        if model.isLoading && model.replies.isEmpty {
            LoadingStateView(message: "正在读取回复…")
        } else if model.replies.isEmpty {
            EmptyStateView(title: "还没有回复", message: "在下方写下第一条回复。")
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

    private func replyRow(_ reply: ReviewReply) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(reply.userDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Zine.ink)
                    if reply.replyToDeleted {
                        Text("回复已删除用户")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    } else if let target = reply.replyToUserDisplayName, !target.isEmpty {
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
                    Button("回复") {
                        model.setReplyTarget(reply)
                    }
                    .font(.caption)
                    .foregroundStyle(Zine.blue)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let name = model.replyToName {
                HStack {
                    Text("回复 @\(name)")
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
                    } else {
                        Text("发送")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .frame(width: 82)
                .disabled(model.isSubmitting)
            }
        }
        .padding(.horizontal, Zine.pagePadding)
        .padding(.vertical, 8)
        .background(Zine.bar)
    }
}

@MainActor
struct MyRepliesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: MyRepliesViewModel
    @State private var pendingDelete: ReviewReply?

    init(session: AppSession) {
        _model = StateObject(wrappedValue: MyRepliesViewModel(service: session.reviews))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
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
                        if model.isLoading && model.replies.isEmpty {
                            LoadingStateView(message: "正在读取回复…")
                        } else if model.replies.isEmpty {
                            EmptyStateView(title: "还没有回复", message: nil)
                        } else {
                            ForEach(model.replies) { reply in
                                PaperCard {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text(reply.dishName)
                                                .font(.system(size: 17, weight: .bold, design: .serif))
                                                .foregroundStyle(Zine.ink)
                                            Spacer()
                                            Text(reply.statusLabel)
                                                .font(.caption)
                                                .foregroundStyle(reply.status == "approved" ? Zine.green : reply.status == "rejected" ? Zine.red : Zine.muted)
                                        }
                                        Text(reply.content)
                                            .font(.subheadline)
                                            .foregroundStyle(Zine.ink)
                                        if let reason = reply.reviewReason, !reason.isEmpty {
                                            Text("审核说明：\(reason)")
                                                .font(.footnote)
                                                .foregroundStyle(Zine.red)
                                        }
                                        HStack {
                                            Text(DisplayFormat.dateTime(reply.createdAt))
                                                .font(.caption)
                                                .foregroundStyle(Zine.muted)
                                            Spacer()
                                            Button("删除") { pendingDelete = reply }
                                                .buttonStyle(LinkButtonStyle())
                                        }
                                    }
                                }
                            }
                            if model.totalPages > 1 {
                                HStack {
                                    Button("上一页") {
                                        Task { await model.load(page: model.page - 1) }
                                    }
                                    .buttonStyle(InkButtonStyle())
                                    .disabled(model.page <= 1 || model.isLoading)
                                    Text("第 \(model.page)/\(model.totalPages) 页")
                                        .font(.footnote)
                                        .foregroundStyle(Zine.muted)
                                    Button("下一页") {
                                        Task { await model.load(page: model.page + 1) }
                                    }
                                    .buttonStyle(InkButtonStyle())
                                    .disabled(model.page >= model.totalPages || model.isLoading)
                                }
                            }
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("我的回复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.load(page: 1) }
            .alert(item: $pendingDelete) { reply in
                Alert(
                    title: Text("删除这条回复？"),
                    message: Text("删除后回复不再公开，审核历史与后续回复保留。"),
                    primaryButton: .destructive(Text("删除")) {
                        Task { await model.delete(reply) }
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }
}
