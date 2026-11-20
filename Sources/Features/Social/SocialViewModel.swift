import Combine
import Foundation

@MainActor
final class SocialViewModel: ObservableObject {
    enum Segment: String, CaseIterable, Identifiable, Hashable {
        case following
        case followers
        case blocks
        case search

        var id: String { rawValue }

        var title: String {
            switch self {
            case .following: return "关注"
            case .followers: return "粉丝"
            case .blocks: return "黑名单"
            case .search: return "搜索"
            }
        }
    }

    @Published var segment: Segment = .following
    @Published var query = ""
    @Published private(set) var users: [SocialUser] = []
    @Published private(set) var blockedUsers: [BlockedUser] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = false
    @Published private(set) var blockedIDs: Set<String> = []
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let session: AppSession
    private let currentUserID: String
    private var page = 1
    private let pageSize = 20
    private var searchTask: Task<Void, Never>?

    init(session: AppSession, currentUserID: String) {
        self.session = session
        self.currentUserID = currentUserID
    }

    var isSearching: Bool {
        segment == .search && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        page = 1
        users = []
        blockedUsers = []
        defer { isLoading = false }

        do {
            switch segment {
            case .following:
                let result = try await session.social.following(
                    userID: currentUserID,
                    page: 1,
                    size: pageSize
                )
                users = result.items
                hasMore = result.items.count >= pageSize
            case .followers:
                let result = try await session.social.followers(
                    userID: currentUserID,
                    page: 1,
                    size: pageSize
                )
                users = result.items
                hasMore = result.items.count >= pageSize
            case .blocks:
                let result = try await session.social.blockedUsers(page: 1, size: pageSize)
                blockedUsers = result.items
                blockedIDs = Set(result.items.map(\.id))
                hasMore = result.items.count >= pageSize
            case .search:
                if !isSearching {
                    users = []
                    hasMore = false
                } else {
                    let result = try await session.social.searchUsers(
                        query: query,
                        page: 1,
                        size: pageSize
                    )
                    users = result.items
                    hasMore = result.items.count >= pageSize
                }
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchQueryChanged() {
        searchTask?.cancel()
        searchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.reload()
        }
    }

    func loadMoreIfNeeded(currentUser user: SocialUser) async {
        guard segment != .blocks, hasMore, !isLoadingMore, !isLoading,
              users.last?.id == user.id else { return }
        await loadMore()
    }

    func loadMoreBlockedIfNeeded(currentUser user: BlockedUser) async {
        guard segment == .blocks, hasMore, !isLoadingMore, !isLoading,
              blockedUsers.last?.id == user.id else { return }
        await loadMore()
    }

    func toggleFollow(_ user: SocialUser) async {
        errorMessage = nil
        infoMessage = nil
        do {
            let state = user.followedByMe
                ? try await session.social.unfollow(userID: user.id)
                : try await session.social.follow(userID: user.id)
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = SocialUser(
                    id: user.id,
                    displayName: user.displayName,
                    avatarUrl: user.avatarUrl,
                    followedByMe: state.followed
                )
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func block(_ user: SocialUser) async {
        errorMessage = nil
        infoMessage = nil
        do {
            let state = try await session.social.block(userID: user.id)
            if state.blocked {
                blockedIDs.insert(user.id)
                infoMessage = "已拉黑 \(user.displayName)；拉黑主要影响私信。"
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unblock(_ user: BlockedUser) async {
        errorMessage = nil
        infoMessage = nil
        do {
            let state = try await session.social.unblock(userID: user.id)
            if !state.blocked {
                blockedUsers.removeAll { $0.id == user.id }
                blockedIDs.remove(user.id)
                infoMessage = "已解除拉黑 \(user.displayName)。"
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let next = page + 1
        do {
            switch segment {
            case .following:
                let result = try await session.social.following(
                    userID: currentUserID,
                    page: next,
                    size: pageSize
                )
                users.append(contentsOf: result.items)
                hasMore = result.items.count >= pageSize
            case .followers:
                let result = try await session.social.followers(
                    userID: currentUserID,
                    page: next,
                    size: pageSize
                )
                users.append(contentsOf: result.items)
                hasMore = result.items.count >= pageSize
            case .blocks:
                let result = try await session.social.blockedUsers(page: next, size: pageSize)
                blockedUsers.append(contentsOf: result.items)
                blockedIDs.formUnion(result.items.map(\.id))
                hasMore = result.items.count >= pageSize
            case .search:
                let result = try await session.social.searchUsers(
                    query: query,
                    page: next,
                    size: pageSize
                )
                users.append(contentsOf: result.items)
                hasMore = result.items.count >= pageSize
            }
            page = next
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
