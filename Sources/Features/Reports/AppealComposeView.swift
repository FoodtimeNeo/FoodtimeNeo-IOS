import SwiftUI
import UIKit

@MainActor
struct AppealComposeView: View {
    @StateObject private var model: AppealComposeViewModel
    @State private var showPicker = false

    init(
        decisionID: String,
        service: ReportService,
        submissions: SubmissionService,
        drafts: AppealDraftStoring? = nil
    ) {
        _model = StateObject(
            wrappedValue: AppealComposeViewModel(
                decisionID: decisionID,
                service: service,
                submissions: submissions,
                drafts: drafts
            )
        )
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    SectionHeading(
                        index: "04.3",
                        title: "提交申诉",
                        subtitle: "文字和最多 3 张图片；失败后可在本页重试。"
                    )
                    content
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("提交申诉")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .onChange(of: model.content) { _, _ in
            model.persistDraft()
        }
        .sheet(isPresented: $showPicker) {
            MultiPhotoPicker(selectionLimit: max(1, model.remainingEvidenceSlots)) { images in
                Task { await model.addEvidence(images) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.decision == nil {
            LoadingStateView(message: "正在读取处理决定…")
        } else if let error = model.errorMessage, model.decision == nil {
            ErrorStateView(message: error) {
                Task { await model.load() }
            }
        } else if let decision = model.decision {
            decisionCard(decision)
            if model.alreadyAppealed {
                statusCard(decision)
            } else if model.deadlinePassed {
                Text("申诉期限已过。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                formCard
            }
            if let error = model.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(Zine.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusCard(_ decision: ModerationDecision) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("你的申诉：\(model.appealStatusText)")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                let outcome = decision.appealOutcomeLabel()
                if !outcome.isEmpty {
                    Text("复核结论：\(outcome)")
                        .font(.subheadline)
                        .foregroundStyle(Zine.green)
                }
                Text("同一决定只能提交一次申诉；复核结论不会自动恢复处罚。")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var formCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("申诉内容（最多 2000 字）")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                TextEditor(text: $model.content)
                    .frame(minHeight: 120, maxHeight: 220)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                    .overlay(
                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                            .stroke(Zine.border, lineWidth: 1)
                    )

                if !model.evidence.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(model.evidence) { item in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: item.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: Zine.smallRadius))
                                    if item.isUploading {
                                        ProgressView()
                                            .tint(Zine.onRed)
                                            .padding(5)
                                            .background(Circle().fill(Zine.ink.opacity(0.6)))
                                    }
                                    Button {
                                        model.removeEvidence(id: item.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Zine.red)
                                            .background(Circle().fill(Zine.paper))
                                    }
                                    .offset(x: 5, y: -5)
                                    .accessibilityLabel("移除证据")
                                }
                            }
                        }
                    }
                }
                Button("添加证据（最多 3 张）") { showPicker = true }
                    .buttonStyle(InkButtonStyle())
                    .disabled(model.remainingEvidenceSlots == 0 || model.isSubmitting)

                Button {
                    Task { await model.submit() }
                } label: {
                    if model.isSubmitting {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("提交申诉")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isSubmitting)

                Text("草稿按服务与账号保存在本机；重新认证受限会话后可恢复。证据仅本人与复核者可见。")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
        }
    }
}
