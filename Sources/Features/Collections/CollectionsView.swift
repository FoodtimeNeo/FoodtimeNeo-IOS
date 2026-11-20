import SwiftUI

@MainActor
struct CollectionsView: View {
    private struct MembershipTarget: Identifiable {
        let id: String
        let name: String
    }

    private enum Sheet: Identifiable {
        case groups
        case membership(MembershipTarget)

        var id: String {
            switch self {
            case .groups: return "groups"
            case .membership(let target): return "membership-\(target.id)"
            }
        }
    }

    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: CollectionsViewModel
    @State private var activeSheet: Sheet?

    init(session: AppSession) {
        _model = StateObject(wrappedValue: CollectionsViewModel(service: session.favorites))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 12) {
                        SectionHeading(
                            index: "06",
                            title: "收藏分组",
                            subtitle: "菜品与帖子分组独立；每类最多 20 组，分组只组织已收藏对象。"
                        )
                        Picker("类型", selection: $model.kind) {
                            ForEach(FavoriteKind.allCases) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: model.kind) { _, value in
                            Task { await model.selectKind(value) }
                        }

                        groupChips
                        if let error = model.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        content
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
                                    Task { await model.loadMore() }
                                }
                                .buttonStyle(InkButtonStyle())
                                .disabled(model.page >= model.totalPages || model.isLoading)
                            }
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("管理分组") { activeSheet = .groups }
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.loadAll() }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .groups:
                    FavoriteGroupsView(
                        service: session.favorites,
                        kind: model.kind
                    ) {
                        Task { await model.loadGroups() }
                    }
                case .membership(let target):
                    FavoriteMembershipView(
                        service: session.favorites,
                        kind: model.kind,
                        targetID: target.id,
                        targetName: target.name
                    )
                }
            }
        }
    }

    private var groupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("全部", selected: model.selectedGroupID == nil) {
                    Task { await model.selectGroup(nil) }
                }
                chip("未分组", selected: model.isUnfiled) {
                    Task { await model.selectGroup(CollectionsViewModel.unfiledID) }
                }
                ForEach(model.groups) { group in
                    chip("\(group.name) \(group.itemCount)", selected: model.selectedGroupID == group.id) {
                        Task { await model.selectGroup(group.id) }
                    }
                }
            }
        }
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? Zine.onRed : Zine.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Zine.red : Zine.paper))
                .overlay(Capsule().stroke(Zine.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityValue(Text(selected ? "已选择" : "未选择"))
        .accessibilityAddTraits(selected ? .isSelected : AccessibilityTraits())
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.dishItems.isEmpty && model.postItems.isEmpty {
            LoadingStateView(message: "正在读取收藏…")
        } else if model.kind == .dish {
            if model.dishItems.isEmpty {
                EmptyStateView(title: "暂无收藏菜品", message: "在菜品详情点收藏后会出现在这里。")
            } else {
                ForEach(model.dishItems) { dish in
                    NavigationLink {
                        DishDetailView(dishID: dish.id, catalog: session.catalog)
                    } label: {
                        PaperCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(dish.name)
                                        .font(.system(size: 17, weight: .bold, design: .serif))
                                        .foregroundStyle(Zine.ink)
                                    Text("\(dish.diningHallName) · \(dish.stallName)")
                                        .font(.caption)
                                        .foregroundStyle(Zine.muted)
                                }
                                Spacer()
                                Text(DisplayFormat.price(dish.price))
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(Zine.red)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("管理分组") {
                            activeSheet = .membership(
                                MembershipTarget(id: dish.id, name: dish.name)
                            )
                        }
                    }
                }
            }
        } else {
            if model.postItems.isEmpty {
                EmptyStateView(title: "暂无收藏帖子", message: "在社区详情点收藏后会出现在这里。")
            } else {
                ForEach(model.postItems) { post in
                    NavigationLink {
                        CommunityDetailView(postID: post.id, service: session.community)
                    } label: {
                        PaperCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(post.title)
                                        .font(.system(size: 17, weight: .bold, design: .serif))
                                        .foregroundStyle(Zine.ink)
                                    Text("\(post.userDisplayName) · \(post.favoriteCount) 收藏")
                                        .font(.caption)
                                        .foregroundStyle(Zine.muted)
                                }
                                Spacer()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("管理分组") {
                            activeSheet = .membership(
                                MembershipTarget(id: post.id, name: post.title)
                            )
                        }
                    }
                }
            }
        }
    }
}
