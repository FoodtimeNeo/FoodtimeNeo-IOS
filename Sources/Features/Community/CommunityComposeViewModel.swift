import Combine
import Foundation
import UIKit

@MainActor
final class CommunityComposeViewModel: ObservableObject {
    @Published var title = "" {
        didSet { requestID = UUID().uuidString }
    }
    @Published var content = "" {
        didSet { requestID = UUID().uuidString }
    }
    @Published private(set) var images: [UIImage] = []
    @Published private(set) var requestID = UUID().uuidString
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var receipt: CommunityPostReceipt?

    private let community: CommunityService
    private let submissions: SubmissionService

    init(community: CommunityService, submissions: SubmissionService) {
        self.community = community
        self.submissions = submissions
    }

    func setImages(_ next: [UIImage]) {
        images = Array(next.prefix(9))
        requestID = UUID().uuidString
    }

    func removeImage(at index: Int) {
        guard images.indices.contains(index) else { return }
        images.remove(at: index)
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

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            var imageURLs: [String] = []
            for image in images {
                guard let data = ImageProcessor.jpegData(from: image) else {
                    throw AppError.invalidResponse(message: "图片处理失败，请重新选择")
                }
                let uploaded = try await submissions.uploadImage(data)
                imageURLs.append(uploaded.imageUrl)
            }
            receipt = try await community.createPost(
                title: trimmedTitle,
                content: trimmedContent,
                imageURLs: imageURLs,
                requestID: requestID
            )
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
