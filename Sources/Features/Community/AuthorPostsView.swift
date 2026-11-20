import SwiftUI

@MainActor
struct AuthorPostsView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var model: AuthorPostsViewModel

    init(authorID: String, service: CommunityService) {
        _model = StateObject(
            wrappedValue: AuthorPostsViewModel(authorID: authorID, service: service)
        )
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if let error = model.errorMessage, !error.isEmpty, model.posts.isEmpty {
                        ErrorStateView(message: error) { Task { await model.load() } }
                    } else if model.isLoading && model.posts.isEmpty {
                        LoadingStateView(message: "正在翻这位同学的食记…")
                    } else if model.posts.isEmpty {
                        EmptyStateView(title: "还没有公开食记", message: "等等再来看看。")
                    } else {
                        ForEach(model.posts) { post in
                            NavigationLink {
                                CommunityDetailView(postID: post.id, service: session.community)
                            } label: {
                                card(post)
                            }
                            .buttonStyle(.plain)
                        }
                        if model.hasMore {
                            Button("加载更多") { Task { await model.loadMore() } }
                                .buttonStyle(InkButtonStyle())
                                .disabled(model.isLoadingMore)
                        }
                    }
                    if let error = model.errorMessage, !error.isEmpty, !model.posts.isEmpty {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Zine.red)
                    }
                }
                .padding(Zine.pagePadding)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle("作者食记")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model.posts.isEmpty { await model.load() }
        }
    }

    private var header: some View {
        PaperCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Zine.alt)
                    Text(String((model.author?.displayName ?? "饭").prefix(1)))
                        .font(.system(size: 24, weight: .black, design: .serif))
                        .foregroundStyle(Zine.red)
                }
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.author?.displayName ?? "同学")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Text("共 \(model.total) 条公开食记")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func card(_ post: CommunityPost) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                if !post.title.isEmpty {
                    Text(post.title)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                }
                Text(post.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                    .lineLimit(4)
                Text(DisplayFormat.dateTime(post.createdAt))
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
