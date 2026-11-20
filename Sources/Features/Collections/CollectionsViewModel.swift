import Combine
import Foundation

@MainActor
final class CollectionsViewModel: ObservableObject {
    static let unfiledID = "__unfiled__"

    @Published var kind: FavoriteKind = .dish
    @Published private(set) var groups: [FavoriteGroup] = []
    @Published private(set) var selectedGroupID: String?
    @Published private(set) var dishItems: [DishSearchRow] = []
    @Published private(set) var postItems: [CommunityPost] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: FavoriteService
    private let pageSize = 20

    init(service: FavoriteService) {
        self.service = service
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / Double(pageSize))))
    }

    var isUnfiled: Bool {
        selectedGroupID == Self.unfiledID
    }

    func loadAll() async {
        await loadGroups()
        await loadFavorites(reset: true)
    }

    func loadGroups() async {
        do {
            groups = try await service.groups(kind: kind)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectKind(_ next: FavoriteKind) async {
        kind = next
        selectedGroupID = nil
        dishItems = []
        postItems = []
        await loadAll()
    }

    func selectGroup(_ id: String?) async {
        selectedGroupID = id
        await loadFavorites(reset: true)
    }

    func loadFavorites(reset: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let targetPage = reset ? 1 : page + 1
            let groupID = selectedGroupID == Self.unfiledID ? nil : selectedGroupID
            let unfiled = selectedGroupID == Self.unfiledID
            switch kind {
            case .dish:
                let result = try await service.dishFavorites(
                    groupID: groupID,
                    unfiled: unfiled,
                    page: targetPage,
                    size: pageSize
                )
                dishItems = reset ? result.items : dishItems + result.items
                page = result.page
                total = result.total
            case .post:
                let result = try await service.communityFavorites(
                    groupID: groupID,
                    unfiled: unfiled,
                    page: targetPage,
                    size: pageSize
                )
                postItems = reset ? result.items : postItems + result.items
                page = result.page
                total = result.total
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard page < totalPages else { return }
        await loadFavorites(reset: false)
    }

    func loadPage(_ number: Int) async {
        guard !isLoading, number >= 1 else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let groupID = selectedGroupID == Self.unfiledID ? nil : selectedGroupID
        let unfiled = selectedGroupID == Self.unfiledID
        do {
            switch kind {
            case .dish:
                let result = try await service.dishFavorites(
                    groupID: groupID,
                    unfiled: unfiled,
                    page: number,
                    size: pageSize
                )
                dishItems = result.items
                page = result.page
                total = result.total
            case .post:
                let result = try await service.communityFavorites(
                    groupID: groupID,
                    unfiled: unfiled,
                    page: number,
                    size: pageSize
                )
                postItems = result.items
                page = result.page
                total = result.total
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createGroup(name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "分组名称不能为空"
            return false
        }
        do {
            _ = try await service.createGroup(
                kind: kind,
                name: trimmed,
                sortOrder: groups.count
            )
            await loadGroups()
            return true
        } catch let error as AppError {
            handleGroupError(error)
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func renameGroup(_ group: FavoriteGroup, name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "分组名称不能为空"
            return false
        }
        do {
            _ = try await service.updateGroup(
                id: group.id,
                name: trimmed,
                sortOrder: group.sortOrder,
                expectedRevision: group.revision
            )
            await loadGroups()
            return true
        } catch let error as AppError {
            handleGroupError(error)
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteGroup(_ group: FavoriteGroup) async {
        do {
            try await service.deleteGroup(id: group.id)
            if selectedGroupID == group.id {
                selectedGroupID = nil
            }
            await loadGroups()
            await loadFavorites(reset: true)
        } catch let error as AppError {
            handleGroupError(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func groupName(_ id: String) -> String {
        groups.first { $0.id == id }?.name ?? id
    }

    private func handleGroupError(_ error: AppError) {
        switch error.code {
        case "GROUP_NAME_TAKEN": errorMessage = "同类型下已有同名分组"
        case "GROUP_LIMIT_REACHED": errorMessage = "每类最多 20 个分组"
        case "GROUP_REVISION_CONFLICT": errorMessage = "分组已变化，请刷新后重试"
        default: errorMessage = error.localizedDescription
        }
    }
}
