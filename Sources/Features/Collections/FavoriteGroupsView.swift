import SwiftUI

@MainActor
struct FavoriteGroupsView: View {
    @Environment(\.dismiss) private var dismiss
    private let service: FavoriteService
    private let kind: FavoriteKind
    private let onChanged: () -> Void
    @State private var groups: [FavoriteGroup] = []
    @State private var newName = ""
    @State private var errorMessage: String?
    @State private var renameTarget: FavoriteGroup?
    @State private var renameName = ""
    @State private var deleteTarget: FavoriteGroup?

    init(service: FavoriteService, kind: FavoriteKind, onChanged: @escaping () -> Void) {
        self.service = service
        self.kind = kind
        self.onChanged = onChanged
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 12) {
                        SectionHeading(
                            index: "06.1",
                            title: "\(kind.label)分组",
                            subtitle: "名称 1–20 字符；删除分组不会删除收藏。"
                        )
                        if let errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(groups) { group in
                            PaperCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Zine.ink)
                                        Text("\(group.itemCount) 项 · 版本 \(group.revision)")
                                            .font(.caption)
                                            .foregroundStyle(Zine.muted)
                                    }
                                    Spacer()
                                    Button("重命名") {
                                        renameTarget = group
                                        renameName = group.name
                                    }
                                    .buttonStyle(LinkButtonStyle())
                                    Button("删除") { deleteTarget = group }
                                        .buttonStyle(LinkButtonStyle())
                                }
                            }
                        }
                        PaperCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("新建分组")
                                    .font(.system(size: 17, weight: .bold, design: .serif))
                                    .foregroundStyle(Zine.ink)
                                TextField("1–20 字符", text: $newName)
                                    .modifier(FormInputStyle())
                                Button("创建") {
                                    Task { await create() }
                                }
                                .buttonStyle(InkButtonStyle(primary: true))
                                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("管理分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await reload() }
            .alert("重命名分组", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("名称", text: $renameName)
                Button("保存") { Task { await rename() } }
                Button("取消", role: .cancel) { renameTarget = nil }
            }
            .alert("删除分组？", isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            )) {
                Button("删除", role: .destructive) { Task { await delete() } }
                Button("取消", role: .cancel) { deleteTarget = nil }
            } message: {
                Text("仅删除分组关系，已收藏内容仍保留为未分组。")
            }
        }
    }

    private func reload() async {
        errorMessage = nil
        do {
            groups = try await service.groups(kind: kind)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func create() async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            _ = try await service.createGroup(kind: kind, name: name, sortOrder: groups.count)
            newName = ""
            await reload()
            onChanged()
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rename() async {
        guard let target = renameTarget else { return }
        let name = renameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            _ = try await service.updateGroup(
                id: target.id,
                name: name,
                sortOrder: target.sortOrder,
                expectedRevision: target.revision
            )
            renameTarget = nil
            await reload()
            onChanged()
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        guard let target = deleteTarget else { return }
        do {
            try await service.deleteGroup(id: target.id)
            deleteTarget = nil
            await reload()
            onChanged()
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
