import SwiftUI

@MainActor
struct DishDetailView: View {
    @EnvironmentObject private var session: AppSession
    private let catalog: CatalogService
    @StateObject private var model: DishDetailViewModel
    @State private var showGallery = false
    @State private var galleryStart = 0

    init(dishID: String, catalog: CatalogService) {
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
        .task { await model.load() }
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
                if let rating = model.rating {
                    Text(DisplayFormat.score(rating.averageScore, reviewCount: rating.reviewCount))
                        .font(.subheadline)
                        .foregroundStyle(Zine.red)
                } else {
                    Text("暂无评分")
                        .font(.subheadline)
                        .foregroundStyle(Zine.muted)
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
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnification)
                    .simultaneousGesture(pan)
                    .onTapGesture(count: 2) { toggleZoom() }
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
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(5, max(1, lastScale * value.magnification))
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 {
                    resetZoom()
                }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
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

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if scale > 1 {
                resetZoom()
            } else {
                scale = 2.5
                lastScale = 2.5
                offset = .zero
                lastOffset = .zero
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
