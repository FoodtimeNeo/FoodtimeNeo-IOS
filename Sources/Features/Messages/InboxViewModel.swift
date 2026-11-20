import Foundation

@MainActor
final class InboxViewModel: ObservableObject {
    enum Segment: String, CaseIterable, Identifiable {
        case notices
        case messages
        case chats

        var id: String { rawValue }

        var title: String {
            switch self {
            case .notices: return "公告"
            case .messages: return "系统消息"
            case .chats: return "私信"
            }
        }
    }

    @Published var segment: Segment = .notices
    @Published private(set) var notices: [Notice] = []
    @Published private(set) var messages: [InboxMessage] = []
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var noticeUnread = 0
    @Published private(set) var messageUnread = 0
    @Published private(set) var chatUnread = 0
    @Published private(set) var noticeTotal = 0
    @Published private(set) var messageTotal = 0
    @Published private(set) var chatTotal = 0
    @Published var errorMessage: String?

    private let inbox: InboxService
    private let messagesService: MessageService
    private let pageSize = 20
    private var noticePage = 1
    private var messagePage = 1
    private var chatPage = 1
    private var noticeHasMore = false
    private var messageHasMore = false
    private var chatHasMore = false
    private var generation = 0

    init(inbox: InboxService, messages: MessageService) {
        self.inbox = inbox
        self.messagesService = messages
    }

    var totalUnread: Int {
        noticeUnread + messageUnread + chatUnread
    }

    var canLoadMore: Bool {
        switch segment {
        case .notices: return noticeHasMore
        case .messages: return messageHasMore
        case .chats: return chatHasMore
        }
    }

    func loadCounts() async {
        async let notices = try? await inbox.unreadNoticeCount()
        async let messages = try? await inbox.unreadMessageCount()
        async let chats = try? await messagesService.unreadCount()
        let result = await (notices, messages, chats)
        noticeUnread = result.0 ?? noticeUnread
        messageUnread = result.1 ?? messageUnread
        chatUnread = result.2 ?? chatUnread
    }

    func load(reset: Bool = true) async {
        if reset {
            generation += 1
        }
        let current = generation
        isLoading = true
        errorMessage = nil
        defer {
            if current == generation {
                isLoading = false
            }
        }

        switch segment {
        case .notices:
            await loadNotices(reset: reset, generation: current)
        case .messages:
            await loadMessages(reset: reset, generation: current)
        case .chats:
            await loadConversations(reset: reset, generation: current)
        }
    }

    func switchSegment(_ next: Segment) async {
        segment = next
        await load(reset: true)
    }

    func loadMore() async {
        guard !isLoadingMore else { return }
        switch segment {
        case .notices:
            guard noticeHasMore else { return }
            await loadNotices(reset: false, generation: generation, isMore: true)
        case .messages:
            guard messageHasMore else { return }
            await loadMessages(reset: false, generation: generation, isMore: true)
        case .chats:
            guard chatHasMore else { return }
            await loadConversations(reset: false, generation: generation, isMore: true)
        }
    }

    func openNotice(_ notice: Notice) async {
        errorMessage = nil
        do {
            try await inbox.markNoticeRead(id: notice.id)
            noticeUnread = max(0, noticeUnread - 1)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openMessage(_ message: InboxMessage) async {
        guard !message.isRead else { return }
        do {
            try await inbox.markMessageRead(id: message.id)
            replaceMessage(message.id, read: true)
            messageUnread = max(0, messageUnread - 1)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllMessagesRead() async {
        errorMessage = nil
        do {
            try await inbox.markAllMessagesRead()
            messages = messages.map { read($0) }
            messageUnread = 0
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleConversationOpened(_ conversationID: String) {
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            let current = conversations[index]
            let opened = Conversation(
                id: current.id,
                other: current.other,
                lastMessage: current.lastMessage,
                lastSenderId: current.lastSenderId,
                lastMessageAt: current.lastMessageAt,
                unreadCount: 0,
                updatedAt: current.updatedAt
            )
            conversations[index] = opened
            chatUnread = max(0, chatUnread - current.unreadCount)
        }
    }

    private func loadNotices(reset: Bool, generation: Int, isMore: Bool = false) async {
        if isMore {
            isLoadingMore = true
        }
        defer { isLoadingMore = false }
        let page = reset ? 1 : noticePage + 1
        do {
            let result = try await inbox.notices(page: page, size: pageSize)
            guard generation == self.generation else { return }
            notices = reset ? result.items : merged(notices, result.items, id: \.id)
            noticePage = page
            noticeTotal = result.total
            noticeHasMore = page * pageSize < result.total
        } catch let error as AppError {
            if generation == self.generation { errorMessage = error.localizedDescription }
        } catch {
            if generation == self.generation { errorMessage = error.localizedDescription }
        }
    }

    private func loadMessages(reset: Bool, generation: Int, isMore: Bool = false) async {
        if isMore {
            isLoadingMore = true
        }
        defer { isLoadingMore = false }
        let page = reset ? 1 : messagePage + 1
        do {
            let result = try await inbox.messages(page: page, size: pageSize)
            guard generation == self.generation else { return }
            messages = reset ? result.items : merged(messages, result.items, id: \.id)
            messagePage = page
            messageTotal = result.total
            messageHasMore = page * pageSize < result.total
        } catch let error as AppError {
            if generation == self.generation { errorMessage = error.localizedDescription }
        } catch {
            if generation == self.generation { errorMessage = error.localizedDescription }
        }
    }

    private func loadConversations(reset: Bool, generation: Int, isMore: Bool = false) async {
        if isMore {
            isLoadingMore = true
        }
        defer { isLoadingMore = false }
        let page = reset ? 1 : chatPage + 1
        do {
            let result = try await messagesService.conversations(page: page, size: pageSize)
            guard generation == self.generation else { return }
            conversations = reset ? result.items : merged(conversations, result.items, id: \.id)
            chatPage = page
            chatTotal = result.total
            chatHasMore = page * pageSize < result.total
        } catch let error as AppError {
            if generation == self.generation { errorMessage = error.localizedDescription }
        } catch {
            if generation == self.generation { errorMessage = error.localizedDescription }
        }
    }

    private func merged<T>(_ current: [T], _ next: [T], id: KeyPath<T, String>) -> [T] {
        var seen = Set(current.map { $0[keyPath: id] })
        var result = current
        for item in next where seen.insert(item[keyPath: id]).inserted {
            result.append(item)
        }
        return result
    }

    private func replaceMessage(_ id: String, read: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index] = read ? read(messages[index]) : messages[index]
    }

    private func read(_ message: InboxMessage) -> InboxMessage {
        InboxMessage(
            id: message.id,
            title: message.title,
            body: message.body,
            category: message.category,
            refType: message.refType,
            refId: message.refId,
            refCommentId: message.refCommentId,
            refRootCommentId: message.refRootCommentId,
            actorCount: message.actorCount,
            isRead: true,
            createdAt: message.createdAt
        )
    }
}
