import SwiftUI

@MainActor
struct StallDishesView: View {
    let stall: Stall
    private let catalog: CatalogService
    @StateObject private var model: DishesViewModel

    init(stall: Stall, catalog: CatalogService) {
        self.stall = stall
        self.catalog = catalog
        _model = StateObject(wrappedValue: DishesViewModel(stallID: stall.id, catalog: catalog))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeading(
                        index: "01.1.1",
                        title: stall.name,
                        subtitle: stall.description
                    )
                    content
                }
                .padding(Zine.pagePadding)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle(stall.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.dishes.isEmpty {
            LoadingStateView(message: "正在端上菜品…")
        } else if let error = model.errorMessage, model.dishes.isEmpty {
            ErrorStateView(message: error) {
                Task { await model.load() }
            }
        } else if model.dishes.isEmpty {
            EmptyStateView(title: "暂无菜品", message: "这个档口还没有启用的菜品。")
        } else {
            ForEach(model.dishes) { dish in
                NavigationLink {
                    DishDetailView(dishID: dish.id, catalog: catalog)
                } label: {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(dish.name)
                                    .font(.system(size: 19, weight: .bold, design: .serif))
                                    .foregroundStyle(Zine.ink)
                                Spacer(minLength: 8)
                                Text(DisplayFormat.price(dish.price))
                                    .font(.system(size: 17, weight: .heavy))
                                    .foregroundStyle(Zine.red)
                            }
                            Text(DisplayFormat.score(dish.averageScore, reviewCount: dish.reviewCount))
                                .font(.subheadline)
                                .foregroundStyle(Zine.muted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
