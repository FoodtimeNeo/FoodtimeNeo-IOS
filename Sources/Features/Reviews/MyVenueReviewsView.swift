import SwiftUI

@MainActor
struct MyVenueReviewsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: MyVenueReviewsViewModel

    init(service: VenueReviewService) {
        _model = StateObject(wrappedValue: MyVenueReviewsViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "06.2",
                            title: "我的食堂点评",
                            subtitle: "食堂与档口的评价、审核状态与原因。"
                        )
                        Picker("范围", selection: $model.filter) {
                            ForEach(MyVenueReviewsViewModel.Filter.allCases) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: model.filter) { _, value in
                            Task { await model.switchFilter(value) }
                        }
                        HStack {
                            Text(model.statusText)
                                .font(.caption)
                                .foregroundStyle(Zine.muted)
                            Spacer()
                            Button("刷新") { Task { await model.load() } }
                                .buttonStyle(LinkButtonStyle())
                                .disabled(model.isLoading)
                        }
                        if let error = model.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        content
                        if model.hasMore {
                            Button("加载更多") { Task { await model.loadMore() } }
                                .buttonStyle(InkButtonStyle())
                                .disabled(model.isLoading)
                        }
                    }
                    .padding(Zine.pagePadding)
                }
                .refreshable { await model.load() }
            }
            .navigationTitle("我的食堂点评")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                if model.reviews.isEmpty { await model.load() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.reviews.isEmpty {
            LoadingStateView(message: "正在读取我的点评…")
        } else if let error = model.errorMessage, model.reviews.isEmpty {
            ErrorStateView(message: error) { Task { await model.load() } }
        } else if model.reviews.isEmpty {
            EmptyStateView(
                title: "还没有食堂或档口点评",
                message: "在食堂或档口页面写下的评价会出现在这里。"
            )
        } else {
            ForEach(model.reviews) { review in
                card(review)
            }
        }
    }

    private func card(_ review: VenueReview) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(review.name)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(review.statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor(review.status))
                }
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= review.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(index <= review.rating ? Zine.gold : Zine.muted)
                    }
                    Text(review.targetType == "hall" ? "食堂" : "档口")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                        .padding(.leading, 6)
                }
                Text(review.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                Text(DisplayFormat.dateTime(review.createdAt))
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                if let reason = review.reviewReason, !reason.isEmpty {
                    Text("审核说明：\(reason)")
                        .font(.caption)
                        .foregroundStyle(Zine.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "approved": return Zine.green
        case "rejected", "invalidated": return Zine.red
        default: return Zine.gold
        }
    }
}
