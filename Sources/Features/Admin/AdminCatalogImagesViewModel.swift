import Combine
import Foundation
import UIKit

@MainActor
final class AdminCatalogImagesViewModel: ObservableObject {
    let kind: AdminCatalogKind
    let item: AdminCatalogItem
    @Published private(set) var images: [AdminCatalogImage] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isUploading = false
    @Published private(set) var deletingID: String?
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: AdminService
    private let uploader: SubmissionService
    private let pageSize = 12

    init(
        service: AdminService,
        uploader: SubmissionService,
        kind: AdminCatalogKind,
        item: AdminCatalogItem
    ) {
        self.service = service
        self.uploader = uploader
        self.kind = kind
        self.item = item
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
            let result = try await service.catalogImages(
                type: kind.rawValue,
                id: item.id,
                page: max(1, page),
                size: pageSize
            )
            images = result.items
            self.page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(_ image: UIImage) async -> Bool {
        guard !isUploading else { return false }
        isUploading = true
        errorMessage = nil
        infoMessage = nil
        defer { isUploading = false }
        guard let data = ImageProcessor.jpegData(from: image) else {
            errorMessage = "图片处理失败，请重新选择"
            return false
        }
        do {
            let uploaded = try await uploader.uploadImage(data)
            _ = try await service.addCatalogImage(
                type: kind.rawValue,
                id: item.id,
                imageURL: uploaded.imageUrl
            )
            infoMessage = kind == .diningHalls ? "封面已更新。" : "图片已添加。"
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

    func remove(_ image: AdminCatalogImage) async -> Bool {
        guard deletingID == nil else { return false }
        deletingID = image.id
        errorMessage = nil
        infoMessage = nil
        defer { deletingID = nil }
        do {
            try await service.removeCatalogImage(
                type: kind.rawValue,
                id: item.id,
                imageID: image.id
            )
            infoMessage = "已移除图片。"
            if images.count == 1, page > 1 {
                await load(page: page - 1)
            } else {
                await load(page: page)
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
}
