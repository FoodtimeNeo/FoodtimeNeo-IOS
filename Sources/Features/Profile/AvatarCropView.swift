import SwiftUI
import UIKit

@MainActor
struct AvatarCropView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    private let avatar: AvatarService
    private let onUploaded: (String) -> Void

    @State private var zoom: CGFloat = 1
    @State private var panX: CGFloat = 0
    @State private var panY: CGFloat = 0
    @State private var rotation = 0
    @State private var viewportSize: CGSize = .zero
    @State private var lastDrag: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1
    @State private var isUploading = false
    @State private var errorMessage: String?

    init(
        image: UIImage,
        avatar: AvatarService,
        onUploaded: @escaping (String) -> Void
    ) {
        self.image = image
        self.avatar = avatar
        self.onUploaded = onUploaded
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    SectionHeading(
                        index: "03.1",
                        title: "裁剪头像",
                        subtitle: "固定 1:1 方形选框，拖动或双指缩放图片。"
                    )
                    cropArea
                        .frame(height: 320)
                    HStack {
                        Text(String(format: "缩放 · %.2f×", zoom))
                            .font(.footnote)
                            .foregroundStyle(Zine.muted)
                        Slider(value: $zoom, in: 1...4)
                            .tint(Zine.red)
                    }
                    HStack(spacing: 12) {
                        Button("旋转 90°") {
                            rotation = (rotation + 90) % 360
                            panX = 0
                            panY = 0
                        }
                        .buttonStyle(InkButtonStyle())
                        Button("重置") {
                            reset()
                        }
                        .buttonStyle(InkButtonStyle())
                    }
                    Text("导出 512×512 方形头像；保存资料后才会更新。")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(Zine.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        Task { await upload() }
                    } label: {
                        if isUploading {
                            ProgressView().tint(Zine.onRed)
                        } else {
                            Text("使用此头像")
                        }
                    }
                    .buttonStyle(InkButtonStyle(primary: true))
                    .disabled(isUploading)
                    Button("取消") { dismiss() }
                        .buttonStyle(InkButtonStyle())
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("裁剪头像")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
    }

    private var cropArea: some View {
        GeometryReader { geo in
            let size = geo.size
            let layout = AvatarCropGeometry.calculate(
                imageWidth: image.size.width,
                imageHeight: image.size.height,
                viewportWidth: size.width,
                viewportHeight: size.height,
                rotation: rotation,
                zoom: zoom,
                panX: panX,
                panY: panY
            )
            ZStack {
                Zine.bar
                Image(uiImage: image)
                    .resizable()
                    .frame(width: image.size.width, height: image.size.height)
                    .scaleEffect(layout.scale)
                    .rotationEffect(.degrees(Double(rotation)))
                    .offset(x: layout.panX, y: layout.panY)
                    .frame(width: layout.side, height: layout.side)
                    .clipped()
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: layout.side, height: layout.side)
                    .allowsHitTesting(false)
                Path { path in
                    let third = layout.side / 3
                    for index in 1...2 {
                        let offset = third * CGFloat(index)
                        path.move(to: CGPoint(x: layout.side / 2 - layout.side / 2 + offset, y: 0))
                        path.addLine(to: CGPoint(x: offset, y: layout.side))
                        path.move(to: CGPoint(x: 0, y: offset))
                        path.addLine(to: CGPoint(x: layout.side, y: offset))
                    }
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                .frame(width: layout.side, height: layout.side)
                .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard layout.side > 0 else { return }
                        let dx = (value.translation.width - lastDrag.width) / layout.side
                        let dy = (value.translation.height - lastDrag.height) / layout.side
                        panX = max(-1, min(1, panX + dx))
                        panY = max(-1, min(1, panY + dy))
                        lastDrag = value.translation
                    }
                    .onEnded { _ in
                        lastDrag = .zero
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let delta = value.magnification / max(0.1, lastMagnification)
                        zoom = max(1, min(4, zoom * delta))
                        lastMagnification = value.magnification
                    }
                    .onEnded { _ in
                        lastMagnification = 1
                    }
            )
            .onAppear {
                viewportSize = size
            }
            .onChange(of: size) { _, newValue in
                viewportSize = newValue
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Zine.cardRadius)
                .fill(Zine.alt)
        )
        .clipShape(RoundedRectangle(cornerRadius: Zine.cardRadius))
    }

    private func reset() {
        zoom = 1
        rotation = 0
        panX = 0
        panY = 0
        lastDrag = .zero
        lastMagnification = 1
    }

    private func upload() async {
        guard !isUploading else { return }
        guard viewportSize.width > 32, viewportSize.height > 32 else {
            errorMessage = "请等待图片布局完成后再试"
            return
        }
        guard let data = AvatarCropRenderer.exportJPEG(
            image: image,
            rotation: rotation,
            zoom: zoom,
            panX: panX,
            panY: panY,
            viewportWidth: viewportSize.width,
            viewportHeight: viewportSize.height
        ) else {
            errorMessage = "头像处理失败，请重新选择图片"
            return
        }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        do {
            let uploaded = try await avatar.uploadAvatar(data)
            onUploaded(uploaded.imageUrl)
            dismiss()
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
