import SwiftUI
import UIKit

@MainActor
struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ChatViewModel
    @State private var confirmHide = false
    private let onRead: (() -> Void)?

    init(
        conversationID: String,
        messages: MessageService,
        social: SocialService,
        currentUserID: String,
        onRead: (() -> Void)? = nil
    ) {
        _model = StateObject(
            wrappedValue: ChatViewModel(
                conversationID: conversationID,
                service: messages,
                social: social,
                currentUserID: currentUserID
            )
        )
        self.onRead = onRead
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            VStack(spacing: 0) {
                if let info = model.infoMessage, !info.isEmpty {
                    Text(info)
                        .font(.footnote)
                        .foregroundStyle(Zine.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Zine.pagePadding)
                        .padding(.top, 8)
                }
                messageList
                if let error = model.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Zine.red)
                        .padding(.horizontal, Zine.pagePadding)
                        .padding(.bottom, 6)
                }
            }
        }
        .navigationTitle(model.peerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(model.blockedByMe ? "解除拉黑" : "拉黑用户") {
                        Task { await model.toggleBlock() }
                    }
                    Button("刷新") {
                        Task { await model.load() }
                    }
                    Button("删除会话", role: .destructive) {
                        confirmHide = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("私信管理")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            composerArea
        }
        .task {
            await model.load()
            if model.conversation != nil {
                onRead?()
            }
        }
        .alert("删除会话？", isPresented: $confirmHide) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    if await model.hideConversation() {
                        onRead?()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("只隐藏你这一侧的会话；对方再发消息会重新出现。")
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if model.hasMore {
                        Button("加载更早的消息") {
                            Task { await model.loadOlder() }
                        }
                        .buttonStyle(InkButtonStyle())
                        .disabled(model.isLoadingOlder)
                    }
                    if model.isLoading && model.messages.isEmpty {
                        LoadingStateView(message: "正在读取私信…")
                    } else if model.messages.isEmpty {
                        EmptyStateView(title: "还没有消息", message: "发一句问候开始聊天吧。")
                    } else {
                        ForEach(model.messages) { message in
                            bubble(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, Zine.pagePadding)
                .padding(.vertical, 12)
            }
            .onChange(of: model.messages.count) { _, _ in
                guard let last = model.messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func bubble(_ message: DirectMessage) -> some View {
        HStack {
            if model.isMine(message) {
                Spacer(minLength: 44)
            }
            VStack(alignment: model.isMine(message) ? .trailing : .leading, spacing: 3) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(Zine.ink)
                    .multilineTextAlignment(model.isMine(message) ? .trailing : .leading)
                    .textSelection(.enabled)
                Text(DisplayFormat.dateTime(message.createdAt))
                    .font(.system(size: 10))
                    .foregroundStyle(Zine.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(model.isMine(message) ? Zine.red.opacity(0.14) : Zine.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(model.isMine(message) ? Zine.red.opacity(0.55) : Zine.border, lineWidth: 1)
            )
            .contextMenu {
                Button("复制") {
                    UIPasteboard.general.string = message.content
                }
            }
            if !model.isMine(message) {
                Spacer(minLength: 44)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var composerArea: some View {
        if model.blockedByMe {
            PaperCard {
                HStack(spacing: 12) {
                    Text("已拉黑该用户，解除后可继续发送。")
                        .font(.subheadline)
                        .foregroundStyle(Zine.muted)
                    Spacer(minLength: 8)
                    Button("解除拉黑") {
                        Task { await model.toggleBlock() }
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
            .padding(.horizontal, Zine.pagePadding)
            .padding(.bottom, 8)
            .background(Zine.bar)
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("说点什么…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.never)
                    .modifier(FormInputStyle())
                Button {
                    Task { await model.send() }
                } label: {
                    if model.isSending {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("发送")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .frame(width: 82)
                .disabled(model.isSending)
            }
            .padding(.horizontal, Zine.pagePadding)
            .padding(.vertical, 8)
            .background(Zine.bar)
        }
    }
}
