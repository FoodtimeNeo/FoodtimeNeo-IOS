import Foundation
import SwiftUI

@MainActor
struct AdminAppealsView: View {
    @StateObject private var model: AdminAppealsViewModel
    @State private var selected: AdminAppeal?
    private let service: AdminService

    init(service: AdminService) {
        self.service = service
        _model = StateObject(wrappedValue: AdminAppealsViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "08.5",
                        title: "申诉复核",
                        subtitle: "开始复核与结束复核都带修订号；冲突以服务端为准。"
                    )
                    Picker("状态", selection: $model.status) {
                        Text("全部").tag("")
                        Text("已提交").tag(AdminAppealStatus.submitted)
                        Text("复核中").tag(AdminAppealStatus.underReview)
                        Text("已结束").tag(AdminAppealStatus.resolved)
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

                    if model.isLoading && model.appeals.isEmpty {
                        LoadingStateView(message: "正在读取申诉…")
                    } else if model.appeals.isEmpty {
                        EmptyStateView(title: "没有申诉", message: nil)
                    } else {
                        ForEach(model.appeals) { appeal in
                            Button {
                                selected = appeal
                            } label: {
                                appealCard(appeal)
                            }
                            .buttonStyle(.plain)
                        }
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
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("申诉复核")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(page: 1) }
        .sheet(item: $selected) { appeal in
            AdminAppealDetailView(service: service, appeal: appeal) { message in
                model.changed(message)
            }
        }
    }

    private func appealCard(_ appeal: AdminAppeal) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(appeal.appellantName)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(AdminAppealStatus.label(appeal.status))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Zine.alt))
                        .foregroundStyle(appeal.status == AdminAppealStatus.resolved ? Zine.muted : Zine.gold)
                }
                Text(appeal.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                    .lineLimit(4)
                if let outcome = appeal.outcome {
                    Text("结论：\(outcome == "upheld" ? "成立" : "不成立") · \(appeal.publicReason ?? "")")
                        .font(.caption)
                        .foregroundStyle(Zine.red)
                }
                Text("修订 \(appeal.revision) · \(DisplayFormat.dateTime(appeal.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
            }
        }
    }
}

@MainActor
private struct AdminAppealDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AdminAppealDetailViewModel
    @State private var outcome = "upheld"
    @State private var publicReason = ""
    @State private var internalNote = ""
    let onChanged: (String) -> Void

    init(
        service: AdminService,
        appeal: AdminAppeal,
        onChanged: @escaping (String) -> Void
    ) {
        _model = StateObject(
            wrappedValue: AdminAppealDetailViewModel(service: service, appeal: appeal)
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
                            index: "08.5",
                            title: "申诉详情",
                            subtitle: "内部备注与证据仅管理员可见；结束后通知双方。"
                        )
                        if model.isLoading {
                            LoadingStateView(message: "正在读取申诉…")
                        }
                        appealCard
                        if let error = model.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        actionCard
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("申诉详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.load() }
        }
    }

    private var appealCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(model.appeal.appellantName)
                        .font(.system(size: 19, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(AdminAppealStatus.label(model.appeal.status))
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                }
                Text(model.appeal.content)
                    .font(Zine.bodyFont)
                    .foregroundStyle(Zine.ink)
                    .textSelection(.enabled)
                if let side = model.appeal.side {
                    Text("申诉方：\(side)")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                if let note = model.appeal.internalNote, !note.isEmpty {
                    Text("内部备注：\(note)")
                        .font(.caption)
                        .foregroundStyle(Zine.blue)
                }
                if !model.appeal.evidenceUrls.isEmpty {
                    Text("证据：\(model.appeal.evidenceUrls.joined(separator: "、"))")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                if let outcome = model.appeal.outcome {
                    Text("结论：\(outcome == "upheld" ? "成立" : "不成立")")
                        .font(.caption)
                        .foregroundStyle(Zine.red)
                    Text("公开理由：\(model.appeal.publicReason ?? "")")
                        .font(.caption)
                        .foregroundStyle(Zine.ink)
                }
                Text("申诉 \(model.appeal.id) · 决定 \(model.appeal.decisionId) · 修订 \(model.appeal.revision)")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
                Text("提交：\(DisplayFormat.dateTime(model.appeal.createdAt)) · 结束：\(DisplayFormat.dateTime(model.appeal.resolvedAt))")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    @ViewBuilder
    private var actionCard: some View {
        if model.appeal.status == AdminAppealStatus.submitted {
            PaperCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("开始复核")
                        .font(.system(size: 19, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Text("状态将从 submitted 变为 under_review，并占用当前修订号 \(model.appeal.revision)。")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                    Button("开始复核") {
                        Task {
                            if await model.start() {
                                onChanged("已开始复核。")
                            }
                        }
                    }
                    .buttonStyle(InkButtonStyle(primary: true))
                    .disabled(model.isSubmitting)
                }
            }
        } else if model.appeal.status == AdminAppealStatus.underReview {
            PaperCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("结束复核")
                        .font(.system(size: 19, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Picker("结论", selection: $outcome) {
                        Text("成立").tag("upheld")
                        Text("不成立").tag("rejected")
                    }
                    .pickerStyle(.segmented)
                    Text("公开理由（必填，≤500）")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
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
                    TextField("内部备注（可选，≤2000）", text: $internalNote, axis: .vertical)
                        .lineLimit(2...4)
                        .modifier(FormInputStyle())
                    Button("提交复核结论") {
                        Task {
                            let note = internalNote.trimmingCharacters(in: .whitespacesAndNewlines)
                            if await model.resolve(
                                outcome: outcome,
                                publicReason: publicReason,
                                internalNote: note.isEmpty ? nil : note
                            ) {
                                onChanged("申诉复核已结束。")
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(InkButtonStyle(primary: true))
                    .disabled(model.isSubmitting)
                }
            }
        } else {
            PaperCard {
                Text("申诉已结束，记录只读。")
                    .font(Zine.bodyFont)
                    .foregroundStyle(Zine.muted)
            }
        }
    }
}
