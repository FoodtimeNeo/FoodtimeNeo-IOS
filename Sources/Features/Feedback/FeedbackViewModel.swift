import Combine
import Foundation

@MainActor
final class FeedbackViewModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case submit
        case records

        var id: String { rawValue }
        var title: String { self == .submit ? "提交反馈" : "我的反馈" }
    }

    @Published var tab: Tab = .submit
    @Published var type: FeedbackType = .function {
        didSet { requestID = UUID().uuidString }
    }
    @Published var content = "" {
        didSet {
            if oldValue != content {
                requestID = UUID().uuidString
            }
        }
    }
    @Published private(set) var requestID = UUID().uuidString
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    @Published var archived = false
    @Published private(set) var items: [Feedback] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published var listError: String?

    private let session: AppSession
    private let pageSize = 20

    init(session: AppSession) {
        self.session = session
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / Double(pageSize))))
    }

    func submit() async {
        guard !isSubmitting else { return }
        if let error = FeedbackValidation.contentError(content) {
            errorMessage = error
            return
        }
        isSubmitting = true
        errorMessage = nil
        infoMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await session.feedback.create(
                type: type,
                content: FeedbackValidation.normalizedContent(content),
                requestID: requestID
            )
            content = ""
            type = .function
            infoMessage = "反馈已提交，感谢你的建议。"
            tab = .records
            archived = false
            await loadRecords(page: 1)
        } catch let error as AppError {
            handleSubmitError(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadRecords(page: Int) async {
        guard !isLoading else { return }
        isLoading = true
        listError = nil
        defer { isLoading = false }
        do {
            let result = try await session.feedback.list(
                archived: archived,
                page: max(1, page),
                size: pageSize
            )
            items = result.items
            self.page = result.page
            total = result.total
        } catch let error as AppError {
            listError = error.localizedDescription
        } catch {
            listError = error.localizedDescription
        }
    }

    private func handleSubmitError(_ error: AppError) {
        switch error {
        case .validation(let fields):
            errorMessage = fields.isEmpty
                ? error.localizedDescription
                : fields.map(\.message).joined(separator: "；")
        default:
            switch error.code {
            case "FEEDBACK_DAILY_LIMIT":
                errorMessage = "今天的反馈额度已用完，请明天（UTC+8 00:00）再试"
            case "FEEDBACK_DEVICE_DAILY_LIMIT":
                errorMessage = "该设备今天的反馈总额度已用完，请明天再试"
            case "FEEDBACK_REQUEST_CONFLICT":
                errorMessage = "请求编号已被用于其他内容，请重新编辑后提交"
            default:
                errorMessage = error.localizedDescription
            }
        }
    }
}

@MainActor
final class FeedbackDetailViewModel: ObservableObject {
    @Published private(set) var feedback: Feedback?
    @Published private(set) var replies: [FeedbackReply] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published var errorMessage: String?

    private let service: FeedbackService
    private let feedbackID: String
    private let pageSize = 20

    init(service: FeedbackService, feedbackID: String) {
        self.service = service
        self.feedbackID = feedbackID
    }

    var hasMoreReplies: Bool {
        page * pageSize < total
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            feedback = try await service.detail(id: feedbackID)
            let replies = try await service.replies(id: feedbackID, page: 1, size: pageSize)
            self.replies = replies.items
            page = replies.page
            total = replies.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreReplies() async {
        guard hasMoreReplies, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let replies = try await service.replies(id: feedbackID, page: page + 1, size: pageSize)
            self.replies.append(contentsOf: replies.items)
            page = replies.page
            total = replies.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
