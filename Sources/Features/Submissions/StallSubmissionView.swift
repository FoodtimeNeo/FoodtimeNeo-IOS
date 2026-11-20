import SwiftUI
import UIKit

@MainActor
struct StallSubmissionView: View {
    @EnvironmentObject private var session: AppSession
    let hallID: String
    let hallName: String
    @State private var name = ""
    @State private var description = ""
    @State private var pickedImage: UIImage?
    @State private var showPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var receipt: CatalogSubmissionReceipt?

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeading(
                        index: "02.5",
                        title: "投稿档口",
                        subtitle: "提交到 \(hallName)；审核通过前不会出现在公开目录。"
                    )
                    if let receipt {
                        successCard(receipt)
                    } else {
                        formCard
                    }
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("投稿档口")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            PhotoPicker { pickedImage = $0 }
        }
    }

    private var formCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("档口名称（必填，最多 100 字）")
                TextField("例如：面食档口", text: $name)
                    .modifier(FormInputStyle())

                fieldLabel("简介（可选，最多 500 字）")
                TextEditor(text: $description)
                    .frame(minHeight: 80, maxHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                    .overlay(RoundedRectangle(cornerRadius: Zine.smallRadius).stroke(Zine.border, lineWidth: 1))

                fieldLabel("封面图片（必填）")
                if let image = pickedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: Zine.smallRadius))
                }
                Button("从相册选择封面") { showPicker = true }
                    .buttonStyle(InkButtonStyle())

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(Zine.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("提交投稿")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(isSubmitting)
            }
        }
    }

    private func successCard(_ receipt: CatalogSubmissionReceipt) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("投稿已提交")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("档口投稿正在审核，通过后进入正式目录。状态：\(SubmissionStatus.label(receipt.status))")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    private func submit() async {
        guard !isSubmitting else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { errorMessage = "请填写档口名称"; return }
        guard trimmedName.count <= 100 else { errorMessage = "档口名称不能超过 100 字"; return }
        guard description.count <= 500 else { errorMessage = "简介不能超过 500 字"; return }
        guard let image = pickedImage else { errorMessage = "请选择封面图片"; return }
        guard let data = ImageProcessor.jpegData(from: image) else {
            errorMessage = "图片处理失败，请重新选择"
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let uploaded = try await session.submissions.uploadImage(data)
            receipt = try await session.submissions.submitStall(
                hallID: hallID,
                name: trimmedName,
                description: description.isEmpty ? nil : description,
                coverImageURL: uploaded.imageUrl
            )
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(Zine.muted)
    }
}
