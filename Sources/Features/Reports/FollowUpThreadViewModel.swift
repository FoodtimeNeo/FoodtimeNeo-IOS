import Foundation
import UIKit

@MainActor
final class FollowUpThreadViewModel: ObservableObject {
    struct EvidenceItem: Identifiable {
        let id: UUID
        let image: UIImage
        var url: String?
        var isUploading: Bool
    }

    @Published private(set) var items: [ReportFollowUp] = []
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published var content = ""
    @Published private(set) var evidence: [EvidenceItem] = []
    @Published var errorMessage: String?

    let reportID: String
    private let service: ReportService
    private let submissions: SubmissionService
    private let pageSize = 20
    private var page = 1
    private var pendingRequestID: String?
    private var pendingContent: String?

    init(reportID: String, service: ReportService, submissions: SubmissionService) {
        self.reportID = reportID
        self.service = service
        self.submissions = submissions
    }

    var hasMore: Bool { page * pageSize < total }

    var remainingEvidenceSlots: Int { max(0, 3 - evidence.count) }

    var isUploadingEvidence: Bool { evidence.contains { $0.isUploading } }

    func load(page target: Int = 1) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.followUps(reportID: reportID, page: max(1, target), size: pageSize)
            items = target <= 1 ? Array(result.items.reversed()) : Array(result.items.reversed()) + items
            total = result.total
            page = max(1, target)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        await load(page: page + 1)
    }

    func addEvidence(_ images: [UIImage]) async {
        guard !isSending else { return }
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
        await uploadPendingEvidence()
    }

    func removeEvidence(id: UUID) {
        guard !isSending else { return }
        evidence.removeAll { $0.id == id }
    }

    func send() async {
        guard !isSending else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请填写追问内容"
            return
        }
        guard trimmed.count <= 500 else {
            errorMessage = "追问不能超过 500 字"
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

        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let created = try await service.addFollowUp(
                reportID: reportID,
                content: trimmed,
                evidenceURLs: evidence.compactMap(\.url),
                requestID: requestID
            )
            items.append(created)
            total += 1
            content = ""
            evidence = []
            pendingRequestID = nil
            pendingContent = nil
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
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
