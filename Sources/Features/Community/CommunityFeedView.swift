import SwiftUI

@MainActor
struct CommunityFeedView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var model: CommunityFeedViewModel
    @State private var showCompose = false
    @State private var showPins = false

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
                .readableWidth()
            }
            .refreshable { await model.load(reset: true) }
        }
        .navigationTitle("社区")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.canManagePins {
                    Button("置顶") { showPins = true }
                }
                Button("写食记") { showCompose = true }
            }
        }
        .sheet(isPresented: $showPins) {
            CommunityPinsView(service: session.community) {
                Task { await model.reloadPinsAfterManagement() }
            }
        }
        .sheet(isPresented: $showCompose) {
            CommunityComposeView(
                community: session.community,
                submissions: session.submissions,
                drafts: session.drafts,
                accountID: session.user?.id ?? ""
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
            pinnedSection
            EmptyStateView(
                title: model.segment == .following ? "关注的人还没有食记" : "还没有公开食记",
                message: nil
            )
        } else {
            pinnedSection
            LazyVGrid(columns: feedColumns, spacing: 12) {
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

    @ViewBuilder
    private var pinnedSection: some View {
        if let pins = model.pins, !pins.items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("置顶")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                ForEach(pins.items) { entry in
                    NavigationLink {
                        CommunityDetailView(postID: entry.id, service: session.community)
                    } label: {
                        PaperCard {
                            HStack {
                                Text("\(entry.position)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Zine.red)
                                Text(entry.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Zine.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text(entry.userDisplayName)
                                    .font(.caption)
                                    .foregroundStyle(Zine.muted)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var feedColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 10)]
        }
        let count = horizontalSizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
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
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text(post.content)
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                HStack(spacing: 10) {
                    Button {
                        Task { await model.toggleLike(post) }
                    } label: {
                        Label("\(model.likeCount(post))", systemImage: model.isLiked(post) ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundStyle(model.isLiked(post) ? Zine.red : Zine.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("点赞")
                    .accessibilityValue(
                        "\(model.likeCount(post)) 个赞，\(model.isLiked(post) ? "已点赞" : "未点赞")"
                    )
                    Label("\(post.commentCount)", systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                        .accessibilityLabel("\(post.commentCount) 条评论")
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
        .accessibilityAction(named: Text(model.isLiked(post) ? "取消点赞" : "点赞")) {
            Task { await model.toggleLike(post) }
        }
        .contextMenu {
            if model.canManagePins {
                Button("置顶这篇食记") {
                    Task { await model.pin(post) }
                }
            }
        }
    }
}
