import Combine
import Foundation

@MainActor
final class ReviewThreadViewModel: ObservableObject {
    @Published private(set) var replies: [ReviewReply] = []
    @Published private(set) var total = 0
    @Published private(set) var hasMore = false
    @Published private(set) var nextCursor: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    @Published var content = "" {
        didSet { requestID = UUID().uuidString }
    }
    @Published var replyToID: String?
    @Published var replyToName: String?
    @Published private(set) var isSubmitting = false
    @Published private(set) var requestID = UUID().uuidString
    @Published private(set) var likeStates: [String: ReviewLikeState] = [:]

    private let reviewID: String
    private let service: ReviewService
    private let pageSize = 20

    init(reviewID: String, service: ReviewService) {
        self.reviewID = reviewID
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await service.replies(reviewID: reviewID, size: pageSize, cursor: nil)
            replies = page.items
            total = page.total
            hasMore = page.hasMore
            nextCursor = page.nextCursor
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, let cursor = nextCursor, !cursor.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.replies(reviewID: reviewID, size: pageSize, cursor: cursor)
            replies.append(contentsOf: page.items)
            total = page.total
            hasMore = page.hasMore
            nextCursor = page.nextCursor
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(_ reply: ReviewReply) {
        let current = likeStates[reply.id]
        let liked = current?.likedByMe ?? reply.likedByMe
        Task {
            do {
                let state = try await service.setReplyLike(id: reply.id, liked: !liked)
                likeStates[reply.id] = state
            } catch let error as AppError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func likeCount(_ reply: ReviewReply) -> Int {
        likeStates[reply.id]?.likeCount ?? reply.likeCount
    }

    func isLiked(_ reply: ReviewReply) -> Bool {
        likeStates[reply.id]?.likedByMe ?? reply.likedByMe
    }

    func setReplyTarget(_ reply: ReviewReply) {
        replyToID = reply.id
        replyToName = reply.userDisplayName
    }

    func clearReplyTarget() {
        replyToID = nil
        replyToName = nil
    }

    func submit() async {
        guard !isSubmitting else { return }
        if let error = ReviewValidation.contentError(content) {
            errorMessage = error
            return
        }
        isSubmitting = true
        errorMessage = nil
        infoMessage = nil
        defer { isSubmitting = false }
        do {
            let receipt = try await service.submitReply(
                reviewID: reviewID,
                content: ReviewValidation.normalizedContent(content),
                replyToID: replyToID,
                requestID: requestID
            )
            content = ""
            clearReplyTarget()
            infoMessage = receipt.status == "pending"
                ? "回复已提交，审核通过后公开。"
                : "回复已提交。"
        } catch let error as AppError {
            if error.code == "REPLY_REQUEST_CONFLICT" {
                errorMessage = "请求编号已被用于其他内容，请重新编辑后提交"
            } else if case .validation(let fields) = error {
                errorMessage = fields.isEmpty
                    ? error.localizedDescription
                    : fields.map(\.message).joined(separator: "；")
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class MyRepliesViewModel: ObservableObject {
    @Published private(set) var replies: [ReviewReply] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: ReviewService
    private let pageSize = 20

    init(service: ReviewService) {
        self.service = service
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / Double(pageSize))))
    }

    func load(page: Int = 1) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.myReplies(page: max(1, page), size: pageSize)
            replies = result.items
            self.page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ reply: ReviewReply) async {
        errorMessage = nil
        infoMessage = nil
        do {
            try await service.deleteReply(id: reply.id)
            replies.removeAll { $0.id == reply.id }
            total = max(0, total - 1)
            infoMessage = "回复已删除，后续回复与审核历史保留。"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
