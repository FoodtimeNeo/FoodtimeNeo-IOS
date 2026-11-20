import Foundation
import SwiftUI

@MainActor
struct AdminReviewsView: View {
    @StateObject private var model: AdminReviewsViewModel
    @State private var removing: AdminReviewItem?
    private let service: AdminService

    init(service: AdminService) {
        self.service = service
        _model = StateObject(wrappedValue: AdminReviewsViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "08.7",
                        title: "正式点评管理",
                        subtitle: "含停用菜品历史；移除为软删除并保留审核历史，评分服务端重算。"
                    )
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Zine.muted)
                        TextField("搜索内容、用户或菜名", text: $model.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await model.load(page: 1) } }
                            .onChange(of: model.query) { _, _ in
                                model.queryChanged()
                            }
                    }
                    .modifier(FormInputStyle())

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

                    if model.isLoading && model.reviews.isEmpty {
                        LoadingStateView(message: "正在读取点评…")
                    } else if model.reviews.isEmpty {
                        EmptyStateView(title: "没有匹配点评", message: nil)
                    } else {
                        ForEach(model.reviews) { review in
                            reviewCard(review)
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
        .navigationTitle("正式点评管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(page: 1) }
        .sheet(item: $removing) { review in
            AdminReviewRemovalView(review: review) { reason in
                await model.remove(review, reason: reason)
            }
        }
    }

    private func reviewCard(_ review: AdminReviewItem) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(review.dishName)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Text("\(review.rating) 星")
                        .font(.caption)
                        .foregroundStyle(Zine.gold)
                    Spacer()
                    Text(DisplayFormat.dateTime(review.createdAt))
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                }
                Text(review.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                    .lineLimit(6)
                Text("\(review.userDisplayName)\(review.userEmail.map { " · \($0)" } ?? "")")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                Text("\(review.diningHallName ?? "-") / \(review.stallName ?? "-")")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
                HStack {
                    if let risk = review.aiRiskLevel {
                        Text("AI：\(risk)\(review.aiConfidence.map { String(format: " %.0f%%", $0 * 100) } ?? "")")
                            .font(.caption2)
                            .foregroundStyle(Zine.blue)
                    }
                    Spacer()
                    Button("移除点评") {
                        removing = review
                    }
                    .buttonStyle(LinkButtonStyle())
                    .disabled(model.removingID == review.id)
                }
            }
        }
    }
}

@MainActor
private struct AdminReviewRemovalView: View {
    @Environment(\.dismiss) private var dismiss
    let review: AdminReviewItem
    let onSubmit: (String) async -> Bool
    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "08.7",
                            title: "移除点评",
                            subtitle: "原因必填；移除后内容软删除，审核历史保留。"
                        )
                        PaperCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(review.content)
                                    .font(.subheadline)
                                    .foregroundStyle(Zine.ink)
                                    .lineLimit(6)
                                Text("原因")
                                    .font(.footnote)
                                    .foregroundStyle(Zine.muted)
                                TextEditor(text: $reason)
                                    .frame(minHeight: 90)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                                            .stroke(Zine.border, lineWidth: 1)
                                    )
                                if let errorMessage, !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .font(.subheadline)
                                        .foregroundStyle(Zine.red)
                                }
                                Button {
                                    Task { await submit() }
                                } label: {
                                    if isSubmitting {
                                        ProgressView().tint(Zine.onRed)
                                    } else {
                                        Text("确认移除")
                                    }
                                }
                                .buttonStyle(InkButtonStyle(primary: true))
                                .disabled(isSubmitting)
                            }
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("移除点评")
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
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请填写移除原因"
            return
        }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        if await onSubmit(trimmed) {
            dismiss()
        } else {
            errorMessage = "移除失败，请关闭后查看列表错误信息。"
        }
    }
}
