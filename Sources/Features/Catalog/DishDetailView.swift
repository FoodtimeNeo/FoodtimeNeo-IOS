import SwiftUI

@MainActor
struct DishDetailView: View {
    @EnvironmentObject private var session: AppSession
    private let catalog: CatalogService
    private let dishID: String
    @StateObject private var model: DishDetailViewModel
    @State private var showGallery = false
    @State private var galleryStart = 0
    @State private var isFavorited = false

    init(dishID: String, catalog: CatalogService) {
        self.dishID = dishID
        self.catalog = catalog
        _model = StateObject(
            wrappedValue: DishDetailViewModel(dishID: dishID, catalog: catalog)
        )
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    content
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle(model.detail?.name ?? "菜品详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load()
            isFavorited = (try? await session.favorites.dishFavoriteState(dishID: dishID)) ?? false
            if model.detail != nil {
                await session.recordHistory(kind: .dish, targetID: dishID)
            }
        }
        .fullScreenCover(isPresented: $showGallery) {
            DishGalleryView(urls: model.imageURLs, startIndex: galleryStart)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.detail == nil {
            LoadingStateView(message: "正在端上这道菜…")
        } else if let error = model.errorMessage, model.detail == nil {
            ErrorStateView(message: error) {
                Task { await model.load() }
            }
        } else if let detail = model.detail {
            hero(detail)
            infoCard(detail)
            NavigationLink {
                PriceHistoryView(dishID: detail.id, catalog: catalog)
            } label: {
                PaperCard {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(Zine.red)
                        Text("价格变化")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Zine.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Zine.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            NavigationLink {
                ImageSubmissionView(dishID: detail.id, dishName: detail.name)
            } label: {
                PaperCard {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .foregroundStyle(Zine.red)
                        Text("上传图片")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Zine.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Zine.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            NavigationLink {
                CorrectionFormView(
                    dish: detail,
                    corrections: session.corrections,
                    submissions: session.submissions
                )
            } label: {
                PaperCard {
                    HStack(spacing: 10) {
                        Image(systemName: "checklist")
                            .foregroundStyle(Zine.red)
                        Text("目录纠错")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Zine.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Zine.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            DishReviewsSection(session: session, dishID: detail.id)
            if !model.imageURLs.isEmpty {
                galleryStrip
            }
        }
    }

    private func hero(_ detail: DishDetail) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Zine.cardRadius)
                .fill(Zine.alt)
            if let url = model.imageURLs.first {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 36))
                            .foregroundStyle(Zine.muted)
                    default:
                        ProgressView().tint(Zine.red)
                    }
                }
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 42))
                    .foregroundStyle(Zine.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Zine.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Zine.cardRadius)
                .stroke(Zine.border, lineWidth: 1)
        )
        .onTapGesture {
            if !model.imageURLs.isEmpty {
                galleryStart = 0
                showGallery = true
            }
        }
        .accessibilityLabel(detail.name)
    }

    private func infoCard(_ detail: DishDetail) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(detail.name)
                        .font(.system(size: 26, weight: .black, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer(minLength: 8)
                    Text(DisplayFormat.price(detail.price))
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Zine.red)
                }
                Text("\(detail.diningHallName) · \(detail.stallName)")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                HStack {
                    if let rating = model.rating {
                        Text(DisplayFormat.score(rating.averageScore, reviewCount: rating.reviewCount))
                            .font(.subheadline)
                            .foregroundStyle(Zine.red)
                    } else {
                        Text("暂无评分")
                            .font(.subheadline)
                            .foregroundStyle(Zine.muted)
                    }
                    Spacer()
                    Button {
                        Task {
                            let next = !isFavorited
                            if let saved = try? await session.favorites.setDishFavorite(
                                dishID: detail.id,
                                favorited: next
                            ) {
                                isFavorited = saved
                            }
                        }
                    } label: {
                        Label(
                            isFavorited ? "已收藏" : "收藏",
                            systemImage: isFavorited ? "star.fill" : "star"
                        )
                        .font(.caption)
                        .foregroundStyle(isFavorited ? Zine.gold : Zine.muted)
                    }
                    .buttonStyle(.plain)
                }
                if let description = detail.description, !description.isEmpty {
                    Divider().overlay(Zine.border)
                    Text(description)
                        .font(.body)
                        .foregroundStyle(Zine.ink)
                }
            }
        }
    }

    private var galleryStrip: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("图册")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text("\(model.imageURLs.count) 张")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.imageURLs.indices, id: \.self) { index in
                            AsyncImage(url: model.imageURLs[index]) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Zine.alt
                                }
                            }
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: Zine.smallRadius))
                            .onTapGesture {
                                galleryStart = index
                                showGallery = true
                            }
                        }
                    }
                }
                Button("查看全部图片") {
                    galleryStart = 0
                    showGallery = true
                }
                .buttonStyle(LinkButtonStyle())
            }
        }
    }
}

@MainActor
struct DishGalleryView: View {
    let urls: [URL]
    let startIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(urls: [URL], startIndex: Int) {
        self.urls = urls
        self.startIndex = startIndex
        _index = State(initialValue: min(max(0, startIndex), max(0, urls.count - 1)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(urls.indices, id: \.self) { position in
                    ZoomableRemoteImage(url: urls[position])
                        .tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                }
                .accessibilityLabel("关闭图册")
                Spacer()
                Text("\(index + 1) / \(urls.count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
        }
        .statusBarHidden(true)
    }
}

@MainActor
private struct ZoomableRemoteImage: View {
    let url: URL
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let container = geo.size
            AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnification(container: container))
                        .simultaneousGesture(pan(container: container))
                        .simultaneousGesture(doubleTap(container: container))
                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 34))
                        Text("图片加载失败")
                            .font(.footnote)
                    }
                    .foregroundStyle(.white.opacity(0.8))
                default:
                    ProgressView().tint(.white)
                }
            }
            .frame(width: container.width, height: container.height)
        }
    }

    private func magnification(container: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let next = min(5, max(1, lastScale * value.magnification))
                scale = next
                offset = GalleryZoomGeometry.clampedOffset(
                    offset,
                    scale: next,
                    container: container
                )
            }
            .onEnded { _ in
                if scale <= 1.01 {
                    resetZoom()
                } else {
                    lastScale = scale
                    offset = GalleryZoomGeometry.clampedOffset(
                        offset,
                        scale: scale,
                        container: container
                    )
                    lastOffset = offset
                }
            }
    }

    private func pan(container: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = GalleryZoomGeometry.clampedOffset(
                    CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    ),
                    scale: scale,
                    container: container
                )
            }
            .onEnded { _ in
                if scale > 1 {
                    lastOffset = offset
                } else {
                    resetZoom()
                }
            }
    }

    private func doubleTap(container: CGSize) -> some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                if scale > 1 {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        resetZoom()
                    }
                } else {
                    let target: CGFloat = 2.5
                    let anchored = GalleryZoomGeometry.anchoredOffset(
                        tap: value.location,
                        container: container,
                        scale: target
                    )
                    withAnimation(.easeInOut(duration: 0.28)) {
                        scale = target
                        lastScale = target
                        offset = anchored
                        lastOffset = anchored
                    }
                }
            }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
