import SwiftUI

@MainActor
struct ReportReceiptsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ReportReceiptsViewModel
    @State private var actionDecision: ModerationDecision?
    private let submissions: SubmissionService
    private let drafts: AppealDraftStoring?

    init(
        service: ReportService,
        submissions: SubmissionService,
        drafts: AppealDraftStoring? = nil
    ) {
        _model = StateObject(wrappedValue: ReportReceiptsViewModel(service: service))
        self.submissions = submissions
        self.drafts = drafts
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "04.2",
                            title: "举报与处理决定",
                            subtitle: "公开结果、入箱时间与申诉截止。"
                        )
                        Picker("范围", selection: $model.segment) {
                            ForEach(ReportReceiptsViewModel.Segment.allCases) { segment in
                                Text(segment.title).tag(segment)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: model.segment) { _, value in
                            Task { await model.switchSegment(value) }
                        }

                        HStack {
                            Text(model.statusText)
                                .font(.caption)
                                .foregroundStyle(Zine.muted)
                            Spacer()
                            Button("刷新") {
                                Task { await model.load() }
                            }
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
                        if model.canLoadMore {
                            Button("加载更多") {
                                Task { await model.loadMore() }
                            }
                            .buttonStyle(InkButtonStyle())
                            .disabled(model.isLoadingMore)
                        }
                    }
                    .padding(Zine.pagePadding)
                }
                .refreshable { await model.load() }
            }
            .navigationTitle("举报与处理决定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                if model.reports.isEmpty && model.decisions.isEmpty {
                    await model.load()
                }
            }
            .sheet(item: $actionDecision) { decision in
                DecisionActionsView(model: model, decisionID: decision.decisionId)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && isEmpty {
            LoadingStateView(message: "正在读取举报记录…")
        } else if let error = model.errorMessage, isEmpty {
            ErrorStateView(message: error) {
                Task { await model.load() }
            }
        } else if isEmpty {
            EmptyStateView(
                title: model.segment == .reports ? "还没有举报记录" : "还没有收到的处理决定",
                message: model.segment == .reports
                    ? "在食记、评论或私信中选择举报后，进度会出现在这里。"
                    : "举报成立或不成立后，双方会收到决定回执。"
            )
        } else if model.segment == .reports {
            ForEach(model.reports) { report in
                reportCard(report)
            }
        } else {
            ForEach(model.decisions) { decision in
                decisionCard(decision)
            }
        }
    }

    private var isEmpty: Bool {
        model.segment == .reports ? model.reports.isEmpty : model.decisions.isEmpty
    }

    private func reportCard(_ report: UserReport) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(report.targetLabel) · \(report.statusLabel)")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text(DisplayFormat.dateTime(report.createdAt))
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                Text("举报理由：\(report.reason)")
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                if let excerpt = report.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                        .lineLimit(3)
                }
                if let outcome = report.outcome, !outcome.isEmpty {
                    Text("处理结果：\(outcome == "upheld" ? "成立" : "不成立")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Zine.red)
                    Text("公开理由：\(report.publicReason ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(Zine.ink)
                } else if report.status == "legacy" {
                    Text("历史记录，未提供详细结果。")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                NavigationLink {
                    FollowUpThreadView(
                        reportID: report.id,
                        service: modelService,
                        submissions: submissions
                    )
                } label: {
                    Text("追问记录")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Zine.red)
                        .underline()
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func decisionCard(_ decision: ModerationDecision) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(decision.targetLabel) · \(decision.outcomeLabel)")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("公开理由：\(decision.publicReason)")
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                Text("入箱时间：\(DisplayFormat.dateTime(decision.deliveredAt))")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                Text("申诉截止：\(DisplayFormat.dateTime(decision.appealDeadline))")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                Text(decision.sideLabel)
                    .font(.caption)
                    .foregroundStyle(Zine.muted)

                Button("查看处理动作") {
                    actionDecision = decision
                }
                .buttonStyle(LinkButtonStyle())

                if decision.appealStatusLabel.isEmpty {
                    if decision.canAppeal {
                        NavigationLink {
                            AppealComposeView(
                                decisionID: decision.decisionId,
                                service: modelService,
                                submissions: submissions,
                                drafts: drafts
                            )
                        } label: {
                            Text("提交申诉")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Zine.red)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("申诉期限已过。")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    }
                } else {
                    Text("你的申诉：\(decision.appealStatusLabel)\(decision.appealOutcomeLabel().isEmpty ? "" : " · \(decision.appealOutcomeLabel())")")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var modelService: ReportService {
        model.service
    }
}

@MainActor
private struct DecisionActionsView: View {
    @ObservedObject var model: ReportReceiptsViewModel
    let decisionID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let actions = model.actions(decisionID: decisionID) {
                            if actions.isEmpty {
                                Text("尚未记录实际处理动作。")
                                    .font(.subheadline)
                                    .foregroundStyle(Zine.muted)
                            } else {
                                ForEach(actions) { action in
                                    PaperCard {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(action.label)
                                                .font(.system(size: 17, weight: .bold, design: .serif))
                                                .foregroundStyle(Zine.ink)
                                            Text("目标：\(action.targetType) · \(DisplayFormat.dateTime(action.createdAt))")
                                                .font(.caption)
                                                .foregroundStyle(Zine.muted)
                                            if let note = action.note, !note.isEmpty {
                                                Text(note)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Zine.ink)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        } else {
                            LoadingStateView(message: "正在读取处理动作…")
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("处理动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.loadActions(decisionID: decisionID) }
        }
    }
}
