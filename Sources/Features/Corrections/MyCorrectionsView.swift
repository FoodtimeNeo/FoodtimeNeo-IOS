import SwiftUI

@MainActor
struct MyCorrectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: MyCorrectionsViewModel

    init(service: CorrectionService) {
        _model = StateObject(wrappedValue: MyCorrectionsViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "01.5",
                            title: "我的纠错",
                            subtitle: "名称、价格与介绍的更正进度。"
                        )
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
                        if model.hasMore {
                            Button("加载更多") {
                                Task { await model.loadMore() }
                            }
                            .buttonStyle(InkButtonStyle())
                            .disabled(model.isLoading)
                        }
                    }
                    .padding(Zine.pagePadding)
                }
                .refreshable { await model.load() }
            }
            .navigationTitle("我的纠错")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                if model.items.isEmpty {
                    await model.load()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.items.isEmpty {
            LoadingStateView(message: "正在读取纠错记录…")
        } else if let error = model.errorMessage, model.items.isEmpty {
            ErrorStateView(message: error) {
                Task { await model.load() }
            }
        } else if model.items.isEmpty {
            EmptyStateView(
                title: "还没有纠错提案",
                message: "在菜品详情点「纠错」，提交名称、价格或介绍的更正。"
            )
        } else {
            ForEach(model.items) { item in
                card(item)
            }
        }
    }

    private func card(_ item: CatalogCorrection) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.targetSummary)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(item.statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color(for: item))
                }
                Text(DisplayFormat.dateTime(item.createdAt))
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                ForEach(Array(item.changeDescriptions.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(Zine.ink)
                }
                Text("理由：\(item.reason)")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                if let note = item.reviewNote, !note.isEmpty {
                    Text("审核说明：\(note)")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func color(for item: CatalogCorrection) -> Color {
        switch item.status {
        case "approved": return Zine.green
        case "rejected": return Zine.red
        default: return Zine.gold
        }
    }
}
