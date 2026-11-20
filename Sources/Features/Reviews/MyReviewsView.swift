import SwiftUI

@MainActor
struct MyReviewsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: MyReviewsViewModel
    @State private var pendingDelete: Review?

    init(session: AppSession) {
        _model = StateObject(wrappedValue: MyReviewsViewModel(service: session.reviews))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        Picker("范围", selection: $model.tab) {
                            ForEach(MyReviewsViewModel.Tab.allCases) { tab in
                                Text(tab.title).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: model.tab) { _, _ in
                            Task { await model.load(page: 1) }
                        }

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

                        content
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
            .navigationTitle("我的点评")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.load(page: 1) }
            .alert(item: $pendingDelete) { review in
                Alert(
                    title: Text("删除这条点评？"),
                    message: Text("删除后公开点评与评分会立即更新，审核历史保留。"),
                    primaryButton: .destructive(Text("删除")) {
                        Task { await model.delete(review) }
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.reviews.isEmpty && model.submissions.isEmpty {
            LoadingStateView(message: "正在读取点评…")
        } else if model.tab == .published {
            if model.reviews.isEmpty {
                EmptyStateView(title: "还没有已发布点评", message: "在菜品详情页写下第一条点评吧。")
            } else {
                ForEach(model.reviews) { review in
                    publishedCard(review)
                }
            }
        } else if model.submissions.isEmpty {
            EmptyStateView(title: "暂无审核记录", message: nil)
        } else {
            ForEach(model.submissions) { submission in
                submissionCard(submission)
            }
        }
    }

    private func publishedCard(_ review: Review) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(review.dishName)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(String(repeating: "★", count: review.rating)
                         + String(repeating: "☆", count: max(0, 5 - review.rating)))
                        .font(.caption)
                        .foregroundStyle(Zine.gold)
                        .accessibilityLabel("评分 \(review.rating) 星")
                }
                Text("\(review.diningHallName) · \(review.stallName)")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                Text(review.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                HStack {
                    Text(DisplayFormat.dateTime(review.createdAt))
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                    Spacer()
                    Button("删除") { pendingDelete = review }
                        .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }

    private func submissionCard(_ submission: ReviewSubmission) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(submission.dishName)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(submission.statusLabel)
                        .font(.caption)
                        .foregroundStyle(submission.status == "approved" ? Zine.green : submission.status == "rejected" ? Zine.red : Zine.muted)
                }
                Text("\(submission.diningHallName) · \(submission.stallName)")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                Text(submission.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                if let reason = submission.reviewReason, !reason.isEmpty {
                    Text("审核说明：\(reason)")
                        .font(.footnote)
                        .foregroundStyle(Zine.red)
                }
                Text(DisplayFormat.dateTime(submission.submittedAt))
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
        }
    }
}
