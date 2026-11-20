import SwiftUI

struct DailyRecommendationSection: View {
    let recommendations: DailyRecommendations?
    let isLoading: Bool
    let error: String?
    let catalog: CatalogService
    let retry: () -> Void

    var body: some View {
        if isLoading && recommendations == nil {
            loadingCard
        } else if let error, recommendations == nil {
            errorCard(error)
        } else if let recommendations {
            if recommendations.items.isEmpty {
                emptyCard
            } else {
                section(recommendations)
            }
        }
    }

    private var loadingCard: some View {
        PaperCard {
            HStack(spacing: 10) {
                ProgressView().tint(Zine.red)
                Text("今日菜单正在翻页…")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("今日推荐暂时无法加载")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Zine.red)
                Button("再试一次", action: retry)
                    .buttonStyle(LinkButtonStyle())
            }
        }
    }

    private var emptyCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("今日暂无推荐")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("今日清单还在冒热气，先逛逛食堂吧。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    private func section(_ data: DailyRecommendations) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日推荐")
                        .font(.system(size: 24, weight: .black, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Text("今天吃点不一样的")
                        .font(Zine.noteFont)
                        .foregroundStyle(Zine.red)
                }
                Spacer()
                Text("\(data.total) 道")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(data.items.prefix(5))) { dish in
                        NavigationLink {
                            DishDetailView(dishID: dish.dishId, catalog: catalog)
                        } label: {
                            recommendationCard(dish)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func recommendationCard(_ dish: RecommendedDish) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Zine.alt
                if let raw = dish.imageUrl,
                   let url = MediaURL.resolve(raw, baseURL: catalog.mediaBaseURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "fork.knife")
                                .font(.system(size: 30))
                                .foregroundStyle(Zine.muted)
                        }
                    }
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 30))
                        .foregroundStyle(Zine.muted)
                }
            }
            .frame(width: 230, height: 132)
            .clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(dish.dishName)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                    .lineLimit(2)
                Text("\(dish.diningHallName) · \(dish.stallName)")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                    .lineLimit(1)
                if let rating = dish.averageRating {
                    Text(DisplayFormat.score(rating, reviewCount: dish.reviewCount))
                        .font(.caption)
                        .foregroundStyle(Zine.red)
                }
                Text(dish.reason)
                    .font(.caption)
                    .foregroundStyle(Zine.green)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(width: 230, alignment: .leading)
            .background(Zine.paper)
        }
        .frame(width: 230)
        .clipShape(RoundedRectangle(cornerRadius: Zine.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Zine.cardRadius)
                .stroke(Zine.border, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: Zine.cardRadius)
                .fill(Zine.shadow)
                .offset(x: 3, y: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dish.dishName)，\(dish.diningHallName)，\(dish.stallName)，查看详情")
    }
}
