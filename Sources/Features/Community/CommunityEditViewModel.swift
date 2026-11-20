import Combine
import Foundation
import UIKit

@MainActor
final class CommunityEditViewModel: ObservableObject {
    @Published var title: String {
        didSet { requestID = UUID().uuidString }
    }
    @Published var content: String {
        didSet { requestID = UUID().uuidString }
    }
    @Published private(set) var existingURLs: [String]
    @Published private(set) var pickedImages: [UIImage] = []
    @Published private(set) var requestID = UUID().uuidString
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var receipt: CommunityEditReceipt?

    let expectedRevision: Int
    private let postID: String
    private let isRepost: Bool
    private let community: CommunityService
    private let submissions: SubmissionService

    init(post: CommunityPost, community: CommunityService, submissions: SubmissionService) {
        self.postID = post.id
        self.expectedRevision = post.contentRevision
        self.isRepost = post.repostOfId != nil
        self.existingURLs = post.imageUrls
        self.title = post.title
        self.content = post.content
        self.community = community
        self.submissions = submissions
    }

    var remainingSlots: Int {
        max(0, 9 - existingURLs.count - pickedImages.count)
    }

    func addImages(_ images: [UIImage]) {
        pickedImages.append(contentsOf: images.prefix(remainingSlots))
        requestID = UUID().uuidString
    }

    func removePicked(at index: Int) {
        guard pickedImages.indices.contains(index) else { return }
        pickedImages.remove(at: index)
        requestID = UUID().uuidString
    }

    func removeExisting(at index: Int) {
        guard existingURLs.indices.contains(index) else { return }
        existingURLs.remove(at: index)
        requestID = UUID().uuidString
    }

    func submit() async {
        guard !isSubmitting else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { errorMessage = "请填写标题"; return }
        guard trimmedTitle.count <= 50 else { errorMessage = "标题不能超过 50 字"; return }
        guard !trimmedContent.isEmpty else { errorMessage = "请填写正文"; return }
        guard trimmedContent.count <= 2000 else { errorMessage = "正文不能超过 2000 字"; return }
        guard !existingURLs.isEmpty || !pickedImages.isEmpty || isRepost else {
            errorMessage = "原创食记至少保留 1 张图片"
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            var uploaded: [String] = []
            for image in pickedImages {
                guard let data = ImageProcessor.jpegData(from: image) else {
                    throw AppError.invalidResponse(message: "图片处理失败，请重新选择")
                }
                let media = try await submissions.uploadImage(data)
                uploaded.append(media.imageUrl)
            }
            receipt = try await community.editPost(
                id: postID,
                expectedRevision: expectedRevision,
                title: trimmedTitle,
                content: trimmedContent,
                imageURLs: existingURLs + uploaded,
                requestID: requestID
            )
        } catch let error as AppError {
            switch error.code {
            case "POST_EDIT_CONFLICT":
                errorMessage = "食记已被修改，请关闭本页重新读取最新内容后再编辑"
            case "REQUEST_CONFLICT":
                errorMessage = "请求编号已用于另一份内容，请重新编辑后提交"
            case "IMAGE_DUPLICATED":
                errorMessage = "请勿重复添加同一张图片"
            case "POST_IMAGES_REQUIRED":
                errorMessage = "原创食记至少保留 1 张图片"
            case "DISH_NOT_FOUND":
                errorMessage = "关联菜品不存在或暂不可用"
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
