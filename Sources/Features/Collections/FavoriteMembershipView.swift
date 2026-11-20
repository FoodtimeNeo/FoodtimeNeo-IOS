import SwiftUI

@MainActor
struct FavoriteMembershipView: View {
    @Environment(\.dismiss) private var dismiss
    private let service: FavoriteService
    private let kind: FavoriteKind
    private let targetID: String
    private let targetName: String
    @State private var groups: [FavoriteGroup] = []
    @State private var selected: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(
        service: FavoriteService,
        kind: FavoriteKind,
        targetID: String,
        targetName: String
    ) {
        self.service = service
        self.kind = kind
        self.targetID = targetID
        self.targetName = targetName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 12) {
                        SectionHeading(
                            index: "06.2",
                            title: targetName,
                            subtitle: "同一收藏可加入同类型多个分组；加入不会自动创建收藏。"
                        )
                        if let errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if isLoading && groups.isEmpty {
                            LoadingStateView(message: "正在读取分组…")
                        } else if groups.isEmpty {
                            EmptyStateView(title: "还没有分组", message: "先在“管理分组”创建。")
                        } else {
                            ForEach(groups) { group in
                                Button {
                                    Task { await toggle(group) }
                                } label: {
                                    PaperCard {
                                        HStack {
                                            Image(systemName: selected.contains(group.id)
                                                  ? "checkmark.square.fill" : "square")
                                                .foregroundStyle(Zine.red)
                                            Text(group.name)
                                                .foregroundStyle(Zine.ink)
                                            Spacer()
                                            Text("\(group.itemCount)")
                                                .font(.caption)
                                                .foregroundStyle(Zine.muted)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            groups = try await service.groups(kind: kind)
            selected = Set(try await service.memberships(kind: kind, targetID: targetID))
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggle(_ group: FavoriteGroup) async {
        errorMessage = nil
        do {
            if selected.contains(group.id) {
                selected = Set(try await service.removeMember(groupID: group.id, targetID: targetID))
            } else {
                selected = Set(try await service.addMember(groupID: group.id, targetID: targetID))
            }
            groups = try await service.groups(kind: kind)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
