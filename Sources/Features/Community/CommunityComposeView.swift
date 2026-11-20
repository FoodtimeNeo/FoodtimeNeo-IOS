import SwiftUI
import UIKit

@MainActor
struct CommunityComposeView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: CommunityComposeViewModel
    @State private var showPicker = false
    private let onSubmitted: () -> Void

    init(community: CommunityService, submissions: SubmissionService, onSubmitted: @escaping () -> Void) {
        _model = StateObject(
            wrappedValue: CommunityComposeViewModel(
                community: community,
                submissions: submissions
            )
        )
        self.onSubmitted = onSubmitted
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 16) {
                        SectionHeading(
                            index: "05.1",
                            title: "写食记",
                            subtitle: "标题 1–50、正文 1–2000、最多 9 张本人图片；提交后进入审核。"
                        )
                        if let receipt = model.receipt {
                            successCard(receipt)
                        } else {
                            formCard
                        }
                    }
                    .padding(Zine.pagePadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("写食记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showPicker) {
                MultiPhotoPicker(selectionLimit: 9) { images in
                    model.setImages(images)
                }
            }
        }
    }

    private var formCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("标题")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                TextField("1–50 字", text: $model.title)
                    .modifier(FormInputStyle())

                Text("正文")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                TextEditor(text: $model.content)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                    .overlay(
                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                            .stroke(Zine.border, lineWidth: 1)
                    )
                    .onChange(of: model.content) { _, value in
                        if value.count > 2000 {
                            model.content = String(value.prefix(2000))
                        }
                    }
                Text("\(model.content.count)/2000")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)

                Text("图片（最多 9 张）")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                if !model.images.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        ForEach(model.images.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: model.images[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 86, height: 86)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: Zine.smallRadius))
                                Button {
                                    model.removeImage(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, Zine.red)
                                }
                                .buttonStyle(.plain)
                                .padding(3)
                            }
                        }
                    }
                }
                Button("添加图片") { showPicker = true }
                    .buttonStyle(InkButtonStyle())

                if let error = model.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Zine.red)
                }

                Button {
                    Task { await model.submit() }
                } label: {
                    if model.isSubmitting {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("提交食记")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isSubmitting)
            }
        }
    }

    private func successCard(_ receipt: CommunityPostReceipt) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("食记已提交")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("食记正在审核，通过后会出现在社区。可以稍后刷新查看。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                Button("完成") {
                    onSubmitted()
                    dismiss()
                }
                .buttonStyle(InkButtonStyle(primary: true))
            }
        }
    }
}
