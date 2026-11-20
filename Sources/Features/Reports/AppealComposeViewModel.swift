import Foundation
import UIKit

@MainActor
final class AppealComposeViewModel: ObservableObject {
    struct EvidenceItem: Identifiable {
        let id: UUID
        let image: UIImage
        var url: String?
        var isUploading: Bool
    }

    @Published private(set) var decision: ModerationDecision?
    @Published private(set) var isLoading = false
    @Published var content = ""
    @Published private(set) var evidence: [EvidenceItem] = []
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var submittedAppeal: ReportAppeal?

    let decisionID: String
    private let service: ReportService
    private let submissions: SubmissionService
    private let drafts: AppealDraftStoring?
    private var pendingRequestID: String?
    private var pendingContent: String?

    init(
        decisionID: String,
        service: ReportService,
        submissions: SubmissionService,
        drafts: AppealDraftStoring?
    ) {
        self.decisionID = decisionID
        self.service = service
        self.submissions = submissions
        self.drafts = drafts
    }

    var remainingEvidenceSlots: Int { max(0, 3 - evidence.count) }

    var isUploadingEvidence: Bool { evidence.contains { $0.isUploading } }

    var deadlinePassed: Bool {
        guard let decision else { return false }
        return decision.appealDeadline <= Date()
    }

    var alreadyAppealed: Bool {
        !(decision?.appealStatus ?? "").isEmpty || submittedAppeal != nil
    }

    var appealStatusText: String {
        if let submittedAppeal {
            return submittedAppeal.statusLabel
        }
        return decision?.appealStatusLabel ?? ""
    }

    func load() async {
        guard !isLoading, decision == nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loaded = try await service.myDecision(id: decisionID)
            decision = loaded
            restoreDraftIfNeeded()
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEvidence(_ images: [UIImage]) async {
        guard !isSubmitting, !alreadyAppealed, !deadlinePassed else { return }
        let room = remainingEvidenceSlots
        guard room > 0 else {
            errorMessage = "最多只能添加 3 张证据"
            return
        }
        for image in images.prefix(room) {
            evidence.append(EvidenceItem(id: UUID(), image: image, url: nil, isUploading: false))
        }
        if images.count > room {
            errorMessage = "最多只能添加 3 张证据，多出的图片未加入"
        }
        persistDraft()
        await uploadPendingEvidence()
    }

    func removeEvidence(id: UUID) {
        guard !isSubmitting else { return }
        evidence.removeAll { $0.id == id }
        persistDraft()
    }

    func persistDraft() {
        guard let drafts, decision != nil, !alreadyAppealed else { return }
        let images = evidence.compactMap { item in
            ImageProcessor.jpegData(from: item.image, maxPixel: 1200, quality: 0.8)
        }
        drafts.save(AppealDraft(content: content, evidence: images), decisionID: decisionID)
    }

    func submit() async {
        guard !isSubmitting, let decision else { return }
        errorMessage = nil
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请填写申诉内容"
            return
        }
        guard trimmed.unicodeScalars.count <= 2000 else {
            errorMessage = "申诉内容不能超过2000字"
            return
        }
        guard decision.appealDeadline > Date() else {
            errorMessage = "申诉期限已过。"
            return
        }
        if evidence.contains(where: { $0.url == nil }) {
            await uploadPendingEvidence()
        }
        guard !evidence.contains(where: { $0.url == nil }) else {
            errorMessage = "证据图片上传失败，请重试"
            return
        }
        let requestID: String
        if let pendingRequestID, pendingContent == trimmed {
            requestID = pendingRequestID
        } else {
            requestID = UUID().uuidString
        }
        pendingRequestID = requestID
        pendingContent = trimmed

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let appeal = try await service.submitAppeal(
                decisionID: decisionID,
                content: trimmed,
                evidenceURLs: evidence.compactMap(\.url),
                requestID: requestID
            )
            submittedAppeal = appeal
            drafts?.clear(decisionID: decisionID)
            pendingRequestID = nil
            pendingContent = nil
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restoreDraftIfNeeded() {
        guard let drafts, let draft = drafts.load(decisionID: decisionID),
              !alreadyAppealed, !deadlinePassed else { return }
        content = draft.content
        evidence = draft.evidence.compactMap { data in
            guard let image = UIImage(data: data) else { return nil }
            return EvidenceItem(id: UUID(), image: image, url: nil, isUploading: false)
        }
    }

    private func uploadPendingEvidence() async {
        let pending = evidence.filter { $0.url == nil }.map(\.id)
        for id in pending {
            guard let index = evidence.firstIndex(where: { $0.id == id }), evidence[index].url == nil else {
                continue
            }
            guard let data = ImageProcessor.jpegData(from: evidence[index].image) else {
                errorMessage = "证据图片处理失败，请重新选择"
                return
            }
            evidence[index].isUploading = true
            do {
                let uploaded = try await submissions.uploadImage(data)
                guard let current = evidence.firstIndex(where: { $0.id == id }) else { continue }
                evidence[current].url = uploaded.imageUrl
                evidence[current].isUploading = false
            } catch let error as AppError {
                if let current = evidence.firstIndex(where: { $0.id == id }) {
                    evidence[current].isUploading = false
                }
                errorMessage = error.localizedDescription
                return
            } catch {
                if let current = evidence.firstIndex(where: { $0.id == id }) {
                    evidence[current].isUploading = false
                }
                errorMessage = error.localizedDescription
                return
            }
        }
    }
}
