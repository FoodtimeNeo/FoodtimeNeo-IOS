import Combine
import Foundation

@MainActor
final class CommunityModerationViewModel: ObservableObject {
    enum Kind: String, CaseIterable, Identifiable {
        case posts
        case comments

        var id: String { rawValue }

        var title: String {
            self == .posts ? "食记" : "评论"
        }

        var singular: String {
            self == .posts ? "食记" : "评论"
        }
    }

    @Published var kind: Kind = .posts {
        didSet { Task { await load(page: 1) } }
    }
    @Published var status = "pending" {
        didSet { Task { await load(page: 1) } }
    }
    @Published private(set) var items: [ModerationItem] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: AdminService
    private let pageSize = 20

    init(service: AdminService) {
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
            let result = try await service.communityQueue(
                kind: kind.rawValue,
                status: status,
                page: max(1, page),
                size: pageSize
            )
            items = result.items
            self.page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moderationSucceeded(_ message: String) {
        infoMessage = message
        Task { await load(page: page) }
    }

    func delete(_ item: ModerationItem) async -> Bool {
        errorMessage = nil
        infoMessage = nil
        do {
            try await service.deleteCommunityContent(kind: kind.rawValue, id: item.id)
            infoMessage = "已删除该\(kind.singular)。"
            await load(page: page)
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class CommunityModerationDetailViewModel: ObservableObject {
    @Published private(set) var detail: CommunityModerationDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let service: AdminService
    private let kind: CommunityModerationViewModel.Kind
    let item: ModerationItem

    init(
        service: AdminService,
        kind: CommunityModerationViewModel.Kind,
        item: ModerationItem
    ) {
        self.service = service
        self.kind = kind
        self.item = item
    }

    var currentRevision: Int? {
        switch kind {
        case .posts:
            return detail?.post?.contentRevision ?? item.contentRevision
        case .comments:
            return item.contentRevision
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detail = try await service.communityModerationDetail(
                kind: kind.rawValue,
                id: item.id
            )
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moderate(action: String, reason: String?) async -> Bool {
        guard !isSubmitting else { return false }
        if action == "reject",
           reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            errorMessage = "驳回必须填写原因"
            return false
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await service.moderateCommunity(
                kind: kind.rawValue,
                id: item.id,
                action: action,
                reason: reason,
                contentRevision: currentRevision
            )
            return true
        } catch let error as AppError {
            if error.code == "POST_REVIEW_CONFLICT" {
                errorMessage = "内容已被作者修改，请刷新详情后重新审核。"
            } else if error.code == "ALREADY_REVIEWED" {
                errorMessage = "该提交已被审核，请返回刷新队列。"
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete() async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await service.deleteCommunityContent(kind: kind.rawValue, id: item.id)
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
