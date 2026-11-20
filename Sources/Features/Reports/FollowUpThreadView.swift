import SwiftUI
import UIKit

@MainActor
struct FollowUpThreadView: View {
    @StateObject private var model: FollowUpThreadViewModel
    @State private var showPicker = false

    init(reportID: String, service: ReportService, submissions: SubmissionService) {
        _model = StateObject(
            wrappedValue: FollowUpThreadViewModel(
                reportID: reportID,
                service: service,
                submissions: submissions
            )
        )
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "04.3",
                        title: "追问记录",
                        subtitle: "与管理员沟通并补充材料；管理员回复公开可见。"
                    )
                    if let error = model.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Zine.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    thread
                    composer
                }
                .padding(Zine.pagePadding)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle("追问记录")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model.items.isEmpty {
                await model.load()
            }
        }
        .sheet(isPresented: $showPicker) {
            MultiPhotoPicker(selectionLimit: max(1, model.remainingEvidenceSlots)) { images in
                Task { await model.addEvidence(images) }
            }
        }
    }

    @ViewBuilder
    private var thread: some View {
        if model.isLoading && model.items.isEmpty {
            LoadingStateView(message: "正在读取追问记录…")
        } else if model.items.isEmpty {
            EmptyStateView(
                title: "还没有追问记录",
                message: "对处理进度有疑问时，可在下方追加追问。"
            )
        } else {
            if model.hasMore {
                Button("加载更早的追问") {
                    Task { await model.loadMore() }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(model.isLoading)
            }
            ForEach(model.items) { item in
                card(item)
            }
        }
    }

    private func card(_ item: ReportFollowUp) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.isStaff ? "管理员回复" : "我")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.isStaff ? Zine.red : Zine.muted)
                Text(item.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                    .textSelection(.enabled)
                Text(DisplayFormat.dateTime(item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var composer: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("追加追问（500 字以内）")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                TextEditor(text: $model.content)
                    .frame(minHeight: 70, maxHeight: 120)
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
                                        .frame(width: 68, height: 68)
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
                    .disabled(model.remainingEvidenceSlots == 0 || model.isSending)

                Button {
                    Task { await model.send() }
                } label: {
                    if model.isSending {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("提交追问")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isSending)

                Text("每个账号每天最多 5 次追问；证据仅本人与审核者可见。")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
        }
    }
}
