import SwiftUI

@MainActor
struct DishReviewsSection: View {
    @StateObject private var model: DishReviewsViewModel
    @State private var showComposer = false
    private let dishID: String
    private let service: ReviewService

    init(session: AppSession, dishID: String) {
        self.dishID = dishID
        self.service = session.reviews
        _model = StateObject(
            wrappedValue: DishReviewsViewModel(dishID: dishID, service: session.reviews)
        )
    }

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("点评")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Text("\(model.total)")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                    Spacer()
                    Button("写点评") { showComposer = true }
                        .buttonStyle(LinkButtonStyle())
                }

                if let error = model.errorMessage, model.reviews.isEmpty {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Zine.red)
                    Button("重新加载") {
                        Task { await model.load() }
                    }
                    .buttonStyle(LinkButtonStyle())
                } else if model.isLoading && model.reviews.isEmpty {
                    ProgressView().tint(Zine.red)
                } else if model.reviews.isEmpty {
                    Text("还没有点评，来当第一个吧。")
                        .font(.subheadline)
                        .foregroundStyle(Zine.muted)
                } else {
                    ForEach(model.reviews) { review in
                        reviewRow(review)
                        Divider().overlay(Zine.border)
                    }
                    if model.hasMore {
                        Button("加载更多点评") {
                            Task { await model.loadMore() }
                        }
                        .buttonStyle(InkButtonStyle())
                        .disabled(model.isLoadingMore)
                    }
                }
            }
        }
        .task { await model.load() }
        .sheet(isPresented: $showComposer) {
            ReviewComposerView(dishID: dishID, service: service) {
                Task { await model.load() }
            }
        }
    }

    private func reviewRow(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(review.userDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Zine.ink)
                Text(String(repeating: "★", count: review.rating)
                     + String(repeating: "☆", count: max(0, 5 - review.rating)))
                    .font(.caption)
                    .foregroundStyle(Zine.gold)
                Spacer()
                Text(DisplayFormat.dateTime(review.createdAt))
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
            Text(review.content)
                .font(.subheadline)
                .foregroundStyle(Zine.ink)
            HStack(spacing: 14) {
                Button {
                    Task { await model.toggleLike(review) }
                } label: {
                    Label("\(review.likeCount)", systemImage: review.likedByMe ? "heart.fill" : "heart")
                        .font(.caption)
                        .foregroundStyle(review.likedByMe ? Zine.red : Zine.muted)
                }
                .buttonStyle(.plain)
                if review.replyCount > 0 {
                    Label("\(review.replyCount)", systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
struct ReviewComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ReviewComposerViewModel
    private let onSubmitted: () -> Void

    init(dishID: String, service: ReviewService, onSubmitted: @escaping () -> Void) {
        _model = StateObject(
            wrappedValue: ReviewComposerViewModel(dishID: dishID, service: service)
        )
        self.onSubmitted = onSubmitted
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 16) {
                        SectionHeading(
                            index: "02",
                            title: "写点评",
                            subtitle: "点评提交后进入审核，通过后公开并计入评分。"
                        )
                        if model.didSubmit {
                            successCard
                        } else {
                            formCard
                        }
                    }
                    .padding(Zine.pagePadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("写点评")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var formCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("评分")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            model.rating = value
                        } label: {
                            Image(systemName: value <= model.rating ? "star.fill" : "star")
                                .font(.system(size: 26))
                                .foregroundStyle(Zine.gold)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(value) 星")
                    }
                }

                Text("正文")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                TextEditor(text: $model.content)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                            .stroke(Zine.border, lineWidth: 1)
                    )
                    .onChange(of: model.content) { _, value in
                        if value.count > 500 {
                            model.content = String(value.prefix(500))
                        }
                    }
                HStack {
                    Text("\(model.content.count)/500")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                    Spacer()
                }

                if let error = model.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Zine.red)
                }

                Button {
                    Task { await model.submit() }
                } label: {
                    if model.isSubmitting {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("提交点评")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isSubmitting)
            }
        }
    }

    private var successCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("点评已提交")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("点评正在审核，通过后会公开并计入评分。可以在“我的点评”查看审核状态。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                Button("完成") {
                    onSubmitted()
                    dismiss()
                }
                .buttonStyle(InkButtonStyle(primary: true))
            }
        }
    }
}
