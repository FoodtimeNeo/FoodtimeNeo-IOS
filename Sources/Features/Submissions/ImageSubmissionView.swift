import SwiftUI
import UIKit

@MainActor
struct ImageSubmissionView: View {
    @EnvironmentObject private var session: AppSession
    let dishID: String
    let dishName: String
    @State private var pickedImage: UIImage?
    @State private var showPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var submitted: ImageSubmission?

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeading(
                        index: "02.3",
                        title: "上传图片",
                        subtitle: "图片先上传为私有暂存，再由管理员审核；\(dishName)"
                    )
                    if let submitted {
                        successCard(submitted)
                    } else {
                        formCard
                    }
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("上传图片")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            PhotoPicker { image in
                pickedImage = image
            }
        }
    }

    private var formCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                if let image = pickedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Zine.smallRadius))
                        .accessibilityLabel("已选择的图片")
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                            .fill(Zine.alt)
                        VStack(spacing: 6) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 30))
                                .foregroundStyle(Zine.muted)
                            Text("尚未选择图片")
                                .font(.footnote)
                                .foregroundStyle(Zine.muted)
                        }
                    }
                    .frame(height: 150)
                }

                Button("从相册选择") { showPicker = true }
                    .buttonStyle(InkButtonStyle())

                Text("图片会压缩到最长边 1600、JPEG 90% 后上传；支持 JPEG/PNG/HEIC 输入，服务端只接受 JPEG/PNG。")
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
                    if isSubmitting {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("上传并投稿")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(isSubmitting || pickedImage == nil)
            }
        }
    }

    private func successCard(_ submission: ImageSubmission) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("图片已投稿")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("图片正在审核，通过后会进入公开图册。状态：\(submission.statusLabel)")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    private func submit() async {
        guard !isSubmitting, let image = pickedImage else { return }
        guard let data = ImageProcessor.jpegData(from: image) else {
            errorMessage = "图片处理失败，请重新选择"
            return
        }
        if data.count > 10 * 1024 * 1024 {
            errorMessage = "压缩后图片仍超过 10MB，请换一张更小的图片"
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let uploaded = try await session.submissions.uploadImage(data)
            submitted = try await session.submissions.submitDishImage(
                dishID: dishID,
                imageURL: uploaded.imageUrl
            )
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
