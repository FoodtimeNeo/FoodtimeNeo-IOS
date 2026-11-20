import SwiftUI

@MainActor
struct DishSearchView: View {
    @StateObject private var model: DishSearchViewModel
    @State private var showFilters = false

    init(catalog: CatalogService) {
        _model = StateObject(wrappedValue: DishSearchViewModel(catalog: catalog))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    searchBar
                    resultSummary
                    resultsContent
                    pagination
                }
                .padding(Zine.pagePadding)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("搜菜")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.loadHalls()
            if model.results.isEmpty {
                await model.search(reset: true)
            }
        }
        .sheet(isPresented: $showFilters) {
            DishFilterSheet(model: model) {
                Task { await model.search(reset: true) }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Zine.muted)
                TextField("搜索菜品名称，留空浏览全部", text: $model.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task { await model.search(reset: true) }
                    }
                    .onChange(of: model.query) { _, _ in
                        model.queryChanged()
                    }
                if !model.query.isEmpty {
                    Button {
                        model.query = ""
                        Task { await model.search(reset: true) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Zine.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .modifier(FormInputStyle())

            Button {
                showFilters = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(model.activeFilterCount > 0 ? "\(model.activeFilterCount)" : "筛选")
                        .font(.caption2)
                }
                .frame(width: 52, height: 48)
            }
            .buttonStyle(InkButtonStyle())
        }
    }

    @ViewBuilder
    private var resultSummary: some View {
        if !model.results.isEmpty {
            HStack {
                Text("共 \(model.total) 道菜")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                Spacer()
                Text("第 \(model.page)/\(model.totalPages) 页")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        if model.isLoading && model.results.isEmpty {
            LoadingStateView(message: "正在翻菜单…")
        } else if let error = model.errorMessage, model.results.isEmpty {
            ErrorStateView(message: error) {
                Task { await model.search(reset: true) }
            }
        } else if model.results.isEmpty {
            EmptyStateView(title: "没有匹配的菜品", message: "换个关键词或放宽筛选条件试试。")
        } else {
            ForEach(model.results) { dish in
                PaperCard {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(dish.name)
                                .font(.system(size: 19, weight: .bold, design: .serif))
                                .foregroundStyle(Zine.ink)
                            Spacer(minLength: 8)
                            Text(DisplayFormat.price(dish.price))
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(Zine.red)
                        }
                        Text("\(dish.diningHallName) · \(dish.stallName)")
                            .font(.footnote)
                            .foregroundStyle(Zine.muted)
                        Text(DisplayFormat.score(dish.averageScore, reviewCount: dish.reviewCount))
                            .font(.footnote)
                            .foregroundStyle(Zine.red)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private var pagination: some View {
        if model.totalPages > 1 {
            HStack {
                Button("上一页") {
                    Task { await model.previousPage() }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(model.page <= 1 || model.isLoading)
                Spacer()
                Text("\(model.page) / \(model.totalPages)")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                Spacer()
                Button("下一页") {
                    Task { await model.nextPage() }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(model.page >= model.totalPages || model.isLoading)
            }
        }
    }
}

@MainActor
private struct DishFilterSheet: View {
    @ObservedObject var model: DishSearchViewModel
    @Environment(\.dismiss) private var dismiss
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        priceCard
                        ratingAndSortCard
                        hallCard
                    }
                    .padding(Zine.pagePadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("重置") {
                        model.resetFilters()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }

    private var priceCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("价格区间")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                HStack(spacing: 10) {
                    TextField("最低价", text: $model.minPriceText)
                        .keyboardType(.decimalPad)
                        .modifier(FormInputStyle())
                    Text("—").foregroundStyle(Zine.muted)
                    TextField("最高价", text: $model.maxPriceText)
                        .keyboardType(.decimalPad)
                        .modifier(FormInputStyle())
                }
                Text("价格未知的菜品会保留并排在完整数据之后。")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    private var ratingAndSortCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                Picker("最低评分", selection: $model.rating) {
                    ForEach(DishRatingFilter.allCases) { rating in
                        Text(rating.label).tag(rating)
                    }
                }
                .pickerStyle(.menu)
                .tint(Zine.ink)

                Picker("排序", selection: $model.sort) {
                    ForEach(DishSort.allCases) { sort in
                        Text(sort.label).tag(sort)
                    }
                }
                .pickerStyle(.menu)
                .tint(Zine.ink)
            }
        }
    }

    private var hallCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("食堂（可多选）")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                if model.halls.isEmpty {
                    if let error = model.hallsError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Zine.red)
                        Button("重新读取食堂") {
                            Task { await model.loadHalls() }
                        }
                        .buttonStyle(LinkButtonStyle())
                    } else {
                        ProgressView().tint(Zine.red)
                    }
                } else {
                    ForEach(model.halls) { hall in
                        Button {
                            model.toggleHall(hall.id)
                        } label: {
                            HStack {
                                Image(systemName: model.selectedHallIDs.contains(hall.id)
                                      ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(Zine.red)
                                Text(hall.name)
                                    .foregroundStyle(Zine.ink)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 40)
                    }
                }
            }
        }
    }
}
