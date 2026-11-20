import Foundation

@MainActor
final class AuthorPostsViewModel: ObservableObject {
    @Published private(set) var author: CommunityAuthor?
    @Published private(set) var posts: [CommunityPost] = []
    @Published private(set) var total = 0
    @Published private(set) var hasMore = false
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    let authorID: String
    private let service: CommunityService
    private var cursor: String?

    init(authorID: String, service: CommunityService) {
        self.authorID = authorID
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        cursor = nil
        defer { isLoading = false }
        do {
            async let profile = service.author(id: authorID)
            async let page = service.authorPosts(authorID: authorID, size: 20, cursor: nil)
            let (loadedAuthor, loadedPage) = try await (profile, page)
            author = loadedAuthor
            posts = loadedPage.items
            total = loadedPage.total
            cursor = loadedPage.nextCursor
            hasMore = loadedPage.hasMore
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }
        do {
            let page = try await service.authorPosts(
                authorID: authorID,
                size: 20,
                cursor: cursor
            )
            var seen = Set(posts.map(\.id))
            for post in page.items where seen.insert(post.id).inserted {
                posts.append(post)
            }
            cursor = page.nextCursor
            hasMore = page.hasMore
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
