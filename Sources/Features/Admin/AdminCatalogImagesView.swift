import SwiftUI

@MainActor
struct AdminCatalogImagesView: View {
    @StateObject private var model: AdminCatalogImagesViewModel
    @State private var showPicker = false
    @State private var pendingDelete: AdminCatalogImage?
    @State private var showDeleteAlert = false
    private let mediaBaseURL: URL

    init(
        service: AdminService,
        uploader: SubmissionService,
        kind: AdminCatalogKind,
        item: AdminCatalogItem,
        mediaBaseURL: URL
    ) {
        _model = StateObject(
            wrappedValue: AdminCatalogImagesViewModel(
                service: service,
                uploader: uploader,
                kind: kind,
                item: item
            )
        )
        self.mediaBaseURL = mediaBaseURL
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeading(
                        index: "08.6.1",
                        title: model.kind == .diningHalls ? "食堂封面" : "\(model.kind.title)图片",
                        subtitle: "先上传图片再引用；食堂只保留封面，移除不删除其他位置使用的文件。"
                    )
                    Text(model.item.name)
                        .font(.system(size: 19, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        showPicker = true
                    } label: {
                        if model.isUploading {
                            ProgressView().tint(Zine.onRed)
                        } else {
                            Text(model.images.isEmpty ? "添加图片" : "再添加一张")
                        }
                    }
                    .buttonStyle(InkButtonStyle(primary: true))
                    .disabled(model.isUploading)

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

                    if model.isLoading && model.images.isEmpty {
                        LoadingStateView(message: "正在读取图片…")
                    } else if model.images.isEmpty {
                        EmptyStateView(title: "暂未添加图片", message: nil)
                    } else {
                        ForEach(model.images) { image in
                            imageCard(image)
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
        .navigationTitle("图片管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(page: 1) }
        .sheet(isPresented: $showPicker) {
            PhotoPicker { image in
                Task { _ = await model.add(image) }
            }
        }
        .alert("移除这张图片？", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { pendingDelete = nil }
            Button("移除", role: .destructive) {
                guard let image = pendingDelete else { return }
                Task {
                    _ = await model.remove(image)
                    pendingDelete = nil
                }
            }
        } message: {
            Text("仅从当前目录移除引用，不删除其他位置使用的文件。")
        }
    }

    private func imageCard(_ image: AdminCatalogImage) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                if let url = MediaURL.resolve(image.imageUrl, baseURL: mediaBaseURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let loaded):
                            loaded
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            imagePlaceholder("图片加载失败")
                        default:
                            imagePlaceholder("正在加载…")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Zine.smallRadius))
                } else {
                    imagePlaceholder("无效图片地址")
                }
                HStack {
                    Text(image.imageUrl)
                        .font(.caption2)
                        .foregroundStyle(Zine.muted)
                        .lineLimit(2)
                    Spacer()
                    Button("移除") {
                        pendingDelete = image
                        showDeleteAlert = true
                    }
                    .buttonStyle(LinkButtonStyle())
                    .disabled(model.deletingID == image.id)
                }
            }
        }
    }

    private func imagePlaceholder(_ text: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.alt)
            Text(text)
                .font(.caption)
                .foregroundStyle(Zine.muted)
        }
    }
}
