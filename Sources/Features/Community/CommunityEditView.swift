import SwiftUI
import UIKit

@MainActor
struct CommunityEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: CommunityEditViewModel
    @State private var showPicker = false
    private let mediaBaseURL: URL
    private let onSaved: () -> Void

    init(
        post: CommunityPost,
        community: CommunityService,
        submissions: SubmissionService,
        mediaBaseURL: URL,
        onSaved: @escaping () -> Void
    ) {
        _model = StateObject(
            wrappedValue: CommunityEditViewModel(
                post: post,
                community: community,
                submissions: submissions
            )
        )
        self.mediaBaseURL = mediaBaseURL
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 16) {
                        SectionHeading(
                            index: "05.2",
                            title: "修改食记",
                            subtitle: "修改后立即隐藏并重新审核；互动、作者、原发布时间保持不变。"
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
            .navigationTitle("修改食记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showPicker) {
                MultiPhotoPicker(selectionLimit: max(1, model.remainingSlots)) { images in
                    model.addImages(images)
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
                    .onChange(of: model.title) { _, value in
                        if value.count > 50 { model.title = String(value.prefix(50)) }
                    }

                Text("正文")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                TextEditor(text: $model.content)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                    .overlay(RoundedRectangle(cornerRadius: Zine.smallRadius).stroke(Zine.border, lineWidth: 1))
                    .onChange(of: model.content) { _, value in
                        if value.count > 2000 { model.content = String(value.prefix(2000)) }
                    }

                Text("图片（\(model.existingURLs.count + model.pickedImages.count)/9）")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                    ForEach(model.existingURLs.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: MediaURL.resolve(model.existingURLs[index], baseURL: mediaBaseURL)) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Zine.alt
                                }
                            }
                            .frame(width: 86, height: 86)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: Zine.smallRadius))
                            Button {
                                model.removeExisting(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, Zine.red)
                            }
                            .buttonStyle(.plain)
                            .padding(3)
                        }
                    }
                    ForEach(model.pickedImages.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: model.pickedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 86, height: 86)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: Zine.smallRadius))
                            Button {
                                model.removePicked(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, Zine.red)
                            }
                            .buttonStyle(.plain)
                            .padding(3)
                        }
                    }
                }
                if model.remainingSlots > 0 {
                    Button("添加图片") { showPicker = true }
                        .buttonStyle(InkButtonStyle())
                }

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
                        Text("保存并重新审核")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isSubmitting)
            }
        }
    }

    private func successCard(_ receipt: CommunityEditReceipt) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(receipt.changed ? "修改已提交" : "内容没有变化")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text(receipt.changed
                     ? "食记已隐藏并重新审核，通过后恢复公开；互动与原发布时间保留。"
                     : "相同内容不会隐藏帖子或增加版本。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                Button("完成") {
                    onSaved()
                    dismiss()
                }
                .buttonStyle(InkButtonStyle(primary: true))
            }
        }
    }
}
