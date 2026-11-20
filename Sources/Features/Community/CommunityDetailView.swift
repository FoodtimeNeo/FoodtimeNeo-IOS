import SwiftUI

@MainActor
struct CommunityDetailView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var model: CommunityDetailViewModel
    @State private var showGallery = false
    @State private var galleryStart = 0

    init(postID: String, service: CommunityService) {
        _model = StateObject(
            wrappedValue: CommunityDetailViewModel(postID: postID, service: service)
        )
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    content
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
                    commentsSection
                }
                .padding(Zine.pagePadding)
            }
            .safeAreaInset(edge: .bottom) {
                composer
            }
        }
        .navigationTitle("食记")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .fullScreenCover(isPresented: $showGallery) {
            DishGalleryView(
                urls: galleryURLs,
                startIndex: galleryStart
            )
        }
    }

    private var galleryURLs: [URL] {
        guard let post = model.post else { return [] }
        return post.images.compactMap {
            MediaURL.resolve($0.url, baseURL: session.catalog.mediaBaseURL)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.post == nil {
            LoadingStateView(message: "正在读取食记…")
        } else if let error = model.errorMessage, model.post == nil {
            ErrorStateView(message: error) {
                Task { await model.load() }
            }
        } else if let post = model.post {
            postCard(post)
            commentsList
        }
    }

    private func postCard(_ post: CommunityPost) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(post.userDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(DisplayFormat.dateTime(post.createdAt))
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                if !post.title.isEmpty {
                    Text(post.title)
                        .font(.system(size: 24, weight: .black, design: .serif))
                        .foregroundStyle(Zine.ink)
                }
                Text(post.content)
                    .font(.body)
                    .foregroundStyle(Zine.ink)
                    .textSelection(.enabled)

                if let repost = post.repost {
                    Text("转发自 \(repost.userDisplayName)：\(repost.content)")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Zine.alt)
                }

                if !galleryURLs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(galleryURLs.indices, id: \.self) { index in
                                AsyncImage(url: galleryURLs[index]) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    default:
                                        Zine.alt
                                    }
                                }
                                .frame(width: 150, height: 150)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: Zine.smallRadius))
                                .onTapGesture {
                                    galleryStart = index
                                    showGallery = true
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 18) {
                    Button {
                        model.toggleLikePost()
                    } label: {
                        Label(
                            "\(model.likeCount(post))",
                            systemImage: model.isLiked(post) ? "heart.fill" : "heart"
                        )
                        .foregroundStyle(model.isLiked(post) ? Zine.red : Zine.muted)
                    }
                    .buttonStyle(.plain)
                    Button {
                        model.toggleFavorite()
                    } label: {
                        Label(
                            "\(model.favoriteCount(post))",
                            systemImage: model.isFavorited(post) ? "star.fill" : "star"
                        )
                        .foregroundStyle(model.isFavorited(post) ? Zine.gold : Zine.muted)
                    }
                    .buttonStyle(.plain)
                    Label("\(post.viewCount)", systemImage: "eye")
                        .foregroundStyle(Zine.muted)
                }
                .font(.subheadline)
            }
        }
    }

    private var commentsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("评论 \(model.post?.commentCount ?? 0)")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(Zine.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(model.comments) { comment in
                commentRow(comment)
            }
            if model.hasMoreComments {
                Button("加载更多评论") {
                    Task { await model.loadMoreComments() }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(model.isLoadingComments)
            }
        }
    }

    private func commentRow(_ comment: CommunityComment) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(comment.userDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Zine.ink)
                    if comment.deleted {
                        Text("已删除")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    }
                    Spacer()
                    Text(DisplayFormat.dateTime(comment.createdAt))
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                Text(comment.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                HStack(spacing: 14) {
                    Button {
                        model.toggleLikeComment(comment)
                    } label: {
                        Label(
                            "\(model.commentLikeCount(comment))",
                            systemImage: model.isCommentLiked(comment) ? "heart.fill" : "heart"
                        )
                        .font(.caption)
                        .foregroundStyle(model.isCommentLiked(comment) ? Zine.red : Zine.muted)
                    }
                    .buttonStyle(.plain)
                    if comment.replyCount > 0 {
                        Label("\(comment.replyCount)", systemImage: "text.bubble")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var commentsSection: some View {
        if model.post != nil, model.comments.isEmpty, !model.isLoading {
            EmptyStateView(title: "还没有评论", message: "在下方写下第一条评论。")
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextEditor(text: $model.commentText)
                .frame(minHeight: 44, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                .overlay(
                    RoundedRectangle(cornerRadius: Zine.smallRadius)
                        .stroke(Zine.border, lineWidth: 1)
                )
                .onChange(of: model.commentText) { _, value in
                    if value.count > 500 {
                        model.commentText = String(value.prefix(500))
                    }
                }
            Button {
                Task { await model.submitComment() }
            } label: {
                if model.isSubmittingComment {
                    ProgressView().tint(Zine.onRed)
                } else {
                    Text("发送")
                }
            }
            .buttonStyle(InkButtonStyle(primary: true))
            .frame(width: 82)
            .disabled(model.isSubmittingComment)
        }
        .padding(.horizontal, Zine.pagePadding)
        .padding(.vertical, 8)
        .background(Zine.bar)
    }
}
