import Combine
import Foundation

@MainActor
final class CommunityDetailViewModel: ObservableObject {
    @Published private(set) var post: CommunityPost?
    @Published private(set) var comments: [CommunityComment] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingComments = false
    @Published private(set) var hasMoreComments = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published private(set) var postLikeState: CommunityLikeState?
    @Published private(set) var favoriteState: CommunityLikeState?
    @Published private(set) var commentLikeStates: [String: CommunityLikeState] = [:]
    @Published var commentText = "" {
        didSet { requestID = UUID().uuidString }
    }
    @Published private(set) var requestID = UUID().uuidString
    @Published private(set) var isSubmittingComment = false

    private let postID: String
    private let service: CommunityService
    private var commentsCursor: String?
    private var viewRecorded = false

    init(postID: String, service: CommunityService) {
        self.postID = postID
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let post = try await service.detail(id: postID)
            self.post = post
            let page = try await service.roots(postID: postID, size: 20, cursor: nil)
            comments = page.items
            commentsCursor = page.nextCursor
            hasMoreComments = page.hasMore
            if !viewRecorded, post.status == "approved" {
                viewRecorded = true
                _ = try? await service.recordView(postID: postID, requestID: UUID().uuidString)
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreComments() async {
        guard hasMoreComments, !isLoadingComments, let cursor = commentsCursor else { return }
        isLoadingComments = true
        defer { isLoadingComments = false }
        do {
            let page = try await service.roots(postID: postID, size: 20, cursor: cursor)
            comments.append(contentsOf: page.items)
            commentsCursor = page.nextCursor
            hasMoreComments = page.hasMore
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLikePost() {
        guard let post else { return }
        Task {
            do {
                let liked = postLikeState?.likedByMe ?? post.likedByMe
                postLikeState = try await service.likePost(id: post.id, liked: !liked)
            } catch let error as AppError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleFavorite() {
        guard let post else { return }
        Task {
            do {
                let favorited = favoriteState?.favoritedByMe ?? post.favoritedByMe
                favoriteState = try await service.favoritePost(id: post.id, favorited: !favorited)
            } catch let error as AppError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleLikeComment(_ comment: CommunityComment) {
        Task {
            do {
                let current = commentLikeStates[comment.id]?.likedByMe ?? comment.likedByMe
                commentLikeStates[comment.id] = try await service.likeComment(
                    id: comment.id,
                    liked: !current
                )
            } catch let error as AppError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func submitComment() async {
        guard !isSubmittingComment else { return }
        let content = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { errorMessage = "请填写评论"; return }
        guard content.count <= 500 else { errorMessage = "评论不能超过 500 字"; return }
        isSubmittingComment = true
        errorMessage = nil
        infoMessage = nil
        defer { isSubmittingComment = false }
        do {
            let comment = try await service.submitComment(
                postID: postID,
                content: content,
                rootID: nil,
                replyToID: nil,
                requestID: requestID
            )
            commentText = ""
            infoMessage = comment.status == "pending"
                ? "评论已提交，审核通过后公开。"
                : "评论已提交。"
            comments.insert(comment, at: 0)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func likeCount(_ post: CommunityPost) -> Int {
        postLikeState?.likeCount ?? post.likeCount
    }

    func isLiked(_ post: CommunityPost) -> Bool {
        postLikeState?.likedByMe ?? post.likedByMe
    }

    func favoriteCount(_ post: CommunityPost) -> Int {
        favoriteState?.favoriteCount ?? post.favoriteCount
    }

    func isFavorited(_ post: CommunityPost) -> Bool {
        favoriteState?.favoritedByMe ?? post.favoritedByMe
    }

    func commentLikeCount(_ comment: CommunityComment) -> Int {
        commentLikeStates[comment.id]?.likeCount ?? comment.likeCount
    }

    func isCommentLiked(_ comment: CommunityComment) -> Bool {
        commentLikeStates[comment.id]?.likedByMe ?? comment.likedByMe
    }
}
