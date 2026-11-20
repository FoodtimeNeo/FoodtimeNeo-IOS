import SwiftUI
import UIKit

@MainActor
struct DishSubmissionView: View {
    @EnvironmentObject private var session: AppSession
    let stallID: String
    let stallName: String
    @State private var name = ""
    @State private var description = ""
    @State private var price = ""
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
                        index: "02.4",
                        title: "投稿菜品",
                        subtitle: "提交到 \(stallName)；审核通过前不会出现在公开目录。"
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
        .navigationTitle("投稿菜品")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            PhotoPicker { pickedImage = $0 }
        }
    }

    private var formCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("菜品名称（必填，最多 120 字）")
                TextField("例如：红烧肉", text: $name)
                    .modifier(FormInputStyle())

                fieldLabel("简介（可选，最多 500 字）")
                TextEditor(text: $description)
                    .frame(minHeight: 80, maxHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                    .overlay(RoundedRectangle(cornerRadius: Zine.smallRadius).stroke(Zine.border, lineWidth: 1))

                fieldLabel("参考价格（可选，最多两位小数）")
                TextField("例如：12.50", text: $price)
                    .keyboardType(.decimalPad)
                    .modifier(FormInputStyle())

                fieldLabel("菜品图片（必填）")
                if let image = pickedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: Zine.smallRadius))
                }
                Button("从相册选择图片") { showPicker = true }
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
                Text("菜品投稿正在审核，通过后进入正式目录。状态：\(SubmissionStatus.label(receipt.status))")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    private func submit() async {
        guard !isSubmitting else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { errorMessage = "请填写菜品名称"; return }
        guard trimmedName.count <= 120 else { errorMessage = "菜品名称不能超过 120 字"; return }
        guard description.count <= 500 else { errorMessage = "简介不能超过 500 字"; return }
        guard let image = pickedImage else { errorMessage = "请选择菜品图片"; return }

        var parsedPrice: Decimal?
        let priceText = price.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        if !priceText.isEmpty {
            guard let value = Decimal(string: priceText, locale: Locale(identifier: "en_US_POSIX")), value >= 0 else {
                errorMessage = "参考价格式不正确或为负数"
                return
            }
            parsedPrice = value
        }
        guard let data = ImageProcessor.jpegData(from: image) else {
            errorMessage = "图片处理失败，请重新选择"
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let uploaded = try await session.submissions.uploadImage(data)
            receipt = try await session.submissions.submitDish(
                stallID: stallID,
                name: trimmedName,
                description: description.isEmpty ? nil : description,
                price: parsedPrice,
                imageURL: uploaded.imageUrl
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
