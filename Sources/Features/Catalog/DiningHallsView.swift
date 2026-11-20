import SwiftUI

@MainActor
struct DiningHallsView: View {
    @StateObject private var model: DiningHallsViewModel
    private let catalog: CatalogService

    init(catalog: CatalogService) {
        self.catalog = catalog
        _model = StateObject(wrappedValue: DiningHallsViewModel(catalog: catalog))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeading(
                        index: "01",
                        title: "食堂手账",
                        subtitle: "今天的好心情，从一顿热饭开始。"
                    )
                    NavigationLink {
                        DishSearchView(catalog: catalog)
                    } label: {
                        PaperCard {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Zine.red)
                                Text("搜索菜品")
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
                        CampusMapView(catalog: catalog)
                    } label: {
                        PaperCard {
                            HStack(spacing: 10) {
                                Image(systemName: "map")
                                    .foregroundStyle(Zine.red)
                                Text("食堂地图")
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
                    DailyRecommendationSection(
                        recommendations: model.recommendations,
                        isLoading: model.isLoadingRecommendations,
                        error: model.recommendationError,
                        catalog: catalog
                    ) {
                        Task { await model.loadRecommendations() }
                    }
                    content
                }
                .padding(Zine.pagePadding)
            }
            .refreshable {
                await model.load()
                await model.loadRecommendations()
            }
        }
        .navigationTitle("食堂")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.loadIfNeeded()
            await model.loadRecommendationsIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.halls.isEmpty {
            LoadingStateView(message: "正在准备食堂…")
        } else if let error = model.errorMessage, model.halls.isEmpty {
            ErrorStateView(message: error) {
                Task { await model.load() }
            }
        } else if model.halls.isEmpty {
            EmptyStateView(title: "暂无食堂", message: "稍后再来看看，或联系管理员确认目录。")
        } else {
            ForEach(model.halls.indices, id: \.self) { index in
                let hall = model.halls[index]
                NavigationLink {
                    StallsView(hall: hall, catalog: catalog)
                } label: {
                    DiningHallCard(hall: hall, index: index)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DiningHallCard: View {
    let hall: DiningHall
    let index: Int

    var body: some View {
        PaperCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Zine.smallRadius)
                        .fill(Zine.alt)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Zine.red)
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "第 %02d 站", index + 1))
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(index % 3 == 1 ? Zine.green : Zine.red)
                    Text(hall.name)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    if let description = hall.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(Zine.muted)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Zine.muted)
                    .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hall.name)，查看档口")
    }
}
