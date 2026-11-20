import Foundation
import SwiftUI

@MainActor
struct AdminReportsView: View {
    @StateObject private var model: AdminReportsViewModel
    @State private var selected: AdminReportRow?
    private let service: AdminService

    init(service: AdminService) {
        self.service = service
        _model = StateObject(wrappedValue: AdminReportsViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "08.4",
                        title: "举报处理",
                        subtitle: "决定公开理由必填；动作与追问独立记录，服务端逐次校验权限。"
                    )
                    Picker("视图", selection: $model.mode) {
                        ForEach(AdminReportsViewModel.Mode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
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

                    if model.isLoading && model.pending.isEmpty && model.decisions.isEmpty {
                        LoadingStateView(message: "正在读取举报…")
                    } else if model.mode == .pending {
                        pendingList
                    } else {
                        decisionList
                    }
                    pagination
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("举报处理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(page: 1) }
        .sheet(item: $selected) { report in
            AdminReportDetailView(service: service, report: report) { message in
                model.changed(message)
            }
        }
    }

    @ViewBuilder
    private var pendingList: some View {
        if model.pending.isEmpty {
            EmptyStateView(title: "没有待处理举报", message: nil)
        } else {
            ForEach(model.pending) { report in
                Button {
                    selected = report
                } label: {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(targetLabel(report.targetType))
                                    .font(.system(size: 17, weight: .bold, design: .serif))
                                    .foregroundStyle(Zine.ink)
                                Spacer()
                                Text(DisplayFormat.dateTime(report.createdAt))
                                    .font(.caption2)
                                    .foregroundStyle(Zine.muted)
                            }
                            Text("理由：\(report.reason)")
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                            if let excerpt = report.excerpt, !excerpt.isEmpty {
                                Text(excerpt)
                                    .font(.subheadline)
                                    .foregroundStyle(Zine.ink)
                                    .lineLimit(4)
                            }
                            Text(identifierLine(report))
                                .font(.caption2)
                                .foregroundStyle(Zine.muted)
                            HStack {
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(Zine.muted)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var decisionList: some View {
        if model.decisions.isEmpty {
            EmptyStateView(title: "暂无已决定记录", message: nil)
        } else {
            ForEach(model.decisions) { decision in
                PaperCard {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(AdminReportOutcome.label(decision.outcome))
                                .font(.system(size: 17, weight: .bold, design: .serif))
                                .foregroundStyle(
                                    decision.outcome == AdminReportOutcome.upheld
                                        ? Zine.red
                                        : Zine.green
                                )
                            Spacer()
                            Text(targetLabel(decision.targetType))
                                .font(.caption)
                                .foregroundStyle(Zine.muted)
                        }
                        Text("公开理由：\(decision.publicReason)")
                            .font(.subheadline)
                            .foregroundStyle(Zine.ink)
                        Text("举报 \(shortID(decision.reportId)) · 决定 \(shortID(decision.decisionId)) · \(DisplayFormat.dateTime(decision.createdAt))")
                            .font(.caption2)
                            .foregroundStyle(Zine.muted)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pagination: some View {
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

    private func targetLabel(_ type: String) -> String {
        switch type {
        case "community-post": return "食记举报"
        case "community-comment": return "评论举报"
        case "chat-message": return "私信举报"
        case "review": return "点评举报"
        default: return "\(type)举报"
        }
    }

    private func identifierLine(_ report: AdminReportRow) -> String {
        var parts = ["举报 \(shortID(report.id))"]
        if let target = report.targetId { parts.append("目标 \(shortID(target))") }
        if let post = report.postId { parts.append("帖子 \(shortID(post))") }
        return parts.joined(separator: " · ")
    }

    private func shortID(_ value: String) -> String {
        value.count <= 8 ? value : String(value.prefix(8))
    }
}

@MainActor
private struct AdminReportDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AdminReportDetailViewModel
    @State private var outcome = AdminReportOutcome.upheld
    @State private var publicReason = ""
    @State private var internalNote = ""
    @State private var followUpContent = ""
    @State private var followUpNote = ""
    @State private var actionType: AdminReportActionType = .removePost
    @State private var actionTarget = ""
    @State private var actionNote = ""
    let onChanged: (String) -> Void

    init(
        service: AdminService,
        report: AdminReportRow,
        onChanged: @escaping (String) -> Void
    ) {
        _model = StateObject(
            wrappedValue: AdminReportDetailViewModel(service: service, report: report)
        )
        self.onChanged = onChanged
        _actionTarget = State(initialValue: report.targetId ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "08.4",
                            title: "举报详情",
                            subtitle: "决定会通知双方并进入申诉期；删除/停用等动作另行记录。"
                        )
                        reportCard
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
                        decisionCard
                        followUpSection
                        actionSection
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("举报详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                if model.followUps.isEmpty && model.actions.isEmpty {
                    await model.load()
                }
            }
        }
    }

    private var reportCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.report.targetType)
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("理由：\(model.report.reason)")
                    .font(.subheadline)
                    .foregroundStyle(Zine.red)
                if let excerpt = model.report.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(Zine.bodyFont)
                        .foregroundStyle(Zine.ink)
                }
                Text("举报 ID：\(model.report.id)")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
                Text("目标：\(model.report.targetId ?? "-") · 作者：\(model.report.targetUserId ?? "-") · 帖子：\(model.report.postId ?? "-")")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
                Text("时间：\(DisplayFormat.dateTime(model.report.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
                Button("标记为已读") {
                    Task {
                        if await model.markReviewed() {
                            onChanged("已标记为已读。")
                        }
                    }
                }
                .buttonStyle(LinkButtonStyle())
                .disabled(model.isSubmitting)
            }
        }
    }

    private var decisionCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("作出决定")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Picker("结论", selection: $outcome) {
                    Text("成立").tag(AdminReportOutcome.upheld)
                    Text("不成立").tag(AdminReportOutcome.notUpheld)
                }
                .pickerStyle(.segmented)
                fieldLabel("公开理由（必填，≤500）")
                TextEditor(text: $publicReason)
                    .frame(minHeight: 70)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                            .stroke(Zine.border, lineWidth: 1)
                    )
                fieldLabel("内部备注（可选，≤2000）")
                TextField("仅管理员可见", text: $internalNote, axis: .vertical)
                    .lineLimit(2...4)
                    .modifier(FormInputStyle())
                Button("提交决定") {
                    Task {
                        let note = internalNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        if await model.decide(
                            outcome: outcome,
                            publicReason: publicReason,
                            internalNote: note.isEmpty ? nil : note
                        ) {
                            onChanged("已提交举报决定。")
                            dismiss()
                        }
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isSubmitting)
            }
        }
    }

    private var followUpSection: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("追问线程")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                if model.followUps.isEmpty {
                    Text("暂无追问。")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                } else {
                    ForEach(model.followUps) { followUp in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("\(followUp.authorName) · \(followUp.authorRole)")
                                    .font(.caption)
                                    .foregroundStyle(Zine.muted)
                                Spacer()
                                Text(DisplayFormat.dateTime(followUp.createdAt))
                                    .font(.caption2)
                                    .foregroundStyle(Zine.muted)
                            }
                            Text(followUp.content)
                                .font(.subheadline)
                                .foregroundStyle(Zine.ink)
                            if let note = followUp.internalNote, !note.isEmpty {
                                Text("内部：\(note)")
                                    .font(.caption2)
                                    .foregroundStyle(Zine.blue)
                            }
                            if !followUp.evidenceUrls.isEmpty {
                                Text("证据：\(followUp.evidenceUrls.joined(separator: "、"))")
                                    .font(.caption2)
                                    .foregroundStyle(Zine.muted)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.alt)
                        )
                    }
                }
                fieldLabel("管理员追问（必填，≤500）")
                TextEditor(text: $followUpContent)
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                            .stroke(Zine.border, lineWidth: 1)
                    )
                TextField("内部备注（可选）", text: $followUpNote)
                    .modifier(FormInputStyle())
                Button("发送追问") {
                    Task {
                        let note = followUpNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        if await model.addFollowUp(
                            content: followUpContent,
                            internalNote: note.isEmpty ? nil : note
                        ) {
                            followUpContent = ""
                            followUpNote = ""
                        }
                    }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(model.isSubmitting)
            }
        }
    }

    private var actionSection: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("处理动作")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                if model.actions.isEmpty {
                    Text("尚未执行动作。")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                } else {
                    ForEach(model.actions) { action in
                        Text("\(action.actionType) · \(action.targetId ?? "-") · \(action.note ?? "无备注") · \(DisplayFormat.dateTime(action.createdAt))")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Picker("动作", selection: $actionType) {
                    ForEach(AdminReportActionType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .tint(Zine.ink)
                if actionType.requiresTargetID {
                    TextField("目标 ID", text: $actionTarget)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .modifier(FormInputStyle())
                }
                TextField("备注（可选，≤500）", text: $actionNote, axis: .vertical)
                    .lineLimit(2...3)
                    .modifier(FormInputStyle())
                Button("执行动作") {
                    Task {
                        let target = actionTarget.trimmingCharacters(in: .whitespacesAndNewlines)
                        let note = actionNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        if await model.performAction(
                            type: actionType,
                            targetID: actionType.requiresTargetID ? target : nil,
                            note: note.isEmpty ? nil : note
                        ) {
                            actionNote = ""
                        }
                    }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(model.isSubmitting)
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Zine.muted)
    }
}
