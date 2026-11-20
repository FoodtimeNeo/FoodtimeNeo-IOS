import Foundation
import UIKit

@MainActor
final class CorrectionFormViewModel: ObservableObject {
    struct EvidenceItem: Identifiable {
        let id: UUID
        let image: UIImage
        var url: String?
        var isUploading: Bool
    }

    let dishID: String
    let dishName: String
    let baseRevision: Int

    @Published var fixName = false
    @Published var fixDescription = false
    @Published var fixPrice = false
    @Published var fixPriceUnit = false
    @Published var name: String
    @Published var descriptionText: String
    @Published var priceText: String
    @Published var priceUnit: String
    @Published var reason = ""
    @Published private(set) var evidence: [EvidenceItem] = []
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var receipt: CatalogCorrection?

    private let corrections: CorrectionService
    private let submissions: SubmissionService
    private var idempotencyKey = UUID().uuidString
    private var lastFingerprint: String?

    init(
        dish: DishDetail,
        corrections: CorrectionService,
        submissions: SubmissionService
    ) {
        self.dishID = dish.id
        self.dishName = dish.name
        self.baseRevision = dish.revision
        self.corrections = corrections
        self.submissions = submissions
        self.name = dish.name
        self.descriptionText = dish.description ?? ""
        self.priceText = dish.price.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        self.priceUnit = dish.priceUnit ?? "unspecified"
    }

    var remainingEvidenceSlots: Int {
        max(0, 3 - evidence.count)
    }

    var isUploadingEvidence: Bool {
        evidence.contains { $0.isUploading }
    }

    var canInteract: Bool {
        baseRevision > 0 && !isSubmitting
    }

    func addEvidence(_ images: [UIImage]) async {
        guard !isSubmitting else { return }
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
        guard !isSubmitting else { return }
        evidence.removeAll { $0.id == id }
    }

    func submit() async {
        guard !isSubmitting, baseRevision > 0 else { return }
        errorMessage = nil

        var fields: [String] = []
        if fixName { fields.append("name") }
        if fixDescription { fields.append("description") }
        if fixPrice { fields.append("price") }
        if fixPriceUnit { fields.append("priceUnit") }
        guard !fields.isEmpty else {
            errorMessage = "请至少勾选一个要更正的字段"
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if fixName {
            guard !trimmedName.isEmpty else {
                errorMessage = "更正后的名称不能为空"
                return
            }
            guard trimmedName.count <= 120 else {
                errorMessage = "名称不能超过 120 字"
                return
            }
        }
        if fixDescription, descriptionText.count > 500 {
            errorMessage = "介绍不能超过 500 字"
            return
        }

        var parsedPrice: Decimal?
        if fixPrice {
            let raw = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            if !raw.isEmpty {
                guard let value = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")),
                      value >= 0 else {
                    errorMessage = "价格必须为非负数"
                    return
                }
                parsedPrice = value
            }
        }
        if fixPriceUnit, !CorrectionPriceUnits.values.contains(priceUnit) {
            errorMessage = "请选择有效的计价单位"
            return
        }

        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else {
            errorMessage = "请填写更正理由"
            return
        }
        guard trimmedReason.count <= 500 else {
            errorMessage = "更正理由不能超过 500 字"
            return
        }

        if evidence.contains(where: { $0.url == nil }) {
            await uploadPendingEvidence()
        }
        guard !evidence.contains(where: { $0.url == nil }) else {
            errorMessage = "证据图片上传失败，请重试"
            return
        }

        let proposal = CorrectionProposal(
            targetType: "dish",
            targetId: dishID,
            baseRevision: baseRevision,
            changedFields: fields,
            name: fixName ? trimmedName : nil,
            description: fixDescription
                ? (descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : descriptionText)
                : nil,
            price: fixPrice ? parsedPrice : nil,
            priceUnit: fixPriceUnit ? priceUnit : nil,
            reason: trimmedReason,
            evidenceUrls: evidence.compactMap(\.url),
            idempotencyKey: idempotencyKey
        )
        if lastFingerprint != proposal.fingerprint {
            idempotencyKey = UUID().uuidString
            lastFingerprint = proposal.fingerprint
        }
        let request = CorrectionProposal(
            targetType: proposal.targetType,
            targetId: proposal.targetId,
            baseRevision: proposal.baseRevision,
            changedFields: proposal.changedFields,
            name: proposal.name,
            description: proposal.description,
            price: proposal.price,
            priceUnit: proposal.priceUnit,
            reason: proposal.reason,
            evidenceUrls: proposal.evidenceUrls,
            idempotencyKey: idempotencyKey
        )

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            receipt = try await corrections.submit(request)
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
