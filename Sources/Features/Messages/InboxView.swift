import SwiftUI

@MainActor
struct InboxView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: InboxViewModel
    @State private var readingNotice: Notice?
    @State private var detailMessage: InboxMessage?
    @State private var communityPostID: String?

    init(inbox: InboxService, messages: MessageService) {
        _model = StateObject(wrappedValue: InboxViewModel(inbox: inbox, messages: messages))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "04",
                        title: "通知信箱",
                        subtitle: "公告与系统消息都在这里，点开即标为已读。"
                    )
                    .padding(.horizontal, Zine.pagePadding)

                    Picker("分类", selection: $model.segment) {
                        ForEach(InboxViewModel.Segment.allCases) { segment in
                            Text(segmentTitle(segment)).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Zine.pagePadding)
                    .onChange(of: model.segment) { _, value in
                        Task { await model.switchSegment(value) }
                    }

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            content
                            if model.canLoadMore {
                                Button("加载更多") {
                                    Task { await model.loadMore() }
                                }
                                .buttonStyle(InkButtonStyle())
                                .disabled(model.isLoadingMore)
                            }
                        }
                        .padding(.horizontal, Zine.pagePadding)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        await model.load(reset: true)
                        await model.loadCounts()
                    }

                    if let error = model.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Zine.red)
                            .padding(.horizontal, Zine.pagePadding)
                    }
                }
            }
            .navigationTitle("消息信箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await model.loadCounts()
                await model.load(reset: true)
            }
            .sheet(item: $readingNotice) { notice in
                NoticeReaderView(notice: notice)
            }
            .sheet(item: $detailMessage) { message in
                MessageDetailView(message: message)
            }
            .navigationDestination(item: $communityPostID) { postID in
                CommunityDetailView(postID: postID, service: session.community)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && isEmpty {
            LoadingStateView(message: "正在翻信箱…")
        } else if let error = model.errorMessage, isEmpty {
            ErrorStateView(message: error) {
                Task { await model.load(reset: true) }
            }
        } else {
            switch model.segment {
            case .notices:
                noticesContent
            case .messages:
                messagesContent
            case .chats:
                chatsContent
            }
        }
    }

    private var isEmpty: Bool {
        switch model.segment {
        case .notices: return model.notices.isEmpty
        case .messages: return model.messages.isEmpty
        case .chats: return model.conversations.isEmpty
        }
    }

    private func segmentTitle(_ segment: InboxViewModel.Segment) -> String {
        switch segment {
        case .notices:
            return model.noticeUnread > 0 ? "公告 \(model.noticeUnread)" : "公告"
        case .messages:
            return model.messageUnread > 0 ? "系统消息 \(model.messageUnread)" : "系统消息"
        case .chats:
            return model.chatUnread > 0 ? "私信 \(model.chatUnread)" : "私信"
        }
    }

    @ViewBuilder
    private var noticesContent: some View {
        if model.notices.isEmpty {
            EmptyStateView(title: "暂无公告", message: "有新的全员通知时，会第一时间送到这里。")
        } else {
            ForEach(model.notices) { notice in
                Button {
                    readingNotice = notice
                    Task { await model.openNotice(notice) }
                } label: {
                    noticeCard(notice)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func noticeCard(_ notice: Notice) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(notice.isUpdate ? "更新公告" : "系统公告")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                if let content = notice.content, !content.isEmpty {
                    markdownText(content)
                        .font(.subheadline)
                        .foregroundStyle(Zine.muted)
                        .lineLimit(6)
                }
                Text(DisplayFormat.dateTime(notice.publishedAt))
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("查看全文")
    }

    @ViewBuilder
    private var messagesContent: some View {
        if model.messages.isEmpty {
            EmptyStateView(
                title: model.isLoading ? "正在读取系统消息…" : "暂无系统消息",
                message: "审核结果、点赞与评论提醒会出现在这里。"
            )
        } else {
            HStack {
                Text("共 \(model.messageTotal) 条")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                Spacer()
                Button("全部标为已读") {
                    Task { await model.markAllMessagesRead() }
                }
                .buttonStyle(LinkButtonStyle())
                .disabled(model.messageUnread == 0)
            }
            ForEach(model.messages) { message in
                Button {
                    open(message)
                } label: {
                    messageCard(message)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func open(_ message: InboxMessage) {
        if message.opensCommunityPost, let id = message.refId {
            communityPostID = id
        } else {
            detailMessage = message
        }
        Task { await model.openMessage(message) }
    }

    private func messageCard(_ message: InboxMessage) -> some View {
        PaperCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: messageIcon(message))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(messageTint(message))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(messageTint(message).opacity(0.12)))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(message.title)
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(message.isRead ? Zine.muted : Zine.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !message.isRead {
                            Circle().fill(Zine.red).frame(width: 7, height: 7)
                        }
                    }
                    if let body = message.body, !body.isEmpty {
                        Text(body)
                            .font(.subheadline)
                            .foregroundStyle(Zine.ink)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    HStack {
                        Text(messageCategoryLabel(message))
                            .font(.caption2)
                            .foregroundStyle(Zine.muted)
                        Spacer()
                        if message.actorCount > 1 {
                            Text("\(message.actorCount)人")
                                .font(.caption2)
                                .foregroundStyle(Zine.red)
                        }
                        Text(DisplayFormat.dateTime(message.createdAt))
                            .font(.caption2)
                            .foregroundStyle(Zine.muted)
                    }
                    if message.opensCommunityPost {
                        Text("查看原帖")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Zine.red)
                            .padding(.top, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(message.isRead ? Color.clear : Zine.alt.opacity(0.4))
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(message.isRead ? "已读" : "未读"))
    }

    @ViewBuilder
    private var chatsContent: some View {
        if model.conversations.isEmpty {
            EmptyStateView(
                title: "还没有私信",
                message: "在社区食记或关注列表找到同学，点击「私信」开始聊天。"
            )
        } else {
            ForEach(model.conversations) { conversation in
                NavigationLink {
                    ChatView(
                        conversationID: conversation.id,
                        messages: session.messages,
                        social: session.social,
                        currentUserID: session.user?.id ?? "",
                        onRead: { model.handleConversationOpened(conversation.id) }
                    )
                } label: {
                    conversationCard(conversation)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func conversationCard(_ conversation: Conversation) -> some View {
        PaperCard(padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Zine.alt)
                    Text(conversation.other.displayName.isEmpty ? "饭" : String(conversation.other.displayName.prefix(1)))
                        .font(.system(size: 17, weight: .black, design: .serif))
                        .foregroundStyle(Zine.red)
                }
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.other.displayName.isEmpty ? "同学" : conversation.other.displayName)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Text(conversation.lastMessage?.isEmpty == false ? conversation.lastMessage! : "还没有消息")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if conversation.unreadCount > 0 {
                    Text(conversation.unreadCount > 99 ? "99+" : String(conversation.unreadCount))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Zine.onRed)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Zine.red))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(conversation.unreadCount > 0 ? Zine.alt.opacity(0.45) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            Text(
                conversation.unreadCount > 0
                    ? "\(conversation.unreadCount) 条未读"
                    : "已读"
            )
        )
    }

    private func markdownText(_ raw: String) -> Text {
        if let attributed = try? AttributedString(markdown: raw) {
            return Text(attributed)
        }
        return Text(raw)
    }

    private func messageIcon(_ message: InboxMessage) -> String {
        switch message.category ?? "" {
        case "LIKE_POST", "LIKE_COMMENT": return "heart.fill"
        case "COMMENT_POST": return "text.bubble.fill"
        case "REPLY_COMMENT": return "arrowshape.turn.up.left.fill"
        default: return "bell.fill"
        }
    }

    private func messageTint(_ message: InboxMessage) -> Color {
        switch message.category ?? "" {
        case "LIKE_POST", "LIKE_COMMENT": return Zine.red
        case "COMMENT_POST": return Zine.blue
        case "REPLY_COMMENT": return Zine.green
        default: return Zine.gold
        }
    }

    private func messageCategoryLabel(_ message: InboxMessage) -> String {
        switch message.category ?? "" {
        case "LIKE_POST": return "食记点赞"
        case "LIKE_COMMENT": return "评论点赞"
        case "COMMENT_POST": return "食记评论"
        case "REPLY_COMMENT": return "评论回复"
        default:
            let category = message.category ?? ""
            return category.isEmpty ? "系统消息" : category
        }
    }
}

@MainActor
private struct NoticeReaderView: View {
    @Environment(\.dismiss) private var dismiss
    let notice: Notice

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(notice.isUpdate ? "更新公告" : "系统公告")
                            .font(Zine.sectionFont)
                            .foregroundStyle(Zine.ink)
                        Text(DisplayFormat.dateTime(notice.publishedAt))
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                        MarkdownBody(text: notice.content ?? "")
                    }
                    .padding(Zine.pagePadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("全文")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

@MainActor
private struct MessageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let message: InboxMessage

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(message.title)
                            .font(Zine.sectionFont)
                            .foregroundStyle(Zine.ink)
                        Text(DisplayFormat.dateTime(message.createdAt))
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                        Text(message.body?.isEmpty == false ? message.body! : "（正文为空）")
                            .font(Zine.bodyFont)
                            .foregroundStyle(Zine.ink)
                            .textSelection(.enabled)
                    }
                    .padding(Zine.pagePadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("消息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct MarkdownBody: View {
    let text: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: text) {
            Text(attributed)
                .font(Zine.bodyFont)
                .foregroundStyle(Zine.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(text)
                .font(Zine.bodyFont)
                .foregroundStyle(Zine.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
