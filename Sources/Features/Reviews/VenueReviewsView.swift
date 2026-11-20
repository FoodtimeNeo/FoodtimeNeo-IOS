import SwiftUI

@MainActor
struct VenueReviewsView: View {
    private let type: VenueTargetType
    private let targetID: String
    private let name: String
    private let service: VenueReviewService
    @StateObject private var model: VenueReviewsViewModel
    @State private var showComposer = false

    init(type: VenueTargetType, targetID: String, name: String, service: VenueReviewService) {
        self.type = type
        self.targetID = targetID
        self.name = name
        self.service = service
        _model = StateObject(
            wrappedValue: VenueReviewsViewModel(type: type, targetID: targetID, service: service)
        )
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    SectionHeading(
                        index: "02.2",
                        title: name,
                        subtitle: "\(type.label)点评；提交后进入审核，通过后公开并计入评分。"
                    )
                    summaryCard
                    mineCard
                    filterPicker
                    if let error = model.errorMessage, model.reviews.isEmpty {
                        ErrorStateView(message: error) {
                            Task { await model.load() }
                        }
                    } else {
                        reviewsContent
                    }
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("\(type.label)点评")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("写点评") { showComposer = true }
            }
        }
        .task { await model.load() }
        .sheet(isPresented: $showComposer) {
            VenueReviewComposerView(
                type: type,
                targetID: targetID,
                service: service
            ) {
                Task { await model.reloadAfterSubmit() }
            }
        }
    }

    private var summaryCard: some View {
        PaperCard {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.target?.name ?? name)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    if let target = model.target {
                        Text(DisplayFormat.score(target.averageScore, reviewCount: target.reviewCount))
                            .font(.subheadline)
                            .foregroundStyle(Zine.red)
                    } else {
                        Text("暂无评分")
                            .font(.subheadline)
                            .foregroundStyle(Zine.muted)
                    }
                }
                Spacer()
                Text("\(model.total) 条")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    @ViewBuilder
    private var mineCard: some View {
        if let mine = model.mine {
            if let privateSubmission = mine.privateSubmission {
                PaperCard {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("我的评价 · \(privateSubmission.statusLabel)")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(privateSubmission.status == "rejected" ? Zine.red : Zine.ink)
                        Text(privateSubmission.content)
                            .font(.subheadline)
                            .foregroundStyle(Zine.muted)
                        if let reason = privateSubmission.reviewReason, !reason.isEmpty {
                            Text("审核说明：\(reason)")
                                .font(.footnote)
                                .foregroundStyle(Zine.red)
                        }
                    }
                }
            } else if mine.publicVersion != nil {
                PaperCard {
                    Text("你的\(type.label)评价已公开。")
                        .font(.subheadline)
                        .foregroundStyle(Zine.green)
                }
            }
        }
    }

    private var filterPicker: some View {
        Picker("评分筛选", selection: Binding(
            get: { model.ratingFilter },
            set: { value in Task { await model.changeFilter(value) } }
        )) {
            Text("全部").tag("all")
            Text("5 星").tag("5")
            Text("4 星").tag("4")
            Text("1–3 星").tag("1-3")
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var reviewsContent: some View {
        if model.isLoading && model.reviews.isEmpty {
            LoadingStateView(message: "正在读取点评…")
        } else if model.reviews.isEmpty {
            EmptyStateView(title: "还没有点评", message: "来写下第一条\(type.label)点评吧。")
        } else {
            ForEach(model.reviews) { review in
                PaperCard {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(review.userDisplayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Zine.ink)
                            Text(String(repeating: "★", count: review.rating)
                                 + String(repeating: "☆", count: max(0, 5 - review.rating)))
                                .font(.caption)
                                .foregroundStyle(Zine.gold)
                                .accessibilityLabel("评分 \(review.rating) 星")
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
                                model.toggleLike(review)
                            } label: {
                                Label(
                                    "\(model.likeCount(review))",
                                    systemImage: model.isLiked(review) ? "heart.fill" : "heart"
                                )
                                .font(.caption)
                                .foregroundStyle(model.isLiked(review) ? Zine.red : Zine.muted)
                            }
                            .buttonStyle(.plain)
                            if review.replyCount > 0 {
                                Label("\(review.replyCount)", systemImage: "text.bubble")
                                    .font(.caption)
                                    .foregroundStyle(Zine.muted)
                            }
                        }
                    }
                }
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

@MainActor
struct VenueReviewComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: VenueReviewComposerViewModel
    private let onSubmitted: () -> Void

    init(
        type: VenueTargetType,
        targetID: String,
        service: VenueReviewService,
        onSubmitted: @escaping () -> Void
    ) {
        _model = StateObject(
            wrappedValue: VenueReviewComposerViewModel(
                type: type,
                targetID: targetID,
                service: service
            )
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
                            index: "02.2",
                            title: "写\(model.rating)星点评",
                            subtitle: "提交后进入审核，通过后公开并计入评分。"
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
                                .font(.title2)
                                .foregroundStyle(Zine.gold)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(value) 星")
                        .accessibilityAddTraits(
                            value == model.rating ? .isSelected : AccessibilityTraits()
                        )
                    }
                }
                .accessibilityValue("\(model.rating) 星")

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
                Text("点评正在审核，通过后会公开并计入评分。")
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
