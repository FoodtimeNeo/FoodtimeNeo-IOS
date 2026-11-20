import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var conversation: Conversation?
    @Published private(set) var messages: [DirectMessage] = []
    @Published var draft = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var isSending = false
    @Published private(set) var blockedByMe = false
    @Published private(set) var hasMore = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    let conversationID: String
    private let service: MessageService
    private let social: SocialService
    private let currentUserID: String
    private var nextCursor: String?
    private var pendingSend: (requestID: String, content: String)?

    init(
        conversationID: String,
        service: MessageService,
        social: SocialService,
        currentUserID: String
    ) {
        self.conversationID = conversationID
        self.service = service
        self.social = social
        self.currentUserID = currentUserID
    }

    var peerName: String {
        let name = conversation?.other.displayName ?? ""
        return name.isEmpty ? "同学" : name
    }

    func isMine(_ message: DirectMessage) -> Bool {
        message.senderId == currentUserID
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let detail = service.conversation(id: conversationID)
            async let page = service.messages(conversationID: conversationID, size: 30, cursor: nil)
            let (loadedConversation, loadedPage) = try await (detail, page)
            conversation = loadedConversation
            messages = loadedPage.items.sorted(by: precedes)
            nextCursor = loadedPage.nextCursor
            hasMore = loadedPage.hasMore
            blockedByMe = (try? await social.blockState(userID: loadedConversation.other.id))?.blocked ?? false
            if loadedConversation.unreadCount > 0 {
                try? await service.markRead(conversationID: conversationID)
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadOlder() async {
        guard hasMore, !isLoadingOlder, let cursor = nextCursor, !cursor.isEmpty else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await service.messages(
                conversationID: conversationID,
                size: 30,
                cursor: cursor
            )
            var seen = Set(messages.map(\.id))
            for message in page.items where seen.insert(message.id).inserted {
                messages.append(message)
            }
            messages.sort(by: precedes)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send() async {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            errorMessage = "消息不能为空"
            return
        }
        guard content.count <= 1000 else {
            errorMessage = "消息不能超过1000字"
            return
        }
        guard !isSending, !blockedByMe else { return }
        isSending = true
        errorMessage = nil
        let requestID: String
        if let pendingSend, pendingSend.content == content {
            requestID = pendingSend.requestID
        } else {
            requestID = UUID().uuidString
        }
        pendingSend = (requestID, content)
        defer { isSending = false }
        do {
            let message = try await service.send(
                conversationID: conversationID,
                content: content,
                requestID: requestID
            )
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
                messages.sort(by: precedes)
            }
            pendingSend = nil
            draft = ""
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleBlock() async {
        guard let peer = conversation?.other else { return }
        errorMessage = nil
        infoMessage = nil
        do {
            let state = blockedByMe
                ? try await social.unblock(userID: peer.id)
                : try await social.block(userID: peer.id)
            blockedByMe = state.blocked
            infoMessage = state.blocked ? "已拉黑对方；解除后可继续发送。" : "已解除拉黑。"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func hideConversation() async -> Bool {
        errorMessage = nil
        do {
            try await service.hide(conversationID: conversationID)
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func precedes(_ lhs: DirectMessage, _ rhs: DirectMessage) -> Bool {
        let left = lhs.createdAt ?? .distantPast
        let right = rhs.createdAt ?? .distantPast
        if left == right {
            return lhs.id < rhs.id
        }
        return left < right
    }
}
