import SwiftUI

private enum AdminNoticeSheet: Identifiable {
    case create
    case edit(AdminNotice)
    case schedule(AdminNotice)
    case settings

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let notice): return "edit-\(notice.id)"
        case .schedule(let notice): return "schedule-\(notice.id)"
        case .settings: return "settings"
        }
    }
}

@MainActor
struct AdminNoticesView: View {
    @StateObject private var model: AdminNoticesViewModel
    @State private var sheet: AdminNoticeSheet?
    @State private var pendingDelete: AdminNotice?
    @State private var showDeleteAlert = false
    private let service: AdminService

    init(service: AdminService) {
        self.service = service
        _model = StateObject(wrappedValue: AdminNoticesViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "08.9",
                        title: "公告管理",
                        subtitle: "Markdown 首个标题作为公告标题；排期与登录弹窗分开设置。"
                    )
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Zine.muted)
                        TextField("搜索标题或正文", text: $model.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await model.load(page: 1) } }
                            .onChange(of: model.query) { _, _ in
                                model.queryChanged()
                            }
                    }
                    .modifier(FormInputStyle())
                    HStack(spacing: 10) {
                        Button("新建公告") { sheet = .create }
                            .buttonStyle(InkButtonStyle(primary: true))
                        Button("登录弹窗设置") { sheet = .settings }
                            .buttonStyle(InkButtonStyle())
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

                    if model.isLoading && model.notices.isEmpty {
                        LoadingStateView(message: "正在读取公告…")
                    } else if model.notices.isEmpty {
                        EmptyStateView(title: "没有公告", message: nil)
                    } else {
                        ForEach(model.notices) { notice in
                            noticeCard(notice)
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
        .navigationTitle("公告管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(page: 1) }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .create:
                AdminNoticeEditorView(service: service, existing: nil) { message in
                    model.changed(message)
                }
            case .edit(let notice):
                AdminNoticeEditorView(service: service, existing: notice) { message in
                    model.changed(message)
                }
            case .schedule(let notice):
                AdminNoticeScheduleView(service: service, notice: notice) { message in
                    model.changed(message)
                }
            case .settings:
                AdminNoticeSettingsView(service: service)
            }
        }
        .alert("删除该公告？", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { pendingDelete = nil }
            Button("删除", role: .destructive) {
                guard let notice = pendingDelete else { return }
                Task {
                    _ = await model.delete(notice)
                    pendingDelete = nil
                }
            }
        } message: {
            Text("硬删除并级联删除已读记录，不可恢复。")
        }
    }

    private func noticeCard(_ notice: AdminNotice) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(notice.title.isEmpty ? "（无标题）" : notice.title)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(AdminNoticeStatusLabel.label(notice.status))
                        .font(.caption2)
                        .foregroundStyle(notice.enabled ? Zine.green : Zine.red)
                }
                Text("发布：\(DisplayFormat.dateTime(notice.publishedAt)) · seq \(notice.seq)")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
                HStack(spacing: 6) {
                    badge(notice.isUpdate ? "更新" : "普通", tint: notice.isUpdate ? Zine.blue : Zine.muted)
                    badge(notice.published ? "已发布" : "未发布", tint: notice.published ? Zine.green : Zine.muted)
                    badge(notice.enabled ? "启用" : "停用", tint: notice.enabled ? Zine.green : Zine.red)
                    if let expiresOn = notice.expiresOn {
                        badge("至 \(expiresOn)", tint: Zine.gold)
                    }
                }
                if let content = notice.content, !content.isEmpty {
                    Text(content)
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                        .lineLimit(3)
                }
                HStack(spacing: 14) {
                    Button("编辑") { sheet = .edit(notice) }
                        .buttonStyle(LinkButtonStyle())
                    Button("排期") { sheet = .schedule(notice) }
                        .buttonStyle(LinkButtonStyle())
                    Button("删除") {
                        pendingDelete = notice
                        showDeleteAlert = true
                    }
                    .buttonStyle(LinkButtonStyle())
                    .disabled(model.deletingID == notice.id)
                }
            }
        }
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Zine.alt))
            .foregroundStyle(tint)
    }
}

@MainActor
private struct AdminNoticeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AdminNoticeEditorViewModel
    let onSaved: (String) -> Void

    init(
        service: AdminService,
        existing: AdminNotice?,
        onSaved: @escaping (String) -> Void
    ) {
        _model = StateObject(
            wrappedValue: AdminNoticeEditorViewModel(service: service, existing: existing)
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
                            index: "08.9",
                            title: model.existing == nil ? "新建公告" : "编辑公告",
                            subtitle: "正文 ≤20000 字；首个非空 Markdown 标题作为标题。"
                        )
                        PaperCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Markdown 正文")
                                    .font(.footnote)
                                    .foregroundStyle(Zine.muted)
                                TextEditor(text: $model.content)
                                    .frame(minHeight: 240)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                                            .stroke(Zine.border, lineWidth: 1)
                                    )
                                scheduleSection
                                if let error = model.errorMessage, !error.isEmpty {
                                    Text(error)
                                        .font(.subheadline)
                                        .foregroundStyle(Zine.red)
                                }
                                Button {
                                    Task {
                                        if await model.save() {
                                            onSaved(
                                                model.existing == nil ? "已创建公告。" : "已保存公告。"
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
            .navigationTitle("公告编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        Text("排期")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Zine.ink)
        DatePicker("发布时间", selection: $model.publishedAt)
        Toggle("设置展示开始", isOn: $model.hasDisplayStart)
        if model.hasDisplayStart {
            DatePicker("展示开始", selection: $model.displayStartsAt)
        }
        Toggle("设置展示结束", isOn: $model.hasDisplayEnd)
        if model.hasDisplayEnd {
            DatePicker("展示结束", selection: $model.displayEndsAt)
        }
        Toggle("设置过期日期", isOn: $model.hasExpiry)
        if model.hasExpiry {
            DatePicker("过期日期", selection: $model.expiresOn, displayedComponents: .date)
        }
        Toggle("更新类公告", isOn: $model.isUpdate)
        Toggle("已发布", isOn: $model.published)
        Toggle("启用", isOn: $model.enabled)
    }
}

@MainActor
private struct AdminNoticeScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AdminNoticeScheduleViewModel
    let onSaved: (String) -> Void

    init(
        service: AdminService,
        notice: AdminNotice,
        onSaved: @escaping (String) -> Void
    ) {
        _model = StateObject(
            wrappedValue: AdminNoticeScheduleViewModel(service: service, notice: notice)
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
                            index: "08.9",
                            title: "公告排期",
                            subtitle: "展示窗口与过期日期只影响用户可见性，不改正文与已读标记。"
                        )
                        PaperCard {
                            VStack(alignment: .leading, spacing: 10) {
                                DatePicker("发布时间", selection: $model.publishedAt)
                                Toggle("设置展示开始", isOn: $model.hasDisplayStart)
                                if model.hasDisplayStart {
                                    DatePicker("展示开始", selection: $model.displayStartsAt)
                                }
                                Toggle("设置展示结束", isOn: $model.hasDisplayEnd)
                                if model.hasDisplayEnd {
                                    DatePicker("展示结束", selection: $model.displayEndsAt)
                                }
                                Toggle("设置过期日期", isOn: $model.hasExpiry)
                                if model.hasExpiry {
                                    DatePicker("过期日期", selection: $model.expiresOn, displayedComponents: .date)
                                }
                                Toggle("更新类公告", isOn: $model.isUpdate)
                                Toggle("已发布", isOn: $model.published)
                                Toggle("启用", isOn: $model.enabled)
                                if let error = model.errorMessage, !error.isEmpty {
                                    Text(error)
                                        .font(.subheadline)
                                        .foregroundStyle(Zine.red)
                                }
                                Button {
                                    Task {
                                        if await model.save() {
                                            onSaved("已更新公告排期。")
                                            dismiss()
                                        }
                                    }
                                } label: {
                                    if model.isSaving {
                                        ProgressView().tint(Zine.onRed)
                                    } else {
                                        Text("保存排期")
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
            .navigationTitle("公告排期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

@MainActor
private struct AdminNoticeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AdminNoticeSettingsViewModel
    @State private var saved = false

    init(service: AdminService) {
        _model = StateObject(wrappedValue: AdminNoticeSettingsViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "08.9",
                            title: "登录弹窗设置",
                            subtitle: "选择一条当前公告；不选则用户登录后不弹公告。"
                        )
                        PaperCard {
                            VStack(alignment: .leading, spacing: 10) {
                                if model.isLoading {
                                    ProgressView().tint(Zine.red)
                                } else {
                                    Picker("当前公告", selection: $model.selectedID) {
                                        Text("不弹公告").tag("")
                                        ForEach(model.notices) { notice in
                                            Text(notice.title.isEmpty ? notice.id : notice.title)
                                                .tag(notice.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Zine.ink)
                                }
                                if let error = model.errorMessage, !error.isEmpty {
                                    Text(error)
                                        .font(.subheadline)
                                        .foregroundStyle(Zine.red)
                                }
                                if saved {
                                    Text("已保存。")
                                        .font(.footnote)
                                        .foregroundStyle(Zine.green)
                                }
                                Button {
                                    Task {
                                        if await model.save() { saved = true }
                                    }
                                } label: {
                                    if model.isSaving {
                                        ProgressView().tint(Zine.onRed)
                                    } else {
                                        Text("保存设置")
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
            .navigationTitle("登录弹窗")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.load() }
        }
    }
}
