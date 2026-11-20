import Foundation

@MainActor
final class MyVenueReviewsViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case hall
        case stall

        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "全部"
            case .hall: return "食堂"
            case .stall: return "档口"
            }
        }
        var type: String? { self == .all ? nil : rawValue }
    }

    @Published var filter: Filter = .all
    @Published private(set) var reviews: [VenueReview] = []
    @Published private(set) var total = 0
    @Published private(set) var page = 1
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: VenueReviewService
    private let pageSize = 20
    private var generation = 0

    init(service: VenueReviewService) {
        self.service = service
    }

    var hasMore: Bool { page * pageSize < total }

    var statusText: String {
        if isLoading && reviews.isEmpty { return "正在加载…" }
        return reviews.isEmpty ? "还没有食堂或档口点评" : "共 \(total) 条"
    }

    func load(reset: Bool = true) async {
        if reset {
            generation += 1
        }
        let current = generation
        isLoading = true
        errorMessage = nil
        defer {
            if current == generation { isLoading = false }
        }
        do {
            let result = try await service.myReviews(
                page: reset ? 1 : page + 1,
                size: pageSize,
                type: filter.type
            )
            guard current == generation else { return }
            reviews = reset ? result.items : merged(reviews, result.items)
            total = result.total
            page = reset ? 1 : page + 1
        } catch let error as AppError {
            if current == generation { errorMessage = error.localizedDescription }
        } catch {
            if current == generation { errorMessage = error.localizedDescription }
        }
    }

    func switchFilter(_ next: Filter) async {
        filter = next
        await load(reset: true)
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        await load(reset: false)
    }

    private func merged(_ current: [VenueReview], _ next: [VenueReview]) -> [VenueReview] {
        var seen = Set(current.map(\.id))
        var result = current
        for item in next where seen.insert(item.id).inserted {
            result.append(item)
        }
        return result
    }
}
