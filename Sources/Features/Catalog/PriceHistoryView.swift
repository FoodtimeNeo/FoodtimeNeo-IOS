import SwiftUI

@MainActor
struct PriceHistoryView: View {
    @StateObject private var model: PriceHistoryViewModel

    init(dishID: String, catalog: CatalogService) {
        _model = StateObject(
            wrappedValue: PriceHistoryViewModel(dishID: dishID, catalog: catalog)
        )
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    Picker("时间范围", selection: Binding(
                        get: { model.days },
                        set: { days in Task { await model.load(days: days) } }
                    )) {
                        Text("全部").tag(0)
                        Text("30 天").tag(30)
                        Text("90 天").tag(90)
                    }
                    .pickerStyle(.segmented)

                    content
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("价格变化")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model.history == nil {
                await model.load(days: 0)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.history == nil {
            LoadingStateView(message: "正在读取价格记录…")
        } else if let error = model.errorMessage, model.history == nil {
            ErrorStateView(message: error) {
                Task { await model.load(days: model.days) }
            }
        } else if let history = model.history {
            summaryCard(history)
            if model.runs.isEmpty {
                EmptyStateView(title: "暂无价格记录", message: "当前时间范围内没有可绘制的价格点。")
            } else {
                chartCard(history)
            }
            recordsCard(history)
        }
    }

    private func summaryCard(_ history: DishPriceHistory) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(history.dishName)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text(priceText(history.currentPrice, unit: history.priceUnit, current: true))
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Zine.red)
                Text("共 \(history.totalRecords) 条记录 · 单位按记录分段绘制")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                if history.canManage {
                    Text("当前账号可更正/隐藏价格记录（管理端界面将在 W6 接入）。")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }
            }
        }
    }

    private func chartCard(_ history: DishPriceHistory) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                PriceHistoryChartView(history: history, runs: model.runs)
                    .frame(height: 230)
                HStack(spacing: 12) {
                    ForEach(model.runs.indices, id: \.self) { index in
                        let run = model.runs[index]
                        Text(PriceUnit.label(run.unit ?? "unspecified"))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Zine.alt))
                            .foregroundStyle(Zine.ink)
                    }
                }
            }
        }
    }

    private func recordsCard(_ history: DishPriceHistory) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("记录")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                ForEach(history.records.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(priceText(entry.price, unit: entry.priceUnit, current: false))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(entry.price == nil ? Zine.muted : Zine.ink)
                            Spacer()
                            Text(DisplayFormat.dateTime(entry.recordedAt))
                                .font(.caption)
                                .foregroundStyle(Zine.muted)
                        }
                        HStack(spacing: 6) {
                            if entry.carriedForward {
                                Text("区间前沿用")
                                    .font(.caption2)
                                    .foregroundStyle(Zine.blue)
                            }
                            if entry.origin == "admin" {
                                Text("管理更正")
                                    .font(.caption2)
                                    .foregroundStyle(Zine.red)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private func priceText(_ price: Decimal?, unit: String, current: Bool) -> String {
        guard let price else { return current ? "当前价格待补充" : "价格未知" }
        let formatted = DisplayFormat.price(price)
        let unitLabel = PriceUnit.label(unit)
        if unitLabel == "未注明" {
            return "\(formatted) · 单位未注明"
        }
        return "\(formatted)/\(unitLabel)"
    }
}

private struct PriceHistoryChartView: View {
    let history: DishPriceHistory
    let runs: [PriceHistoryRun]

    var body: some View {
        Canvas { context, size in
            let points = runs.flatMap(\.points)
            guard !points.isEmpty else { return }
            let windowStart = history.windowStart ?? points.first!.time
            let windowEnd = history.windowEnd ?? points.last!.time
            let span = max(1, windowEnd.timeIntervalSince(windowStart))

            let prices = points.compactMap { $0.entry.price.map { NSDecimalNumber(decimal: $0).doubleValue } }
            guard let rawMin = prices.min(), let rawMax = prices.max() else { return }
            let padding = max(0.5, (rawMax - rawMin) * 0.15)
            let minPrice = max(0, rawMin - padding)
            let maxPrice = rawMax + padding

            let left: CGFloat = 46
            let right: CGFloat = 12
            let top: CGFloat = 12
            let bottom: CGFloat = 24
            let chartWidth = max(1, size.width - left - right)
            let chartHeight = max(1, size.height - top - bottom)

            func x(_ date: Date) -> CGFloat {
                let ratio = date.timeIntervalSince(windowStart) / span
                return left + chartWidth * CGFloat(min(1, max(0, ratio)))
            }
            func y(_ price: Double) -> CGFloat {
                let ratio = (price - minPrice) / max(0.01, maxPrice - minPrice)
                return top + chartHeight * (1 - CGFloat(ratio))
            }

            for step in 0...2 {
                let price = minPrice + (maxPrice - minPrice) * Double(step) / 2
                let yValue = y(price)
                var grid = Path()
                grid.move(to: CGPoint(x: left, y: yValue))
                grid.addLine(to: CGPoint(x: left + chartWidth, y: yValue))
                context.stroke(grid, with: .color(Zine.border.opacity(0.7)), lineWidth: 1)
                let label = Text(String(format: "¥%.1f", price))
                    .font(.system(size: 9))
                    .foregroundColor(Zine.muted)
                context.draw(label, at: CGPoint(x: left - 6, y: yValue), anchor: .trailing)
            }

            for run in runs {
                guard let first = run.points.first,
                      let firstPrice = first.entry.price else { continue }
                var path = Path()
                let firstY = y(NSDecimalNumber(decimal: firstPrice).doubleValue)
                path.move(to: CGPoint(x: x(max(run.start, windowStart)), y: firstY))
                path.addLine(to: CGPoint(x: x(first.time), y: firstY))
                var lastY = firstY
                for point in run.points.dropFirst() {
                    guard let price = point.entry.price else { continue }
                    let px = x(point.time)
                    let py = y(NSDecimalNumber(decimal: price).doubleValue)
                    path.addLine(to: CGPoint(x: px, y: lastY))
                    path.addLine(to: CGPoint(x: px, y: py))
                    lastY = py
                }
                path.addLine(to: CGPoint(x: x(min(run.end, windowEnd)), y: lastY))
                context.stroke(path, with: .color(Zine.red), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                for point in run.points {
                    guard let price = point.entry.price else { continue }
                    let dot = CGRect(
                        x: x(point.time) - 2.5,
                        y: y(NSDecimalNumber(decimal: price).doubleValue) - 2.5,
                        width: 5,
                        height: 5
                    )
                    context.fill(Path(ellipseIn: dot), with: .color(Zine.red))
                }
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            formatter.dateFormat = "MM-dd"
            let startLabel = Text(formatter.string(from: windowStart)).font(.system(size: 9)).foregroundColor(Zine.muted)
            let endLabel = Text(formatter.string(from: windowEnd)).font(.system(size: 9)).foregroundColor(Zine.muted)
            context.draw(startLabel, at: CGPoint(x: left, y: size.height - 4), anchor: .topLeading)
            context.draw(endLabel, at: CGPoint(x: left + chartWidth, y: size.height - 4), anchor: .topTrailing)
        }
        .accessibilityLabel("价格变化阶梯图")
    }
}
