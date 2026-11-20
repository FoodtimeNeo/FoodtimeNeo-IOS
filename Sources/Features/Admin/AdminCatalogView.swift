import SwiftUI

private enum AdminCatalogEditorTarget: Identifiable {
    case create
    case edit(AdminCatalogItem)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let item): return item.id
        }
    }
}

@MainActor
struct AdminCatalogView: View {
    @StateObject private var model: AdminCatalogViewModel
    @State private var editorTarget: AdminCatalogEditorTarget?
    @State private var pendingDelete: AdminCatalogItem?
    @State private var showDeleteAlert = false
    private let service: AdminService
    private let uploader: SubmissionService?
    private let mediaBaseURL: URL?
    private let canManageImages: Bool

    init(
        service: AdminService,
        uploader: SubmissionService? = nil,
        mediaBaseURL: URL? = nil,
        canManageImages: Bool = false
    ) {
        self.service = service
        self.uploader = uploader
        self.mediaBaseURL = mediaBaseURL
        self.canManageImages = canManageImages
        _model = StateObject(wrappedValue: AdminCatalogViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "08.6",
                        title: "目录管理",
                        subtitle: "含停用记录；编辑不改所属；有关联时删除返回 409，可改为停用。"
                    )
                    Picker("类型", selection: $model.kind) {
                        ForEach(AdminCatalogKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    Button("新增\(model.kind.title)") {
                        editorTarget = .create
                    }
                    .buttonStyle(InkButtonStyle())

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
                        LoadingStateView(message: "正在读取目录…")
                    } else if model.items.isEmpty {
                        EmptyStateView(title: "暂无\(model.kind.title)", message: nil)
                    } else {
                        ForEach(model.items) { item in
                            itemCard(item)
                        }
                        if model.totalPages > 1 {
                            HStack {
                                Button("上一页") {
                                    Task { await model.load(page: model.page - 1) }
                                }
                                .buttonStyle(InkButtonStyle())
                                .disabled(model.page <= 1 || model.isLoading)
                                Text("第 \(model.page)/\(model.totalPages) 页")
                                    .font(.footnote)
                                    .foregroundStyle(Zine.muted)
                                Button("下一页") {
                                    Task { await model.load(page: model.page + 1) }
                                }
                                .buttonStyle(InkButtonStyle())
                                .disabled(model.page >= model.totalPages || model.isLoading)
                            }
                        }
                    }
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("目录管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(page: 1) }
        .sheet(item: $editorTarget) { target in
            AdminCatalogEditorView(
                service: service,
                kind: model.kind,
                existing: existingItem(for: target)
            ) { message in
                model.saved(message)
            }
        }
        .alert("删除该\(model.kind.title)？", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { pendingDelete = nil }
            Button("删除", role: .destructive) {
                guard let item = pendingDelete else { return }
                Task {
                    _ = await model.delete(item)
                    pendingDelete = nil
                }
            }
        } message: {
            Text("仍被引用的记录会被服务端拒绝；删除不可撤销，建议优先改为停用。")
        }
    }

    private func existingItem(for target: AdminCatalogEditorTarget) -> AdminCatalogItem? {
        if case .edit(let item) = target { return item }
        return nil
    }

    private func itemCard(_ item: AdminCatalogItem) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Text(item.status == "active" ? "启用" : "停用")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Zine.alt))
                        .foregroundStyle(item.status == "active" ? Zine.green : Zine.red)
                    Spacer()
                    Text("修订 \(item.revision)")
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                }
                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(Zine.ink)
                        .lineLimit(3)
                }
                if let price = item.price {
                    Text("价格：\(DisplayFormat.price(price))\(item.priceUnit.map { " / \($0)" } ?? "")")
                        .font(.caption)
                        .foregroundStyle(Zine.red)
                }
                if let parentId = item.parentId {
                    Text("所属：\(parentId) · 排序 \(item.sortOrder.map(String.init) ?? "-")")
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                } else {
                    Text("排序 \(item.sortOrder.map(String.init) ?? "-")")
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                }
                HStack(spacing: 14) {
                    Button("编辑") {
                        editorTarget = .edit(item)
                    }
                    .buttonStyle(LinkButtonStyle())
                    .disabled(model.deletingID == item.id)
                    if canManageImages, let uploader, let mediaBaseURL {
                        NavigationLink {
                            AdminCatalogImagesView(
                                service: service,
                                uploader: uploader,
                                kind: model.kind,
                                item: item,
                                mediaBaseURL: mediaBaseURL
                            )
                        } label: {
                            Text("图片")
                        }
                        .buttonStyle(LinkButtonStyle())
                    }
                    Button("删除") {
                        pendingDelete = item
                        showDeleteAlert = true
                    }
                    .buttonStyle(LinkButtonStyle())
                    .disabled(model.deletingID == item.id)
                }
            }
        }
    }
}

@MainActor
private struct AdminCatalogEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AdminCatalogEditorViewModel
    let onSaved: (String) -> Void

    init(
        service: AdminService,
        kind: AdminCatalogKind,
        existing: AdminCatalogItem?,
        onSaved: @escaping (String) -> Void
    ) {
        _model = StateObject(
            wrappedValue: AdminCatalogEditorViewModel(
                service: service,
                kind: kind,
                existing: existing
            )
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "08.6",
                            title: model.existing == nil ? "新增\(model.kind.title)" : "编辑\(model.kind.title)",
                            subtitle: "名称为必填；菜品价格必填；所属关系编辑时不可改。"
                        )
                        PaperCard {
                            VStack(alignment: .leading, spacing: 10) {
                                fieldLabel("名称")
                                TextField("名称", text: $model.name)
                                    .modifier(FormInputStyle())
                                fieldLabel("简介")
                                TextEditor(text: $model.descriptionText)
                                    .frame(minHeight: 70)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                                            .stroke(Zine.border, lineWidth: 1)
                                    )
                                if let parentKind = model.parentKind {
                                    fieldLabel("所属\(parentKind.title)")
                                    if model.isLoadingParents {
                                        ProgressView().tint(Zine.red)
                                    } else {
                                        Picker("所属\(parentKind.title)", selection: $model.parentID) {
                                            ForEach(model.parents) { parent in
                                                Text(parent.name).tag(parent.id)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(Zine.ink)
                                        .disabled(model.existing != nil)
                                    }
                                }
                                fieldLabel(model.kind.requiresPrice ? "价格（必填）" : "价格（可选）")
                                TextField("0.00", text: $model.priceText)
                                    .keyboardType(.decimalPad)
                                    .modifier(FormInputStyle())
                                fieldLabel("计价单位（可选）")
                                TextField("如 份 / 斤", text: $model.priceUnit)
                                    .modifier(FormInputStyle())
                                fieldLabel("状态")
                                Picker("状态", selection: $model.status) {
                                    Text("启用").tag("active")
                                    Text("停用").tag("inactive")
                                }
                                .pickerStyle(.segmented)
                                fieldLabel("排序（可选）")
                                TextField("0", text: $model.sortOrderText)
                                    .keyboardType(.numberPad)
                                    .modifier(FormInputStyle())
                                if let error = model.errorMessage, !error.isEmpty {
                                    Text(error)
                                        .font(.subheadline)
                                        .foregroundStyle(Zine.red)
                                }
                                Button {
                                    Task {
                                        if await model.save() {
                                            onSaved(
                                                model.existing == nil
                                                    ? "已新增\(model.kind.title)。"
                                                    : "已保存\(model.kind.title)。"
                                            )
                                            dismiss()
                                        }
                                    }
                                } label: {
                                    if model.isSaving {
                                        ProgressView().tint(Zine.onRed)
                                    } else {
                                        Text("保存")
                                    }
                                }
                                .buttonStyle(InkButtonStyle(primary: true))
                                .disabled(model.isSaving)
                            }
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("目录编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.loadParents() }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Zine.muted)
    }
}
