import SwiftUI

/// 停用账号的受限会话只展示本人决定与申诉，不出现普通导航。
@MainActor
struct RestrictedAppealsView: View {
    let user: User
    private let service: ReportService
    private let submissions: SubmissionService
    private let drafts: AppealDraftStoring?
    private let onLogout: () -> Void
    @StateObject private var model: ReportReceiptsViewModel

    init(
        user: User,
        service: ReportService,
        submissions: SubmissionService,
        drafts: AppealDraftStoring?,
        onLogout: @escaping () -> Void
    ) {
        self.user = user
        self.service = service
        self.submissions = submissions
        self.drafts = drafts
        self.onLogout = onLogout
        _model = StateObject(wrappedValue: ReportReceiptsViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(
                            index: "!",
                            title: "受限申诉会话",
                            subtitle: "只能查看本人处理决定并提交申诉；会话自登录成功起 45 分钟绝对到期。"
                        )
                        PaperCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(user.displayName)
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                    .foregroundStyle(Zine.ink)
                                Text(user.email)
                                    .font(.footnote)
                                    .foregroundStyle(Zine.muted)
                            }
                        }
                        if let error = model.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                        }
                        if model.isLoading && model.decisions.isEmpty {
                            LoadingStateView(message: "正在读取处理决定…")
                        } else if model.decisions.isEmpty {
                            EmptyStateView(
                                title: "没有待申诉的决定",
                                message: "账号恢复或收到新的处理决定后再试。"
                            )
                        } else {
                            ForEach(model.decisions) { decision in
                                decisionCard(decision)
                            }
                            if model.canLoadMore {
                                Button("加载更多") {
                                    Task { await model.loadMore() }
                                }
                                .buttonStyle(InkButtonStyle())
                            }
                        }
                        Button("退出登录", role: .destructive, action: onLogout)
                            .buttonStyle(InkButtonStyle())
                            .padding(.top, 8)
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("申诉")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                model.segment = .decisions
                if model.decisions.isEmpty {
                    await model.load()
                }
            }
        }
    }

    private func decisionCard(_ decision: ModerationDecision) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(decision.targetLabel) · \(decision.outcomeLabel)")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("公开理由：\(decision.publicReason)")
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                Text(decision.sideLabel)
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                Text("申诉截止：\(DisplayFormat.dateTime(decision.appealDeadline))")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)

                if decision.appealStatusLabel.isEmpty {
                    if decision.canAppeal {
                        NavigationLink {
                            AppealComposeView(
                                decisionID: decision.decisionId,
                                service: service,
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
}
