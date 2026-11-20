import SwiftUI

@MainActor
struct MyCommunityPostsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: MyCommunityPostsViewModel

    init(service: CommunityService) {
        _model = StateObject(wrappedValue: MyCommunityPostsViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "05.3",
                            title: "我的食记",
                            subtitle: "发布记录与审核进度都在这里。"
                        )
                        HStack {
                            Text(model.statusText)
                                .font(.caption)
                                .foregroundStyle(Zine.muted)
                            Spacer()
                            Button("刷新") { Task { await model.load() } }
                                .buttonStyle(LinkButtonStyle())
                                .disabled(model.isLoading)
                        }
                        if let error = model.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        content
                        if model.hasMore {
                            Button("加载更多") { Task { await model.loadMore() } }
                                .buttonStyle(InkButtonStyle())
                                .disabled(model.isLoading)
                        }
                    }
                    .padding(Zine.pagePadding)
                }
                .refreshable { await model.load() }
            }
            .navigationTitle("我的食记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                if model.posts.isEmpty { await model.load() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.posts.isEmpty {
            LoadingStateView(message: "正在读取我的食记…")
        } else if let error = model.errorMessage, model.posts.isEmpty {
            ErrorStateView(message: error) { Task { await model.load() } }
        } else if model.posts.isEmpty {
            EmptyStateView(
                title: "还没有发布食记",
                message: "发布记录和审核进度会出现在这里。"
            )
        } else {
            ForEach(model.posts) { post in
                card(post)
            }
        }
    }

    private func card(_ post: CommunityPost) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(post.title.isEmpty ? "无标题食记" : post.title)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(statusLabel(post.status))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor(post.status))
                }
                Text(DisplayFormat.dateTime(post.createdAt))
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                Text(post.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                    .lineLimit(4)
                if let reason = post.reviewReason, !reason.isEmpty {
                    Text("审核说明：\(reason)")
                        .font(.caption)
                        .foregroundStyle(Zine.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "approved": return "已通过"
        case "rejected": return "已驳回"
        default: return "待审核"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "approved": return Zine.green
        case "rejected": return Zine.red
        default: return Zine.gold
        }
    }
}
