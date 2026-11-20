import Combine
import Foundation

@MainActor
final class MyReviewsViewModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case published
        case submissions

        var id: String { rawValue }
        var title: String { self == .published ? "已发布" : "审核记录" }
    }

    @Published var tab: Tab = .published
    @Published private(set) var reviews: [Review] = []
    @Published private(set) var submissions: [ReviewSubmission] = []
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
            switch tab {
            case .published:
                let result = try await service.myReviews(page: max(1, page), size: pageSize)
                reviews = result.items
                self.page = result.page
                total = result.total
            case .submissions:
                let result = try await service.myReviewSubmissions(page: max(1, page), size: pageSize)
                submissions = result.items
                self.page = result.page
                total = result.total
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ review: Review) async {
        errorMessage = nil
        infoMessage = nil
        do {
            try await service.deleteMyReview(id: review.id)
            reviews.removeAll { $0.id == review.id }
            total = max(0, total - 1)
            infoMessage = "点评已删除，评分会同步更新。"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
