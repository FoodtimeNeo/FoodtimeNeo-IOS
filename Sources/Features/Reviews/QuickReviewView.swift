import SwiftUI

@MainActor
struct QuickReviewView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: DishSearchViewModel
    @State private var selectedDish: DishSearchRow?
    @State private var submittedName: String?

    init(catalog: CatalogService) {
        _model = StateObject(wrappedValue: DishSearchViewModel(catalog: catalog))
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    SectionHeading(
                        index: "02.1",
                        title: "一键点评",
                        subtitle: "选一道菜，写下评分和感受；提交后进入审核。"
                    )
                    if let submittedName, !submittedName.isEmpty {
                        successCard(submittedName)
                    }
                    searchBar
                    results
                }
                .padding(Zine.pagePadding)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("一键点评")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model.results.isEmpty {
                await model.search(reset: true)
            }
        }
        .sheet(item: $selectedDish, onDismiss: { selectedDish = nil }) { dish in
            ReviewComposerView(dishID: dish.id, service: session.reviews) {
                submittedName = dish.name
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Zine.muted)
            TextField("搜索菜品，或留空浏览全部", text: $model.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    Task { await model.search(reset: true) }
                }
                .onChange(of: model.query) { _, _ in
                    model.queryChanged()
                }
        }
        .modifier(FormInputStyle())
    }

    @ViewBuilder
    private var results: some View {
        if model.isLoading && model.results.isEmpty {
            LoadingStateView(message: "正在翻菜单…")
        } else if let error = model.errorMessage, model.results.isEmpty {
            ErrorStateView(message: error) {
                Task { await model.search(reset: true) }
            }
        } else if model.results.isEmpty {
            EmptyStateView(title: "没有匹配的菜品", message: "换个关键词试试。")
        } else {
            ForEach(model.results) { dish in
                Button {
                    selectedDish = dish
                } label: {
                    PaperCard {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dish.name)
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundStyle(Zine.ink)
                                Text("\(dish.diningHallName) · \(dish.stallName)")
                                    .font(.caption)
                                    .foregroundStyle(Zine.muted)
                                Text(DisplayFormat.score(dish.averageScore, reviewCount: dish.reviewCount))
                                    .font(.caption)
                                    .foregroundStyle(Zine.red)
                            }
                            Spacer()
                            Text(DisplayFormat.price(dish.price))
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(Zine.red)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            if model.totalPages > 1 {
                HStack {
                    Button("上一页") {
                        Task { await model.previousPage() }
                    }
                    .buttonStyle(InkButtonStyle())
                    .disabled(model.page <= 1 || model.isLoading)
                    Text("\(model.page) / \(model.totalPages)")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                    Button("下一页") {
                        Task { await model.nextPage() }
                    }
                    .buttonStyle(InkButtonStyle())
                    .disabled(model.page >= model.totalPages || model.isLoading)
                }
            }
        }
    }

    private func successCard(_ name: String) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("点评已提交")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("“\(name)”的点评正在审核，通过后会公开并计入评分。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                Button("完成") { dismiss() }
                    .buttonStyle(InkButtonStyle(primary: true))
            }
        }
    }
}
