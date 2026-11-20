import SwiftUI

@MainActor
struct CommunityPinsView: View {
    @Environment(\.dismiss) private var dismiss
    private let service: CommunityService
    private let onChanged: () -> Void
    @State private var snapshot: CommunityPinSnapshot?
    @State private var isLoading = false
    @State private var isMutating = false
    @State private var postIDInput = ""
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    init(service: CommunityService, onChanged: @escaping () -> Void) {
        self.service = service
        self.onChanged = onChanged
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "05.3",
                            title: "置顶管理",
                            subtitle: "最多 3 条；使用全局版本并发校验，冲突时请刷新核对。"
                        )
                        if let infoMessage, !infoMessage.isEmpty {
                            Text(infoMessage)
                                .font(.footnote)
                                .foregroundStyle(Zine.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if isLoading && snapshot == nil {
                            LoadingStateView(message: "正在读取置顶…")
                        } else if let snapshot {
                            pinList(snapshot)
                            addCard(snapshot)
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("置顶")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func pinList(_ snapshot: CommunityPinSnapshot) -> some View {
        VStack(spacing: 10) {
            if snapshot.items.isEmpty {
                EmptyStateView(title: "暂无置顶", message: "可在下方输入帖子 UUID 或从信息流卡片置顶。")
            } else {
                ForEach(snapshot.items.indices, id: \.self) { index in
                    let entry = snapshot.items[index]
                    PaperCard {
                        HStack(spacing: 8) {
                            Text("\(entry.position)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Zine.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Zine.ink)
                                Text("\(entry.userDisplayName) · \(entry.status)")
                                    .font(.caption)
                                    .foregroundStyle(Zine.muted)
                            }
                            Spacer()
                            Button("↑") {
                                Task { await move(snapshot, from: index, offset: -1) }
                            }
                            .disabled(index == 0 || isMutating)
                            Button("↓") {
                                Task { await move(snapshot, from: index, offset: 1) }
                            }
                            .disabled(index == snapshot.items.count - 1 || isMutating)
                            Button("取消") {
                                Task { await unpin(entry, revision: snapshot.revision) }
                            }
                            .foregroundStyle(Zine.red)
                            .disabled(isMutating)
                        }
                    }
                }
            }
        }
    }

    private func addCard(_ snapshot: CommunityPinSnapshot) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("置顶一篇已通过食记")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                TextField("帖子 UUID", text: $postIDInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .modifier(FormInputStyle())
                Button("置顶") {
                    Task { await pin(snapshot) }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(isMutating || postIDInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            snapshot = try await service.pins(manage: true)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pin(_ snapshot: CommunityPinSnapshot) async {
        let id = postIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        isMutating = true
        errorMessage = nil
        infoMessage = nil
        defer { isMutating = false }
        do {
            self.snapshot = try await service.pin(postID: id, expectedRevision: snapshot.revision)
            postIDInput = ""
            infoMessage = "已置顶。"
            onChanged()
        } catch let error as AppError {
            errorMessage = error.code == "PIN_CONFLICT"
                ? "置顶清单已变化，请关闭后重新打开核对"
                : error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unpin(_ entry: CommunityPinEntry, revision: Int) async {
        isMutating = true
        errorMessage = nil
        infoMessage = nil
        defer { isMutating = false }
        do {
            snapshot = try await service.unpin(postID: entry.id, expectedRevision: revision)
            infoMessage = "已取消置顶。"
            onChanged()
        } catch let error as AppError {
            errorMessage = error.code == "PIN_CONFLICT"
                ? "置顶清单已变化，请关闭后重新打开核对"
                : error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func move(_ snapshot: CommunityPinSnapshot, from index: Int, offset: Int) async {
        let target = index + offset
        guard snapshot.items.indices.contains(index), snapshot.items.indices.contains(target) else {
            return
        }
        var ids = snapshot.items.map(\.id)
        ids.swapAt(index, target)
        isMutating = true
        errorMessage = nil
        infoMessage = nil
        defer { isMutating = false }
        do {
            self.snapshot = try await service.reorderPins(
                postIDs: ids,
                expectedRevision: snapshot.revision
            )
            infoMessage = "顺序已保存。"
            onChanged()
        } catch let error as AppError {
            errorMessage = error.code == "PIN_CONFLICT"
                ? "置顶清单已变化，请关闭后重新打开核对"
                : error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
