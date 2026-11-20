import SwiftUI

@MainActor
struct ReportReasonView: View {
    @Environment(\.dismiss) private var dismiss
    let targetType: String
    let targetID: String
    private let service: ReportService
    private let onSubmitted: (() -> Void)?
    @State private var reason = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    init(
        targetType: String,
        targetID: String,
        service: ReportService,
        onSubmitted: (() -> Void)? = nil
    ) {
        self.targetType = targetType
        self.targetID = targetID
        self.service = service
        self.onSubmitted = onSubmitted
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(prompt)
                            .font(.subheadline)
                            .foregroundStyle(Zine.muted)
                        TextEditor(text: $reason)
                            .frame(minHeight: 120, maxHeight: 200)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                            .overlay(
                                RoundedRectangle(cornerRadius: Zine.smallRadius)
                                    .stroke(Zine.border, lineWidth: 1)
                            )
                            .onChange(of: reason) { _, value in
                                if value.count > 500 {
                                    reason = String(value.prefix(500))
                                }
                            }
                        Text("\(reason.count)/500")
                            .font(.caption)
                            .foregroundStyle(Zine.muted)
                        if let errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                        }
                        Button {
                            Task { await submit() }
                        } label: {
                            if isSending {
                                ProgressView().tint(Zine.onRed)
                            } else {
                                Text("提交举报")
                            }
                        }
                        .buttonStyle(InkButtonStyle(primary: true))
                        .disabled(isSending)
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("举报")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var prompt: String {
        targetType == "message"
            ? "平台管理员会收到所选私信及举报说明。"
            : "请说明内容违反了哪些社区规则。"
    }

    private func submit() async {
        guard !isSending else { return }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请输入举报说明"
            return
        }
        guard trimmed.count <= 500 else {
            errorMessage = "举报说明不能超过 500 字"
            return
        }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await service.submitReport(
                targetType: targetType,
                targetID: targetID,
                reason: trimmed
            )
            onSubmitted?()
            dismiss()
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
