import Combine
import Foundation

@MainActor
final class DishReviewsViewModel: ObservableObject {
    @Published private(set) var reviews: [Review] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    private let dishID: String
    private let service: ReviewService
    private let pageSize = 20

    init(dishID: String, service: ReviewService) {
        self.dishID = dishID
        self.service = service
    }

    var hasMore: Bool {
        page * pageSize < total
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.reviews(dishID: dishID, page: 1, size: pageSize)
            reviews = result.items
            page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await service.reviews(dishID: dishID, page: page + 1, size: pageSize)
            reviews.append(contentsOf: result.items)
            page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(_ review: Review) async {
        errorMessage = nil
        do {
            let state = try await service.setReviewLike(id: review.id, liked: !review.likedByMe)
            if let index = reviews.firstIndex(where: { $0.id == review.id }) {
                let old = reviews[index]
                reviews[index] = Review(
                    id: old.id,
                    dishId: old.dishId,
                    userId: old.userId,
                    userDisplayName: old.userDisplayName,
                    rating: old.rating,
                    content: old.content,
                    createdAt: old.createdAt,
                    updatedAt: old.updatedAt,
                    dishName: old.dishName,
                    stallId: old.stallId,
                    stallName: old.stallName,
                    diningHallId: old.diningHallId,
                    diningHallName: old.diningHallName,
                    likeCount: state.likeCount,
                    replyCount: old.replyCount,
                    likedByMe: state.likedByMe,
                    counterVersion: state.counterVersion
                )
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class ReviewComposerViewModel: ObservableObject {
    @Published var rating = 5
    @Published var content = ""
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var didSubmit = false

    private let dishID: String
    private let service: ReviewService

    init(dishID: String, service: ReviewService) {
        self.dishID = dishID
        self.service = service
    }

    func submit() async {
        guard !isSubmitting else { return }
        if let error = ReviewValidation.ratingError(rating) {
            errorMessage = error
            return
        }
        if let error = ReviewValidation.contentError(content) {
            errorMessage = error
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await service.submitReview(
                dishID: dishID,
                rating: rating,
                content: ReviewValidation.normalizedContent(content)
            )
            content = ""
            didSubmit = true
        } catch let error as AppError {
            if error.code == "REVIEW_PENDING" {
                errorMessage = "你在该菜品已有待审核点评，请等待审核或先处理已有提交"
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
