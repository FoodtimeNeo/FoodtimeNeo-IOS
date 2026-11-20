import Foundation

@MainActor
final class MyCommunityPostsViewModel: ObservableObject {
    @Published private(set) var posts: [CommunityPost] = []
    @Published private(set) var total = 0
    @Published private(set) var page = 1
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: CommunityService
    private let pageSize = 20

    init(service: CommunityService) {
        self.service = service
    }

    var hasMore: Bool { page * pageSize < total }

    var statusText: String {
        if isLoading && posts.isEmpty { return "正在加载…" }
        return posts.isEmpty ? "还没有发布食记" : "共 \(total) 条"
    }

    func load(page target: Int = 1) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.myPosts(page: max(1, target), size: pageSize)
            posts = target <= 1 ? result.items : merged(posts, result.items)
            total = result.total
            page = max(1, target)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        await load(page: page + 1)
    }

    private func merged(_ current: [CommunityPost], _ next: [CommunityPost]) -> [CommunityPost] {
        var seen = Set(current.map(\.id))
        var result = current
        for item in next where seen.insert(item.id).inserted {
            result.append(item)
        }
        return result
    }
}
