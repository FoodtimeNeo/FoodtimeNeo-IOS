import SwiftUI

@MainActor
struct HistoryView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: HistoryViewModel
    @State private var confirmClear = false

    init(session: AppSession) {
        _model = StateObject(wrappedValue: HistoryViewModel(service: session.history))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 12) {
                        SectionHeading(
                            index: "07",
                            title: "浏览历史",
                            subtitle: "服务器按账号保存；菜品/帖子各最近 50 条，不按时间过期。"
                        )
                        Picker("类型", selection: $model.kind) {
                            ForEach(HistoryKind.allCases) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: model.kind) { _, value in
                            Task { await model.selectKind(value) }
                        }

                        if let settings = model.settings {
                            PaperCard {
                                Toggle(
                                    "记录浏览历史（关闭后停止新增，已有记录保留）",
                                    isOn: Binding(
                                        get: { settings.enabled },
                                        set: { value in Task { await model.setEnabled(value) } }
                                    )
                                )
                                .tint(Zine.red)
                                .disabled(model.isSavingSettings)
                            }
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

                        if model.isLoading && model.items.isEmpty {
                            LoadingStateView(message: "正在读取历史…")
                        } else if model.items.isEmpty {
                            EmptyStateView(title: "暂无\(model.kind.label)历史", message: nil)
                        } else {
                            ForEach(model.items) { item in
                                row(item)
                            }
                            if model.totalPages > 1 {
                                HStack {
                                    Button("上一页") {
                                        Task { await model.loadPage(model.page - 1) }
                                    }
                                    .buttonStyle(InkButtonStyle())
                                    .disabled(model.page <= 1 || model.isLoading)
                                    Text("第 \(model.page)/\(model.totalPages) 页")
                                        .font(.footnote)
                                        .foregroundStyle(Zine.muted)
                                    Button("下一页") {
                                        Task { await model.loadPage(model.page + 1) }
                                    }
                                    .buttonStyle(InkButtonStyle())
                                    .disabled(model.page >= model.totalPages || model.isLoading)
                                }
                            }
                            Button("清空\(model.kind.label)历史") { confirmClear = true }
                                .buttonStyle(InkButtonStyle())
                                .foregroundStyle(Zine.red)
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("浏览历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.load() }
            .alert("清空\(model.kind.label)历史？", isPresented: $confirmClear) {
                Button("清空", role: .destructive) {
                    Task { await model.clear() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("清空后旧离线任务不能补回记录；另一类历史不受影响。")
            }
        }
    }

    @ViewBuilder
    private func row(_ item: BrowsingHistoryItem) -> some View {
        if item.available {
            NavigationLink {
                if model.kind == .dish {
                    DishDetailView(dishID: item.targetId, catalog: session.catalog)
                } else {
                    CommunityDetailView(postID: item.targetId, service: session.community)
                }
            } label: {
                card(item)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("删除这条历史", role: .destructive) {
                    Task { await model.delete(item) }
                }
            }
        } else {
            card(item)
                .contextMenu {
                    Button("删除这条历史", role: .destructive) {
                        Task { await model.delete(item) }
                    }
                }
        }
    }

    private func card(_ item: BrowsingHistoryItem) -> some View {
        PaperCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.available ? (item.title ?? "已失效内容") : "内容已失效")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.available ? Zine.ink : Zine.muted)
                    if item.available, let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                    }
                    Text(DisplayFormat.dateTime(item.visitedAt))
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                }
                Spacer()
                if item.available {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
            }
        }
    }
}
