import Foundation
import SwiftUI

@MainActor
struct ModerationQueueView: View {
    @StateObject private var model: ModerationQueueViewModel
    @State private var decision: ModerationDecision?

    init(service: AdminService) {
        _model = StateObject(wrappedValue: ModerationQueueViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "08.1",
                        title: "审核队列",
                        subtitle: "仅 pending 可审核；驳回必须原因，菜品通过需补齐价格。"
                    )
                    Picker("状态", selection: $model.status) {
                        Text("待审核").tag("pending")
                        Text("已通过").tag("approved")
                        Text("已驳回").tag("rejected")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: model.status) { _, _ in
                        Task { await model.load(page: 1) }
                    }
                    Picker("类型", selection: $model.type) {
                        Text("全部").tag("")
                        Text("评论").tag("review")
                        Text("菜品").tag("dish")
                        Text("档口").tag("stall")
                        Text("图片").tag("photo")
                        Text("点评回复").tag("dish-review-reply")
                    }
                    .pickerStyle(.menu)
                    .tint(Zine.ink)
                    .onChange(of: model.type) { _, _ in
                        Task { await model.load(page: 1) }
                    }

                    if let info = model.infoMessage, !info.isEmpty {
                        Text(info).font(.footnote).foregroundStyle(Zine.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let error = model.errorMessage, !error.isEmpty {
                        Text(error).font(.subheadline).foregroundStyle(Zine.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if model.isLoading && model.items.isEmpty {
                        LoadingStateView(message: "正在读取审核队列…")
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
                                    .font(.footnote).foregroundStyle(Zine.muted)
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
        .navigationTitle("审核队列")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(page: 1) }
        .sheet(item: $decision) { decision in
            ModerationDecisionView(
                item: decision.item,
                initialAction: decision.initialAction
            ) { action, reason, price in
                await model.moderate(
                    decision.item,
                    action: action,
                    reason: reason,
                    price: price
                )
            }
        }
    }

    private func itemCard(_ item: ModerationItem) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("\(item.type) · \(item.name)")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(item.status)
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                if let email = item.userEmail, !email.isEmpty {
                    Text("\(item.userDisplayName) · \(email)")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                } else {
                    Text(item.userDisplayName)
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                if !item.content.isEmpty {
                    Text(item.content)
                        .font(.subheadline)
                        .foregroundStyle(Zine.ink)
                        .lineLimit(5)
                }
                Text("发布：\(DisplayFormat.dateTime(item.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
                if let rating = item.rating {
                    Text("评分：\(rating)")
                        .font(.caption)
                        .foregroundStyle(Zine.gold)
                }
                if let price = item.price {
                    Text("价格：\(DisplayFormat.price(price))")
                        .font(.caption)
                        .foregroundStyle(Zine.red)
                }
                HStack(spacing: 10) {
                    if let risk = item.aiRiskLevel {
                        Text("AI：\(risk) \(item.aiConfidence.map { String(format: "%.0f%%", $0 * 100) } ?? "")")
                            .font(.caption2)
                            .foregroundStyle(Zine.blue)
                    }
                    Spacer()
                    if item.status == "pending" {
                        Button("通过") {
                            decision = ModerationDecision(item: item, initialAction: "approve")
                        }
                        .buttonStyle(LinkButtonStyle())
                        .disabled(model.actingItemID == item.id)
                        Button("驳回") {
                            decision = ModerationDecision(item: item, initialAction: "reject")
                        }
                        .buttonStyle(LinkButtonStyle())
                        .disabled(model.actingItemID == item.id)
                    }
                }
            }
        }
    }
}

private struct ModerationDecision: Identifiable {
    let item: ModerationItem
    let initialAction: String

    var id: String { "\(item.id)-\(initialAction)" }
}

@MainActor
private struct ModerationDecisionView: View {
    @Environment(\.dismiss) private var dismiss
    let item: ModerationItem
    let onSubmit: (String, String?, Decimal?) async -> Bool
    @State private var action: String
    @State private var reason = ""
    @State private var priceText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(
        item: ModerationItem,
        initialAction: String,
        onSubmit: @escaping (String, String?, Decimal?) async -> Bool
    ) {
        self.item = item
        self.onSubmit = onSubmit
        _action = State(initialValue: initialAction)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "08.1",
                            title: "审核：\(item.name)",
                            subtitle: "通过后立即发布；驳回必须填写原因。"
                        )
                        PaperCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("决定", selection: $action) {
                                    Text("通过").tag("approve")
                                    Text("驳回").tag("reject")
                                }
                                .pickerStyle(.segmented)
                                if item.type == "dish" && action == "approve" {
                                    Text("菜品通过需要价格")
                                        .font(.footnote).foregroundStyle(Zine.muted)
                                    TextField("价格", text: $priceText)
                                        .keyboardType(.decimalPad)
                                        .modifier(FormInputStyle())
                                }
                                Text("原因/说明")
                                    .font(.footnote).foregroundStyle(Zine.muted)
                                TextEditor(text: $reason)
                                    .frame(minHeight: 80)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                                    .overlay(RoundedRectangle(cornerRadius: Zine.smallRadius).stroke(Zine.border, lineWidth: 1))
                                if let errorMessage, !errorMessage.isEmpty {
                                    Text(errorMessage).font(.subheadline).foregroundStyle(Zine.red)
                                }
                                Button {
                                    Task { await submit() }
                                } label: {
                                    if isSubmitting { ProgressView().tint(Zine.onRed) }
                                    else { Text(action == "approve" ? "确认通过" : "确认驳回") }
                                }
                                .buttonStyle(InkButtonStyle(primary: true))
                                .disabled(isSubmitting)
                            }
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("审核")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        guard !isSubmitting else { return }
        if action == "reject", reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "驳回必须填写原因"
            return
        }
        var price: Decimal?
        if item.type == "dish", action == "approve" {
            let text = priceText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
            guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), value >= 0 else {
                errorMessage = "菜品通过需要有效价格"
                return
            }
            price = value
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        if await onSubmit(action, reason.isEmpty ? nil : reason, price) {
            dismiss()
        }
    }
}

@MainActor
struct ModerationLogsView: View {
    @StateObject private var model: ModerationLogsViewModel

    init(service: AdminService) {
        _model = StateObject(wrappedValue: ModerationLogsViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "08.2",
                        title: "审核日志",
                        subtitle: "区分 AI 与人工审核，保留原因与时间。"
                    )
                    if let error = model.errorMessage, !error.isEmpty {
                        Text(error).font(.subheadline).foregroundStyle(Zine.red)
                    }
                    if model.isLoading && model.logs.isEmpty {
                        LoadingStateView(message: "正在读取日志…")
                    } else if model.logs.isEmpty {
                        EmptyStateView(title: "暂无日志", message: nil)
                    } else {
                        ForEach(model.logs) { log in
                            PaperCard {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("\(log.type) · \(log.action)")
                                            .font(.system(size: 16, weight: .bold, design: .serif))
                                            .foregroundStyle(Zine.ink)
                                        Spacer()
                                        Text(log.actor)
                                            .font(.caption2)
                                            .foregroundStyle(log.actor == "ai" ? Zine.blue : Zine.muted)
                                    }
                                    if let name = log.name { Text(name).font(.caption).foregroundStyle(Zine.muted) }
                                    if let reason = log.reason, !reason.isEmpty {
                                        Text("原因：\(reason)").font(.caption).foregroundStyle(Zine.red)
                                    }
                                    Text(DisplayFormat.dateTime(log.createdAt))
                                        .font(.caption2).foregroundStyle(Zine.muted)
                                }
                            }
                        }
                    }
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("审核日志")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(page: 1) }
    }
}
