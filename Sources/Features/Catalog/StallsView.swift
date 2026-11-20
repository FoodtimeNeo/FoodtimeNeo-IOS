import SwiftUI

@MainActor
struct StallsView: View {
    let hall: DiningHall
    private let catalog: CatalogService
    @StateObject private var model: StallsViewModel

    init(hall: DiningHall, catalog: CatalogService) {
        self.hall = hall
        self.catalog = catalog
        _model = StateObject(wrappedValue: StallsViewModel(hallID: hall.id, catalog: catalog))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeading(
                        index: "01.1",
                        title: hall.name,
                        subtitle: hall.description
                    )
                    content
                }
                .padding(Zine.pagePadding)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle(hall.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.stalls.isEmpty {
            LoadingStateView(message: "正在翻档口菜单…")
        } else if let error = model.errorMessage, model.stalls.isEmpty {
            ErrorStateView(message: error) {
                Task { await model.load() }
            }
        } else if model.stalls.isEmpty {
            EmptyStateView(title: "暂无档口", message: "该食堂还没有启用的档口。")
        } else {
            ForEach(model.stalls.indices, id: \.self) { index in
                let stall = model.stalls[index]
                NavigationLink {
                    StallDishesView(stall: stall, catalog: catalog)
                } label: {
                    PaperCard {
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 18, weight: .black, design: .serif))
                                .foregroundStyle(Zine.red)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stall.name)
                                    .font(.system(size: 19, weight: .bold, design: .serif))
                                    .foregroundStyle(Zine.ink)
                                if let description = stall.description, !description.isEmpty {
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
                    .accessibilityLabel("\(stall.name)，查看菜品")
                }
                .buttonStyle(.plain)
            }
        }
    }
}
