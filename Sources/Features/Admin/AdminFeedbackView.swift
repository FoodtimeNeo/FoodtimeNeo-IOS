import Foundation
import SwiftUI
import UniformTypeIdentifiers

private struct FeedbackCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

@MainActor
struct AdminFeedbackView: View {
    @StateObject private var model: AdminFeedbackViewModel
    @State private var selected: AdminFeedbackRow?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: FeedbackCSVDocument?
    @State private var exportFilename = "feedback.csv"
    private let service: AdminService

    init(service: AdminService) {
        self.service = service
        _model = StateObject(wrappedValue: AdminFeedbackViewModel(service: service))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "08.10",
                        title: "反馈管理",
                        subtitle: "CSV 五列、UTF-8 BOM、CRLF；导出会把待处理转为处理中。"
                    )
                    Picker("归档", selection: $model.archived) {
                        Text("未归档").tag(false)
                        Text("已归档").tag(true)
                    }
                    .pickerStyle(.segmented)
                    HStack(spacing: 10) {
                        Button {
                            Task {
                                if let result = await model.export() {
                                    exportFilename = result.filename
                                    exportDocument = FeedbackCSVDocument(text: result.csv)
                                    showExporter = true
                                }
                            }
                        } label: {
                            if model.isExporting {
                                ProgressView().tint(Zine.onRed)
                            } else {
                                Text("导出 CSV")
                            }
                        }
                        .buttonStyle(InkButtonStyle(primary: true))
                        .disabled(model.isExporting || model.isImporting)
                        Button("导入 CSV") { showImporter = true }
                            .buttonStyle(InkButtonStyle())
                            .disabled(model.isExporting || model.isImporting)
                    }
                    Text("导出副作用：服务端会先把 pending 转为 processing，即使随后取消保存也不会回滚。")
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                    if let result = model.importResult, !result.issues.isEmpty {
                        PaperCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("导入问题")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Zine.ink)
                                ForEach(result.issues) { issue in
                                    Text("第 \(issue.row) 行：\(issue.message)")
                                        .font(.caption)
                                        .foregroundStyle(Zine.red)
                                }
                            }
                        }
                    }

                    if model.isLoading && model.rows.isEmpty {
                        LoadingStateView(message: "正在读取反馈…")
                    } else if model.rows.isEmpty {
                        EmptyStateView(title: "没有反馈", message: nil)
                    } else {
                        ForEach(model.rows) { row in
                            Button {
                                selected = row
                            } label: {
                                feedbackCard(row)
                            }
                            .buttonStyle(.plain)
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
        .navigationTitle("反馈管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(page: 1) }
        .sheet(item: $selected) { row in
            AdminFeedbackDetailView(service: service, row: row) { message in
                model.changed(message)
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                model.errorMessage = "保存 CSV 失败：\(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText]
        ) { result in
            switch result {
            case .success(let url):
                let started = url.startAccessingSecurityScopedResource()
                defer {
                    if started { url.stopAccessingSecurityScopedResource() }
                }
                do {
                    let data = try Data(contentsOf: url)
                    guard let csv = String(data: data, encoding: .utf8) else {
                        model.errorMessage = "CSV 不是有效的 UTF-8 文本"
                        return
                    }
                    Task { await model.importCSV(csv) }
                } catch {
                    model.errorMessage = "读取 CSV 失败：\(error.localizedDescription)"
                }
            case .failure(let error):
                model.errorMessage = "选择 CSV 失败：\(error.localizedDescription)"
            }
        }
    }

    private func feedbackCard(_ row: AdminFeedbackRow) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(typeLabel(row.type))
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(statusLabel(row.status))
                        .font(.caption2)
                        .foregroundStyle(row.status == "completed" ? Zine.green : Zine.gold)
                }
                Text(row.content)
                    .font(.subheadline)
                    .foregroundStyle(Zine.ink)
                    .lineLimit(5)
                if let user = row.userDisplayName {
                    Text(user)
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                if let reply = row.latestReply, !reply.isEmpty {
                    Text("最近处理建议：\(reply)")
                        .font(.caption)
                        .foregroundStyle(Zine.blue)
                        .lineLimit(2)
                }
                Text(DisplayFormat.dateTime(row.createdAt))
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    private func typeLabel(_ type: String) -> String {
        switch type {
        case "function": return "功能反馈"
        case "content": return "内容反馈"
        case "usage": return "使用反馈"
        case "suggestion": return "改进建议"
        case "other": return "其他"
        default: return type
        }
    }

    private func statusLabel(_ status: String) -> String {
        AdminFeedbackStatus(rawValue: status)?.title ?? status
    }
}

@MainActor
private struct AdminFeedbackDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AdminFeedbackDetailViewModel
    @State private var status: String
    @State private var reply = ""
    let onChanged: (String) -> Void

    init(
        service: AdminService,
        row: AdminFeedbackRow,
        onChanged: @escaping (String) -> Void
    ) {
        _model = StateObject(
            wrappedValue: AdminFeedbackDetailViewModel(service: service, row: row)
        )
        _status = State(initialValue: row.status)
        self.onChanged = onChanged
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "08.10",
                            title: "反馈详情",
                            subtitle: "处理建议会作为公开回复；可同时更新状态。"
                        )
                        if model.isLoading && model.replies.isEmpty {
                            LoadingStateView(message: "正在读取反馈…")
                        }
                        contentCard
                        if let error = model.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        updateCard
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("反馈详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.load() }
        }
    }

    private var contentCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.row.content)
                    .font(Zine.bodyFont)
                    .foregroundStyle(Zine.ink)
                    .textSelection(.enabled)
                if let user = model.row.userDisplayName {
                    Text("用户：\(user)")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
                Text("类型：\(model.row.type) · 状态：\(model.row.status)")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                Text("提交：\(DisplayFormat.dateTime(model.row.createdAt)) · 更新：\(DisplayFormat.dateTime(model.row.updatedAt))")
                    .font(.caption2)
                    .foregroundStyle(Zine.muted)
                if !model.replies.isEmpty {
                    Text("回复记录")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Zine.ink)
                        .padding(.top, 4)
                    ForEach(model.replies) { reply in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reply.content)
                                .font(.subheadline)
                                .foregroundStyle(Zine.ink)
                            Text(DisplayFormat.dateTime(reply.createdAt))
                                .font(.caption2)
                                .foregroundStyle(Zine.muted)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.alt)
                        )
                    }
                }
            }
        }
    }

    private var updateCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("处理")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Picker("状态", selection: $status) {
                    ForEach(AdminFeedbackStatus.allCases) { value in
                        Text(value.title).tag(value.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Text("处理建议（公开回复，可选 ≤5000）")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                TextEditor(text: $reply)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                            .stroke(Zine.border, lineWidth: 1)
                    )
                Button {
                    Task { await submit() }
                } label: {
                    if model.isSubmitting {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("保存处理")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isSubmitting)
            }
        }
    }

    private func submit() async {
        if await model.update(reply: reply, status: status) {
            onChanged("已更新反馈。")
            dismiss()
        }
    }
}
