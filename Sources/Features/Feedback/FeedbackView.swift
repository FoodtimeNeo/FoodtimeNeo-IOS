import SwiftUI

@MainActor
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: FeedbackViewModel
    private let service: FeedbackService

    init(session: AppSession) {
        _model = StateObject(wrappedValue: FeedbackViewModel(session: session))
        self.service = session.feedback
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                VStack(spacing: 12) {
                    Picker("页面", selection: $model.tab) {
                        ForEach(FeedbackViewModel.Tab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Zine.pagePadding)
                    .onChange(of: model.tab) { _, tab in
                        if tab == .records {
                            Task { await model.loadRecords(page: 1) }
                        }
                    }

                    ScrollView {
                        VStack(spacing: 16) {
                            if model.tab == .submit {
                                submitContent
                            } else {
                                recordsContent
                            }
                        }
                        .padding(Zine.pagePadding)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("建议与反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                if model.tab == .records {
                    await model.loadRecords(page: 1)
                }
            }
        }
    }

    private var submitContent: some View {
        VStack(spacing: 16) {
            SectionHeading(
                index: "04",
                title: "建议与反馈",
                subtitle: "反馈会进入管理员处理队列；处理建议会作为公开回复展示。"
            )
            PaperCard {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("反馈类型", selection: $model.type) {
                        ForEach(FeedbackType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Zine.ink)

                    TextEditor(text: $model.content)
                        .frame(minHeight: 150)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: Zine.smallRadius)
                                .fill(Zine.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Zine.smallRadius)
                                .stroke(Zine.border, lineWidth: 1)
                        )
                        .overlay(alignment: .topLeading) {
                            if model.content.isEmpty {
                                Text("请描述遇到的问题或建议（1–5000 字）")
                                    .font(.subheadline)
                                    .foregroundStyle(Zine.muted)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    HStack {
                        Text("\(model.content.count)/5000")
                            .font(.caption)
                            .foregroundStyle(model.content.count > 5000 ? Zine.red : Zine.muted)
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
                            Text("提交反馈")
                        }
                    }
                    .buttonStyle(InkButtonStyle(primary: true))
                    .disabled(model.isSubmitting)
                }
            }
            Text("额度：访客每天 2 条、普通用户每天 5 条、同设备每天 10 条；UTC+8 00:00 重置。相同请求编号重试不会重复占用额度。")
                .font(.footnote)
                .foregroundStyle(Zine.muted)
        }
    }

    private var recordsContent: some View {
        VStack(spacing: 12) {
            Picker("归档", selection: $model.archived) {
                Text("未完成").tag(false)
                Text("已完成").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: model.archived) { _, _ in
                Task { await model.loadRecords(page: 1) }
            }

            if let info = model.infoMessage, !info.isEmpty {
                Text(info)
                    .font(.footnote)
                    .foregroundStyle(Zine.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let error = model.listError, !error.isEmpty {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(Zine.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.isLoading && model.items.isEmpty {
                LoadingStateView(message: "正在读取反馈…")
            } else if model.items.isEmpty {
                EmptyStateView(
                    title: model.archived ? "暂无已完成反馈" : "暂无未完成反馈",
                    message: nil
                )
            } else {
                ForEach(model.items) { item in
                    NavigationLink {
                        FeedbackDetailView(service: service, feedbackID: item.id)
                    } label: {
                        FeedbackRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
                if model.totalPages > 1 {
                    HStack {
                        Button("上一页") {
                            Task { await model.loadRecords(page: model.page - 1) }
                        }
                        .buttonStyle(InkButtonStyle())
                        .disabled(model.page <= 1 || model.isLoading)
                        Text("第 \(model.page)/\(model.totalPages) 页")
                            .font(.footnote)
                            .foregroundStyle(Zine.muted)
                        Button("下一页") {
                            Task { await model.loadRecords(page: model.page + 1) }
                        }
                        .buttonStyle(InkButtonStyle())
                        .disabled(model.page >= model.totalPages || model.isLoading)
                    }
                }
            }
        }
    }
}

private struct FeedbackRow: View {
    let item: Feedback

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.typeLabel)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Zine.alt))
                        .foregroundStyle(Zine.ink)
                    Text(item.statusLabel)
                        .font(.caption)
                        .foregroundStyle(item.status == "completed" ? Zine.green : Zine.red)
                    Spacer()
                    Text(DisplayFormat.dateTime(item.createdAt))
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                Text(item.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                    .lineLimit(4)
                if let reply = item.latestReply, !reply.isEmpty {
                    Text("最新回复：\(reply)")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
struct FeedbackDetailView: View {
    @StateObject private var model: FeedbackDetailViewModel

    init(service: FeedbackService, feedbackID: String) {
        _model = StateObject(
            wrappedValue: FeedbackDetailViewModel(service: service, feedbackID: feedbackID)
        )
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    if model.isLoading && model.feedback == nil {
                        LoadingStateView(message: "正在读取反馈…")
                    } else if let error = model.errorMessage, model.feedback == nil {
                        ErrorStateView(message: error) {
                            Task { await model.load() }
                        }
                    } else if let feedback = model.feedback {
                        detailCard(feedback)
                        repliesCard
                    }
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("反馈详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    private func detailCard(_ feedback: Feedback) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(feedback.typeLabel)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Zine.alt))
                    Text(feedback.statusLabel)
                        .font(.caption)
                        .foregroundStyle(feedback.status == "completed" ? Zine.green : Zine.red)
                    Spacer()
                }
                Text(DisplayFormat.dateTime(feedback.createdAt))
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                Text(feedback.content)
                    .font(.body)
                    .foregroundStyle(Zine.ink)
                    .textSelection(.enabled)
            }
        }
    }

    private var repliesCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("回复历史")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                if model.replies.isEmpty {
                    Text("暂无管理员回复")
                        .font(.subheadline)
                        .foregroundStyle(Zine.muted)
                } else {
                    ForEach(model.replies) { reply in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(DisplayFormat.dateTime(reply.createdAt))
                                .font(.caption)
                                .foregroundStyle(Zine.muted)
                            Text(reply.content)
                                .font(.subheadline)
                                .foregroundStyle(Zine.ink)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 6)
                    }
                    if model.hasMoreReplies {
                        Button("加载更多回复") {
                            Task { await model.loadMoreReplies() }
                        }
                        .buttonStyle(InkButtonStyle())
                    }
                }
            }
        }
    }
}
