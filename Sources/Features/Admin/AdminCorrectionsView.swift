import Foundation
import SwiftUI

@MainActor
struct AdminCorrectionsView: View {
    @StateObject private var model: AdminCorrectionsViewModel
    @State private var selected: AdminCorrectionRow?
    private let service: AdminService

    init(service: AdminService) {
        self.service = service
        _model = StateObject(wrappedValue: AdminCorrectionsViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "08.8",
                        title: "纠错审核",
                        subtitle: "整单通过或拒绝；通过与目录基线同时校验，冲突时不覆盖新资料。"
                    )
                    Picker("状态", selection: $model.status) {
                        Text("待审核").tag("pending")
                        Text("已通过").tag("approved")
                        Text("已拒绝").tag("rejected")
                    }
                    .pickerStyle(.segmented)
                    Picker("类型", selection: $model.targetType) {
                        Text("全部").tag("")
                        ForEach(AdminCorrectionTarget.allCases) { target in
                            Text(target.title).tag(target.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Zine.ink)

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

                    if model.isLoading && model.rows.isEmpty {
                        LoadingStateView(message: "正在读取纠错队列…")
                    } else if model.rows.isEmpty {
                        EmptyStateView(title: "没有纠错提案", message: nil)
                    } else {
                        ForEach(model.rows) { row in
                            Button {
                                selected = row
                            } label: {
                                rowCard(row)
                            }
                            .buttonStyle(.plain)
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
        .navigationTitle("纠错审核")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(page: 1) }
        .sheet(item: $selected) { row in
            AdminCorrectionDetailView(service: service, row: row) { message in
                model.changed(message)
            }
        }
    }

    private func rowCard(_ row: AdminCorrectionRow) -> some View {
        let correction = row.correction
        return PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(correction.targetSummary)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(statusLabel(correction.status))
                        .font(.caption2)
                        .foregroundStyle(correction.status == "pending" ? Zine.gold : Zine.muted)
                }
                Text("理由：\(correction.reason)")
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                    .lineLimit(3)
                Text("修改字段：\(correction.changedFields.joined(separator: "、"))")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                if let submitter = row.submitterName {
                    Text("\(submitter)\(row.submitterEmail.map { " · \($0)" } ?? "")")
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                }
                HStack {
                    Text("提案修订 \(correction.revision) · 基线 \(correction.baseRevision)")
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                }
            }
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "pending": return "待审核"
        case "approved": return "已通过"
        case "rejected": return "已拒绝"
        default: return status
        }
    }
}

@MainActor
private struct AdminCorrectionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AdminCorrectionDetailViewModel
    @State private var decision = "approved"
    @State private var reviewNote = ""
    let onChanged: (String) -> Void

    init(
        service: AdminService,
        row: AdminCorrectionRow,
        onChanged: @escaping (String) -> Void
    ) {
        _model = StateObject(
            wrappedValue: AdminCorrectionDetailViewModel(service: service, row: row)
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
                            index: "08.8",
                            title: "纠错详情",
                            subtitle: "通过会立即应用建议值；拒绝只记录审核说明。"
                        )
                        if model.isLoading {
                            LoadingStateView(message: "正在读取提案…")
                        }
                        comparisonCard
                        if let error = model.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        decisionCard
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("纠错详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.load() }
        }
    }

    private var comparisonCard: some View {
        let correction = model.row.correction
        return PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(correction.targetSummary)
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("类型：\(correction.targetType) · 目标 \(correction.targetId)")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
                Text("提交理由：\(correction.reason)")
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                Text("修改字段：\(correction.changedFields.joined(separator: "、"))")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                if let name = correction.proposedName {
                    compareRow("名称", correction.originalName, name)
                }
                if let description = correction.proposedDescription {
                    compareRow("简介", correction.originalDescription, description)
                }
                if let price = correction.proposedPrice {
                    compareRow(
                        "价格",
                        DisplayFormat.price(correction.originalPrice),
                        DisplayFormat.price(price)
                    )
                }
                if let unit = correction.proposedPriceUnit {
                    compareRow("计价单位", correction.originalPriceUnit, unit)
                }
                if !correction.evidenceUrls.isEmpty {
                    Text("证据：\(correction.evidenceUrls.joined(separator: "、"))")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                if let note = correction.reviewNote, !note.isEmpty {
                    Text("审核说明：\(note)")
                        .font(.caption)
                        .foregroundStyle(Zine.blue)
                }
                if let submitter = model.row.submitterName {
                    Text("提交人：\(submitter)\(model.row.submitterEmail.map { " · \($0)" } ?? "")")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                Text("修订 \(correction.revision) · 基线 \(correction.baseRevision) · 提交 \(DisplayFormat.dateTime(correction.createdAt)) · 审核 \(DisplayFormat.dateTime(correction.reviewedAt))")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    private func compareRow(_ label: String, _ original: String?, _ proposed: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Zine.muted)
            Text("原：\(original.flatMap { $0.isEmpty ? nil : $0 } ?? "（空）")")
                .font(.caption)
                .foregroundStyle(Zine.muted)
            Text("改：\(proposed.isEmpty ? "（空）" : proposed)")
                .font(.subheadline)
                .foregroundStyle(Zine.ink)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.alt))
    }

    @ViewBuilder
    private var decisionCard: some View {
        if model.row.correction.status == "pending" {
            PaperCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("审核决定")
                        .font(.system(size: 19, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Picker("决定", selection: $decision) {
                        Text("通过并应用").tag("approved")
                        Text("拒绝").tag("rejected")
                    }
                    .pickerStyle(.segmented)
                    Text("审核说明（可选，≤500）")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                    TextEditor(text: $reviewNote)
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
                    Button {
                        Task { await submit() }
                    } label: {
                        if model.isSubmitting {
                            ProgressView().tint(Zine.onRed)
                        } else {
                            Text(decision == "approved" ? "通过并应用" : "拒绝提案")
                        }
                    }
                    .buttonStyle(InkButtonStyle(primary: true))
                    .disabled(model.isSubmitting)
                }
            }
        } else {
            PaperCard {
                Text("该提案已处理，记录只读。")
                    .font(Zine.bodyFont)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    private func submit() async {
        let note = reviewNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if await model.decide(
            decision: decision,
            reviewNote: note.isEmpty ? nil : note
        ) {
            onChanged(decision == "approved" ? "纠错已通过并应用。" : "纠错已拒绝。")
            dismiss()
        }
    }
}
