import SwiftUI
import UIKit

@MainActor
struct CampusMapView: View {
    @StateObject private var model: CampusMapViewModel
    private let catalog: CatalogService
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero

    init(catalog: CatalogService) {
        self.catalog = catalog
        _model = StateObject(wrappedValue: CampusMapViewModel(catalog: catalog))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    SectionHeading(
                        index: "01.2",
                        title: "食堂地图",
                        subtitle: "双指缩放、拖动地图，点选食堂查看详情。"
                    )
                    content
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("食堂地图")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.data == nil {
            LoadingStateView(message: "正在铺开校园地图…")
        } else if let error = model.errorMessage, model.data == nil {
            ErrorStateView(message: error) {
                Task { await model.load() }
            }
        } else if let data = model.data, let image = model.image {
            mapCard(data: data, image: image)
            controls
            regionButtons(data)
            selectionDetails(data)
            Text("校园手绘示意图（2023 年更新）。暂未标注教工、学苑及东区清真；暂不提供定位和路线导航。地图底图来源与再分发许可待确认。")
                .font(.caption)
                .foregroundStyle(Zine.muted)
        }
    }

    private func mapCard(data: CampusMapData, image: UIImage) -> some View {
        ZStack(alignment: .bottomTrailing) {
            CampusMapCanvas(
                data: data,
                image: image,
                selectedID: model.selectedRegionID,
                zoom: $zoom,
                offset: $offset
            ) { region in
                model.select(region)
            }
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: Zine.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Zine.cardRadius)
                    .stroke(Zine.border, lineWidth: 1)
            )
            .accessibilityLabel("校园食堂地图，可双指缩放或使用下方食堂名称选择")
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button("放大") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    zoom = min(6, zoom * 1.5)
                }
            }
            .buttonStyle(InkButtonStyle())
            Button("缩小") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    zoom = max(1, zoom / 1.5)
                    if zoom <= 1 { offset = .zero }
                }
            }
            .buttonStyle(InkButtonStyle())
            Button("全图") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    zoom = 1
                    offset = .zero
                }
            }
            .buttonStyle(InkButtonStyle())
        }
    }

    private func regionButtons(_ data: CampusMapData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择食堂，也可点击地图中的轮廓")
                .font(.footnote)
                .foregroundStyle(Zine.muted)
            ForEach(data.regions) { region in
                Button {
                    model.select(region)
                } label: {
                    HStack {
                        Image(systemName: model.selectedRegionID == region.id
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Zine.red)
                        Text(region.name)
                            .foregroundStyle(Zine.ink)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityValue(
                    Text(model.selectedRegionID == region.id ? "已选择" : "未选择")
                )
                .accessibilityAddTraits(
                    model.selectedRegionID == region.id ? .isSelected : AccessibilityTraits()
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Zine.cardRadius).fill(Zine.paper))
        .overlay(RoundedRectangle(cornerRadius: Zine.cardRadius).stroke(Zine.border, lineWidth: 1))
    }

    @ViewBuilder
    private func selectionDetails(_ data: CampusMapData) -> some View {
        if let region = model.selectedRegion {
            PaperCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(region.name)
                        .font(Zine.sectionFont)
                        .foregroundStyle(Zine.ink)
                        .accessibilityAddTraits(.isHeader)
                    if let error = model.hallsError {
                        Text("食堂入口读取失败，地图仍可使用：\(error)")
                            .font(.subheadline)
                            .foregroundStyle(Zine.red)
                        Button("重新读取食堂") {
                            Task { await model.loadHalls() }
                        }
                        .buttonStyle(LinkButtonStyle())
                    } else {
                        let halls = model.halls(for: region)
                        if halls.isEmpty {
                            Text("此区域暂无可用的食堂详情入口。")
                                .font(.subheadline)
                                .foregroundStyle(Zine.muted)
                        } else {
                            ForEach(halls) { hall in
                                NavigationLink {
                                    StallsView(hall: hall, catalog: catalog)
                                } label: {
                                    HStack {
                                        Text(hall.name)
                                            .foregroundStyle(Zine.ink)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Zine.muted)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .frame(minHeight: 44)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct CampusMapCanvas: View {
    let data: CampusMapData
    let image: UIImage
    let selectedID: String?
    @Binding var zoom: CGFloat
    @Binding var offset: CGSize
    let onSelect: (CampusMapRegion) -> Void

    @State private var lastZoom: CGFloat = 1
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let base = fittedSize(in: geo.size)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: base.width, height: base.height)
                Canvas { context, size in
                    for region in data.regions {
                        guard region.polygon.count >= 3 else { continue }
                        var path = Path()
                        for (index, point) in region.polygon.enumerated() {
                            guard point.count >= 2 else { continue }
                            let x = point[0] / data.width * size.width
                            let y = point[1] / data.height * size.height
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.closeSubpath()
                        let selected = region.id == selectedID
                        context.fill(
                            path,
                            with: .color(Zine.red.opacity(selected ? 0.32 : 0.08))
                        )
                        context.stroke(
                            path,
                            with: .color(Zine.red),
                            lineWidth: selected ? 2.5 : 1.2
                        )
                    }
                }
                .frame(width: base.width, height: base.height)
            }
            .frame(width: base.width, height: base.height)
            .scaleEffect(zoom)
            .offset(offset)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        zoom = min(6, max(1, lastZoom * value.magnification))
                    }
                    .onEnded { _ in
                        lastZoom = zoom
                        if zoom <= 1 {
                            zoom = 1
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        let maxX = max(0, (base.width * zoom - geo.size.width) / 2)
                        let maxY = max(0, (base.height * zoom - geo.size.height) / 2)
                        offset = CGSize(
                            width: min(maxX, max(-maxX, lastOffset.width + value.translation.width)),
                            height: min(maxY, max(-maxY, lastOffset.height + value.translation.height))
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let localX = (value.location.x - geo.size.width / 2 - offset.width) / zoom + base.width / 2
                        let localY = (value.location.y - geo.size.height / 2 - offset.height) / zoom + base.height / 2
                        guard localX >= 0, localX <= base.width, localY >= 0, localY <= base.height else {
                            return
                        }
                        let imageX = Double(localX / base.width) * data.width
                        let imageY = Double(localY / base.height) * data.height
                        if let region = data.regions.first(where: {
                            CampusMapGeometry.contains(polygon: $0.polygon, x: imageX, y: imageY)
                        }) {
                            onSelect(region)
                        }
                    }
            )
            .onChange(of: zoom) { _, value in
                if value <= 1 {
                    offset = .zero
                    lastOffset = .zero
                }
            }
        }
    }

    private func fittedSize(in available: CGSize) -> CGSize {
        guard data.width > 0, data.height > 0 else { return available }
        let ratio = min(available.width / data.width, available.height / data.height)
        return CGSize(width: data.width * ratio, height: data.height * ratio)
    }
}
