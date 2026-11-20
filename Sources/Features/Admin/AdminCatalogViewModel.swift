import Combine
import Foundation

@MainActor
final class AdminCatalogViewModel: ObservableObject {
    @Published var kind: AdminCatalogKind = .diningHalls {
        didSet { Task { await load(page: 1) } }
    }
    @Published private(set) var items: [AdminCatalogItem] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var deletingID: String?
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
            let result = try await service.catalogList(
                type: kind.rawValue,
                parentID: nil,
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

    func delete(_ item: AdminCatalogItem) async -> Bool {
        guard deletingID == nil else { return false }
        deletingID = item.id
        errorMessage = nil
        infoMessage = nil
        defer { deletingID = nil }
        do {
            try await service.deleteCatalogItem(type: kind.rawValue, id: item.id)
            infoMessage = "已删除 \(item.name)。"
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

    func saved(_ message: String) {
        infoMessage = message
        Task { await load(page: page) }
    }
}

@MainActor
final class AdminCatalogEditorViewModel: ObservableObject {
    @Published var name: String
    @Published var descriptionText: String
    @Published var priceText: String
    @Published var priceUnit: String
    @Published var status: String
    @Published var sortOrderText: String
    @Published var parentID: String
    @Published private(set) var parents: [AdminCatalogItem] = []
    @Published private(set) var isLoadingParents = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    let kind: AdminCatalogKind
    let existing: AdminCatalogItem?

    private let service: AdminService

    init(
        service: AdminService,
        kind: AdminCatalogKind,
        existing: AdminCatalogItem?
    ) {
        self.service = service
        self.kind = kind
        self.existing = existing
        name = existing?.name ?? ""
        descriptionText = existing?.description ?? ""
        priceText = Self.priceText(existing?.price)
        priceUnit = existing?.priceUnit ?? ""
        status = existing?.status ?? "active"
        sortOrderText = existing?.sortOrder.map(String.init) ?? ""
        parentID = existing?.parentId ?? ""
    }

    var parentKind: AdminCatalogKind? {
        kind.parentKind
    }

    func loadParents() async {
        guard let parentKind, !isLoadingParents else { return }
        isLoadingParents = true
        errorMessage = nil
        defer { isLoadingParents = false }
        do {
            let result = try await service.catalogList(
                type: parentKind.rawValue,
                parentID: nil,
                page: 1,
                size: 100
            )
            parents = result.items
            if parentID.isEmpty, existing == nil, let first = result.items.first {
                parentID = first.id
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "名称不能为空"
            return false
        }
        guard trimmedName.count <= 120 else {
            errorMessage = "名称不能超过 120 字"
            return false
        }
        if existing == nil, parentKind != nil, parentID.isEmpty {
            errorMessage = "请选择所属\(parentKind?.title ?? "")"
            return false
        }
        var price: Decimal?
        if kind.requiresPrice || !priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let normalized = priceText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
                  value >= 0 else {
                errorMessage = "请输入有效价格"
                return false
            }
            price = value
        }
        var sortOrder: Int?
        let sortText = sortOrderText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sortText.isEmpty {
            guard let value = Int(sortText) else {
                errorMessage = "排序必须是整数"
                return false
            }
            sortOrder = value
        }
        let description = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard description.count <= 500 else {
            errorMessage = "简介不能超过 500 字"
            return false
        }
        let edit = AdminCatalogEdit(
            parentId: parentKind == nil ? nil : (parentID.isEmpty ? nil : parentID),
            name: trimmedName,
            description: description.isEmpty ? nil : description,
            price: price,
            coverImageUrl: existing?.coverImageUrl,
            status: status,
            sortOrder: sortOrder,
            priceUnit: priceUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : priceUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isSaving = true
        defer { isSaving = false }
        do {
            if let existing {
                _ = try await service.updateCatalogItem(
                    type: kind.rawValue,
                    id: existing.id,
                    edit: edit
                )
            } else {
                _ = try await service.createCatalogItem(type: kind.rawValue, edit: edit)
            }
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func priceText(_ value: Decimal?) -> String {
        guard let value else { return "" }
        return NSDecimalNumber(decimal: value).stringValue
    }
}

@MainActor
final class AdminReviewsViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var reviews: [AdminReviewItem] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var removingID: String?
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: AdminService
    private var queryTask: Task<Void, Never>?
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
            let result = try await service.adminReviews(
                query: query,
                page: max(1, page),
                size: pageSize
            )
            reviews = result.items
            self.page = result.page
            total = result.total
        } catch let error as AppError {
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
            await self.load(page: 1)
        }
    }

    func remove(_ review: AdminReviewItem, reason: String) async -> Bool {
        guard removingID == nil else { return false }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "移除点评必须填写原因"
            return false
        }
        removingID = review.id
        errorMessage = nil
        infoMessage = nil
        defer { removingID = nil }
        do {
            try await service.removeReview(id: review.id, reason: trimmed)
            infoMessage = "已移除点评，评分已由服务端重算。"
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
