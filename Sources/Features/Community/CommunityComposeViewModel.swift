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
    @Published private(set) var restoredDraft = false
    @Published var errorMessage: String?
    @Published private(set) var receipt: CommunityPostReceipt?

    private let community: CommunityService
    private let submissions: SubmissionService
    private let draftStore: CommunityDraftStore
    private let accountID: String
    private var imageFiles: [String] = []
    private var draftSaveTask: Task<Void, Never>?
    private var hasLoadedDraft = false

    init(
        community: CommunityService,
        submissions: SubmissionService,
        draftStore: CommunityDraftStore,
        accountID: String
    ) {
        self.community = community
        self.submissions = submissions
        self.draftStore = draftStore
        self.accountID = accountID
    }

    func loadDraft() {
        guard !hasLoadedDraft else { return }
        hasLoadedDraft = true
        guard let draft = draftStore.load(accountID: accountID), !draft.isEmpty else { return }
        title = draft.title
        content = draft.content
        imageFiles = draft.imageFiles
        images = imageFiles.compactMap { name in
            guard let data = draftStore.imageData(named: name, accountID: accountID) else { return nil }
            return UIImage(data: data)
        }
        restoredDraft = true
    }

    func setImages(_ next: [UIImage]) {
        images = Array(next.prefix(9))
        imageFiles = images.compactMap { image in
            guard let data = ImageProcessor.jpegData(from: image) else { return nil }
            return draftStore.saveImage(data, accountID: accountID)
        }
        requestID = UUID().uuidString
        scheduleSave()
    }

    func removeImage(at index: Int) {
        guard images.indices.contains(index) else { return }
        images.remove(at: index)
        if imageFiles.indices.contains(index) {
            imageFiles.remove(at: index)
        }
        requestID = UUID().uuidString
        scheduleSave()
    }

    func discardDraft() {
        title = ""
        content = ""
        images = []
        imageFiles = []
        restoredDraft = false
        draftStore.clear(accountID: accountID)
        requestID = UUID().uuidString
    }

    func scheduleSave() {
        draftSaveTask?.cancel()
        draftSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, !Task.isCancelled else { return }
            self.saveDraftNow()
        }
    }

    func saveDraftNow() {
        let draft = CommunityDraft(
            title: title,
            content: content,
            imageFiles: imageFiles,
            updatedAt: Date()
        )
        if draft.isEmpty {
            draftStore.clear(accountID: accountID)
        } else {
            draftStore.save(draft, accountID: accountID)
        }
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
            draftStore.clear(accountID: accountID)
            imageFiles = []
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
