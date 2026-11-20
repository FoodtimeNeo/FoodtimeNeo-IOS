import Combine
import Foundation

@MainActor
final class CommunityFeedViewModel: ObservableObject {
    enum Segment: String, CaseIterable, Identifiable, Hashable {
        case discover
        case following

        var id: String { rawValue }
        var title: String { self == .discover ? "发现" : "关注" }
    }

    @Published var segment: Segment = .discover
    @Published var query = ""
    @Published private(set) var posts: [CommunityPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = false
    @Published var errorMessage: String?
    @Published private(set) var pins: CommunityPinSnapshot?
    @Published private(set) var likeStates: [String: CommunityLikeState] = [:]

    private let service: CommunityService
    private var cursor: String?
    private var queryTask: Task<Void, Never>?

    init(service: CommunityService) {
        self.service = service
    }

    func load(reset: Bool = true) async {
        guard !isLoading else { return }
        if reset {
            posts = []
            cursor = nil
            hasMore = false
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await service.feed(
                size: 20,
                cursor: reset ? nil : cursor,
                following: segment == .following,
                query: query,
                pinRevision: reset ? nil : pins?.revision
            )
            posts = reset ? page.items : posts + page.items
            cursor = page.nextCursor
            hasMore = page.hasMore
            pins = page.pins
        } catch let error as AppError {
            if error.code == "PIN_SET_CHANGED" {
                isLoading = false
                await load(reset: true)
                return
            }
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.feed(
                size: 20,
                cursor: cursor,
                following: segment == .following,
                query: query,
                pinRevision: pins?.revision
            )
            posts.append(contentsOf: page.items)
            cursor = page.nextCursor
            hasMore = page.hasMore
            if let nextPins = page.pins {
                pins = nextPins
            }
        } catch let error as AppError {
            if error.code == "PIN_SET_CHANGED" {
                isLoadingMore = false
                await load(reset: true)
                return
            }
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func queryChanged() {
        queryTask?.cancel()
        queryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.load(reset: true)
        }
    }

    func switchSegment(_ next: Segment) async {
        segment = next
        await load(reset: true)
    }

    func toggleLike(_ post: CommunityPost) async {
        errorMessage = nil
        do {
            let current = likeStates[post.id]?.likedByMe ?? post.likedByMe
            likeStates[post.id] = try await service.likePost(id: post.id, liked: !current)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func likeCount(_ post: CommunityPost) -> Int {
        likeStates[post.id]?.likeCount ?? post.likeCount
    }

    func isLiked(_ post: CommunityPost) -> Bool {
        likeStates[post.id]?.likedByMe ?? post.likedByMe
    }

    var canManagePins: Bool {
        pins?.canManage == true
    }

    func pin(_ post: CommunityPost) async {
        guard let revision = pins?.revision else { return }
        errorMessage = nil
        do {
            pins = try await service.pin(postID: post.id, expectedRevision: revision)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadPinsAfterManagement() async {
        await load(reset: true)
    }
}
