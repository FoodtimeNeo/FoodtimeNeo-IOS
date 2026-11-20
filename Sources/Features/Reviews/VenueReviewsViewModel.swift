import Combine
import Foundation

@MainActor
final class VenueReviewsViewModel: ObservableObject {
    @Published private(set) var target: VenueRatingTarget?
    @Published private(set) var reviews: [VenueReview] = []
    @Published private(set) var mine: VenueReviewMine?
    @Published private(set) var total = 0
    @Published private(set) var hasMore = false
    @Published private(set) var nextCursor: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var ratingFilter = "all"
    @Published private(set) var likeStates: [String: ReviewLikeState] = [:]

    private let type: VenueTargetType
    private let targetID: String
    private let service: VenueReviewService
    private let pageSize = 20

    init(type: VenueTargetType, targetID: String, service: VenueReviewService) {
        self.type = type
        self.targetID = targetID
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            target = try await service.target(type: type, id: targetID)
            let page = try await service.reviews(
                type: type,
                id: targetID,
                rating: ratingFilter,
                cursor: nil,
                size: pageSize
            )
            reviews = page.items
            total = page.total
            hasMore = page.hasMore
            nextCursor = page.nextCursor
            mine = try? await service.mine(type: type, id: targetID)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changeFilter(_ filter: String) async {
        ratingFilter = filter
        await load()
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, let cursor = nextCursor, !cursor.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.reviews(
                type: type,
                id: targetID,
                rating: ratingFilter,
                cursor: cursor,
                size: pageSize
            )
            reviews.append(contentsOf: page.items)
            total = page.total
            hasMore = page.hasMore
            nextCursor = page.nextCursor
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(_ review: VenueReview) {
        let current = likeStates[review.id]?.likedByMe ?? review.likedByMe
        Task {
            do {
                likeStates[review.id] = try await service.setLike(
                    reviewID: review.id,
                    liked: !current
                )
            } catch let error as AppError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func likeCount(_ review: VenueReview) -> Int {
        likeStates[review.id]?.likeCount ?? review.likeCount
    }

    func isLiked(_ review: VenueReview) -> Bool {
        likeStates[review.id]?.likedByMe ?? review.likedByMe
    }

    func reloadAfterSubmit() async {
        await load()
    }
}

@MainActor
final class VenueReviewComposerViewModel: ObservableObject {
    @Published var rating = 5
    @Published var content = "" {
        didSet { requestID = UUID().uuidString }
    }
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var didSubmit = false
    @Published private(set) var requestID = UUID().uuidString

    private let type: VenueTargetType
    private let targetID: String
    private let service: VenueReviewService

    init(type: VenueTargetType, targetID: String, service: VenueReviewService) {
        self.type = type
        self.targetID = targetID
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
            _ = try await service.submit(
                type: type,
                id: targetID,
                rating: rating,
                content: ReviewValidation.normalizedContent(content),
                requestID: requestID
            )
            content = ""
            didSubmit = true
        } catch let error as AppError {
            if error.code == "VENUE_REVIEW_CONFLICT" {
                errorMessage = "该评价已有待审核或已通过记录，请先查看你的评价状态"
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
