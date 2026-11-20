import Foundation
import SwiftUI

@MainActor
struct CommunityModerationView: View {
    @StateObject private var model: CommunityModerationViewModel
    @State private var selected: ModerationItem?
    private let service: AdminService

    init(service: AdminService) {
        self.service = service
        _model = StateObject(wrappedValue: CommunityModerationViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "08.3",
                        title: "社区审核",
                        subtitle: "帖子与评论独立队列；仅 pending 可审，帖子审核带内容修订号。"
                    )
                    Picker("类型", selection: $model.kind) {
                        ForEach(CommunityModerationViewModel.Kind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("状态", selection: $model.status) {
                        Text("待审核").tag("pending")
                        Text("已通过").tag("approved")
                        Text("已驳回").tag("rejected")
                    }
                    .pickerStyle(.segmented)

                    if let info = model.infoMessage, !info.isEmpty {
                        Text(info)
                            .font(.footnote)
                            .foregroundStyle(Zine.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let error = model.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Zine.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if model.isLoading && model.items.isEmpty {
                        LoadingStateView(message: "正在读取社区审核队列…")
                    } else if model.items.isEmpty {
                        EmptyStateView(title: "队列为空", message: nil)
                    } else {
                        ForEach(model.items) { item in
                            itemCard(item)
                        }
                        if model.totalPages > 1 {
                            HStack {
                                Button("上一页") {
                                    Task { await model.load(page: model.page - 1) }
                                }
                                .buttonStyle(InkButtonStyle())
                                .disabled(model.page <= 1 || model.isLoading)
                                Text("第 \(model.page)/\(model.totalPages) 页")
                                    .font(.footnote)
                                    .foregroundStyle(Zine.muted)
                                Button("下一页") {
                                    Task { await model.load(page: model.page + 1) }
                                }
                                .buttonStyle(InkButtonStyle())
                                .disabled(model.page >= model.totalPages || model.isLoading)
                            }
                        }
                    }
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("社区审核")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(page: 1) }
        .sheet(item: $selected) { item in
            CommunityModerationDetailView(
                service: service,
                kind: model.kind,
                item: item
            ) { message in
                model.moderationSucceeded(message)
            }
        }
    }

    private func itemCard(_ item: ModerationItem) -> some View {
        Button {
            selected = item
        } label: {
            PaperCard {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(item.name.isEmpty ? Self.typeLabel(item.type) : item.name)
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(Zine.ink)
                            .lineLimit(1)
                        Spacer()
                        Text(statusLabel(item.status))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Zine.alt))
                            .foregroundStyle(item.status == "pending" ? Zine.gold : Zine.muted)
                    }
                    Text("\(Self.typeLabel(item.type)) · \(item.userDisplayName)")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                    if !item.content.isEmpty {
                        Text(item.content)
                            .font(.subheadline)
                            .foregroundStyle(Zine.ink)
                            .lineLimit(4)
                    }
                    if let reason = item.reason, !reason.isEmpty {
                        Text("审核原因：\(reason)")
                            .font(.caption)
                            .foregroundStyle(Zine.red)
                    }
                    HStack(spacing: 10) {
                        if let risk = item.aiRiskLevel {
                            Text("AI：\(risk)\(item.aiConfidence.map { String(format: " %.0f%%", $0 * 100) } ?? "")")
                                .font(.caption2)
                                .foregroundStyle(Zine.blue)
                        }
                        if let revision = item.contentRevision {
                            Text("修订 \(revision)")
                                .font(.caption2)
                                .foregroundStyle(Zine.muted)
                        }
                        Spacer()
                        Text(DisplayFormat.dateTime(item.createdAt))
                            .font(.caption2)
                            .foregroundStyle(Zine.muted)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Zine.muted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private static func typeLabel(_ type: String) -> String {
        switch type {
        case "community-post": return "食记"
        case "community-comment": return "评论"
        case "dish-review-reply": return "点评回复"
        default: return type
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "pending": return "待审核"
        case "approved": return "已通过"
        case "rejected": return "已驳回"
        default: return status
        }
    }
}

@MainActor
private struct CommunityModerationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: CommunityModerationDetailViewModel
    @State private var action = "approve"
    @State private var reason = ""
    @State private var confirmDelete = false
    let onChanged: (String) -> Void

    init(
        service: AdminService,
        kind: CommunityModerationViewModel.Kind,
        item: ModerationItem,
        onChanged: @escaping (String) -> Void
    ) {
        _model = StateObject(
            wrappedValue: CommunityModerationDetailViewModel(
                service: service,
                kind: kind,
                item: item
            )
        )
        self.onChanged = onChanged
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "08.3",
                            title: "审核详情",
                            subtitle: "删除不可恢复；通过/驳回只处理 pending，冲突以服务端为准。"
                        )
                        if model.isLoading && model.detail == nil {
                            LoadingStateView(message: "正在读取详情…")
                        } else {
                            contentCard
                            if model.detail != nil {
                                decisionCard
                            }
                        }
                        if let error = model.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("审核详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                if model.detail == nil {
                    await model.load()
                }
            }
            .alert("删除该内容？", isPresented: $confirmDelete) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task {
                        if await model.delete() {
                            onChanged("已删除。")
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("服务端软删除并保留操作者与删除时间，客户端不能撤销。")
            }
        }
    }

    private var contentCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                if let post = model.detail?.post {
                    Text(post.title.isEmpty ? "（无标题）" : post.title)
                        .font(.system(size: 19, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Text(post.content)
                        .font(Zine.bodyFont)
                        .foregroundStyle(Zine.ink)
                    Text("作者：\(post.userDisplayName)")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                    if let email = model.detail?.userEmail, !email.isEmpty {
                        Text("邮箱：\(email)")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    }
                    Text("图片 \(post.images.count) 张 · 点赞 \(post.likeCount) · 评论 \(post.commentCount) · 浏览 \(post.viewCount)")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                    if let reason = post.reviewReason, !reason.isEmpty {
                        Text("审核原因：\(reason)")
                            .font(.caption)
                            .foregroundStyle(Zine.red)
                    }
                    Text("状态：\(post.status) · 修订 \(post.contentRevision) · 发布 \(DisplayFormat.dateTime(post.createdAt))")
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                } else if let comment = model.detail?.comment {
                    Text(comment.content)
                        .font(Zine.bodyFont)
                        .foregroundStyle(Zine.ink)
                    Text("作者：\(comment.userDisplayName)")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                    if let email = model.detail?.userEmail, !email.isEmpty {
                        Text("邮箱：\(email)")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    }
                    if let root = model.detail?.rootComment, root.id != comment.id {
                        contextRow("根评论", root)
                    }
                    if let replyTo = model.detail?.replyToComment {
                        contextRow("回复对象", replyTo)
                    }
                    Text("状态：\(comment.status) · 点赞 \(comment.likeCount) · 发布 \(DisplayFormat.dateTime(comment.createdAt))")
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                } else {
                    Text(model.item.content)
                        .font(Zine.bodyFont)
                        .foregroundStyle(Zine.ink)
                    Text("作者：\(model.item.userDisplayName)")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                if let risk = model.item.aiRiskLevel {
                    Text("AI 风险：\(risk)\(model.item.aiConfidence.map { String(format: " %.0f%%", $0 * 100) } ?? "")")
                        .font(.caption)
                        .foregroundStyle(Zine.blue)
                }
            }
        }
    }

    private func contextRow(_ label: String, _ comment: CommunityComment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label)：\(comment.userDisplayName)")
                .font(.caption2)
                .foregroundStyle(Zine.muted)
            Text(comment.content)
                .font(.caption)
                .foregroundStyle(Zine.ink)
                .lineLimit(3)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.alt))
    }

    private var decisionCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                if model.item.status == "pending" {
                    Picker("决定", selection: $action) {
                        Text("通过").tag("approve")
                        Text("驳回").tag("reject")
                    }
                    .pickerStyle(.segmented)
                    Text("原因/说明")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                    TextEditor(text: $reason)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Zine.smallRadius)
                                .stroke(Zine.border, lineWidth: 1)
                        )
                    Button {
                        Task { await submit() }
                    } label: {
                        if model.isSubmitting {
                            ProgressView().tint(Zine.onRed)
                        } else {
                            Text(action == "approve" ? "确认通过" : "确认驳回")
                        }
                    }
                    .buttonStyle(InkButtonStyle(primary: true))
                    .disabled(model.isSubmitting)
                } else {
                    Text("该内容已被审核，不能再执行通过/驳回。")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                }
                Button("删除\(model.kindTitle)") {
                    confirmDelete = true
                }
                .buttonStyle(InkButtonStyle())
                .foregroundStyle(Zine.red)
                .disabled(model.isSubmitting)
            }
        }
    }

    private func submit() async {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if await model.moderate(action: action, reason: trimmed.isEmpty ? nil : trimmed) {
            onChanged(action == "approve" ? "已通过。" : "已驳回。")
            dismiss()
        }
    }
}

private extension CommunityModerationDetailViewModel {
    var kindTitle: String {
        // `kind` is private in the view model; the item type carries the same
        // information and stays correct if the caller switches tabs.
        item.type == "community-comment" ? "评论" : "食记"
    }
}
