import SwiftUI

@MainActor
struct CommunityFeedView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var model: CommunityFeedViewModel
    @State private var showCompose = false

    init(service: CommunityService) {
        _model = StateObject(wrappedValue: CommunityFeedViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    SectionHeading(
                        index: "05",
                        title: "社区食记",
                        subtitle: "看看大家今天吃了什么。"
                    )
                    Picker("范围", selection: $model.segment) {
                        ForEach(CommunityFeedViewModel.Segment.allCases) { segment in
                            Text(segment.title).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: model.segment) { _, value in
                        Task { await model.switchSegment(value) }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Zine.muted)
                        TextField("搜索食记", text: $model.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await model.load(reset: true) } }
                            .onChange(of: model.query) { _, _ in
                                model.queryChanged()
                            }
                    }
                    .modifier(FormInputStyle())

                    content
                }
                .padding(Zine.pagePadding)
            }
            .refreshable { await model.load(reset: true) }
        }
        .navigationTitle("社区")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("写食记") { showCompose = true }
            }
        }
        .sheet(isPresented: $showCompose) {
            CommunityComposeView(
                community: session.community,
                submissions: session.submissions
            ) {
                Task { await model.load(reset: true) }
            }
        }
        .task {
            if model.posts.isEmpty {
                await model.load(reset: true)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.posts.isEmpty {
            LoadingStateView(message: "正在翻大家的食记…")
        } else if let error = model.errorMessage, model.posts.isEmpty {
            ErrorStateView(message: error) {
                Task { await model.load(reset: true) }
            }
        } else if model.posts.isEmpty {
            EmptyStateView(
                title: model.segment == .following ? "关注的人还没有食记" : "还没有公开食记",
                message: nil
            )
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 12) {
                ForEach(model.posts) { post in
                    NavigationLink {
                        CommunityDetailView(postID: post.id, service: session.community)
                    } label: {
                        postCard(post)
                    }
                    .buttonStyle(.plain)
                }
            }
            if model.hasMore {
                Button("加载更多") {
                    Task { await model.loadMore() }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(model.isLoadingMore)
            }
        }
    }

    private func postCard(_ post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let raw = post.images.first?.url,
               let url = MediaURL.resolve(raw, baseURL: session.catalog.mediaBaseURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Zine.alt
                    }
                }
                .frame(height: 150)
                .clipped()
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(post.title)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                    .lineLimit(2)
                Text(post.content)
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                    .lineLimit(3)
                HStack(spacing: 10) {
                    Button {
                        Task { await model.toggleLike(post) }
                    } label: {
                        Label("\(model.likeCount(post))", systemImage: model.isLiked(post) ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundStyle(model.isLiked(post) ? Zine.red : Zine.muted)
                    }
                    .buttonStyle(.plain)
                    Label("\(post.commentCount)", systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                Text(post.userDisplayName)
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Zine.paper)
        }
        .clipShape(RoundedRectangle(cornerRadius: Zine.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Zine.cardRadius)
                .stroke(Zine.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
