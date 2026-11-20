import Combine
import Foundation

@MainActor
final class CommunityThreadViewModel: ObservableObject {
    @Published private(set) var replies: [CommunityComment] = []
    @Published private(set) var total = 0
    @Published private(set) var hasMore = false
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var content = "" {
        didSet { requestID = UUID().uuidString }
    }
    @Published private(set) var requestID = UUID().uuidString
    @Published private(set) var isSubmitting = false
    @Published private(set) var replyTarget: CommunityComment?
    @Published private(set) var likeStates: [String: CommunityLikeState] = [:]

    let root: CommunityComment
    private let postID: String
    private let service: CommunityService
    private var cursor: String?

    init(root: CommunityComment, postID: String, service: CommunityService) {
        self.root = root
        self.postID = postID
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await service.replies(
                postID: postID,
                rootID: root.id,
                size: 20,
                cursor: nil
            )
            replies = page.items
            total = page.total
            hasMore = page.hasMore
            cursor = page.nextCursor
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, let cursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.replies(
                postID: postID,
                rootID: root.id,
                size: 20,
                cursor: cursor
            )
            replies.append(contentsOf: page.items)
            hasMore = page.hasMore
            self.cursor = page.nextCursor
            total = page.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setReplyTarget(_ comment: CommunityComment) {
        replyTarget = comment
    }

    func clearReplyTarget() {
        replyTarget = nil
    }

    func toggleLike(_ comment: CommunityComment) {
        Task {
            do {
                let current = likeStates[comment.id]?.likedByMe ?? comment.likedByMe
                likeStates[comment.id] = try await service.likeComment(
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

    func likeCount(_ comment: CommunityComment) -> Int {
        likeStates[comment.id]?.likeCount ?? comment.likeCount
    }

    func isLiked(_ comment: CommunityComment) -> Bool {
        likeStates[comment.id]?.likedByMe ?? comment.likedByMe
    }

    func submit() async {
        guard !isSubmitting else { return }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { errorMessage = "请填写回复"; return }
        guard text.count <= 500 else { errorMessage = "回复不能超过 500 字"; return }
        isSubmitting = true
        errorMessage = nil
        infoMessage = nil
        defer { isSubmitting = false }
        do {
            let created = try await service.submitComment(
                postID: postID,
                content: text,
                rootID: root.id,
                replyToID: replyTarget?.id,
                requestID: requestID
            )
            content = ""
            replyTarget = nil
            replies.append(created)
            total += 1
            infoMessage = created.status == "pending"
                ? "回复已提交，审核通过后公开。"
                : "回复已提交。"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
