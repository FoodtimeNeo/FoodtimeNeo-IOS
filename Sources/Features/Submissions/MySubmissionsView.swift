import SwiftUI

@MainActor
final class MySubmissionsViewModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case dishes
        case stalls
        case images

        var id: String { rawValue }
        var title: String {
            switch self {
            case .dishes: return "菜品"
            case .stalls: return "档口"
            case .images: return "图片"
            }
        }
    }

    @Published var tab: Tab = .dishes
    @Published private(set) var dishItems: [DishSubmission] = []
    @Published private(set) var stallItems: [StallSubmission] = []
    @Published private(set) var imageItems: [ImageSubmission] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: SubmissionService
    private let pageSize = 20

    init(service: SubmissionService) {
        self.service = service
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / Double(pageSize))))
    }

    func load(page: Int = 1) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch tab {
            case .dishes:
                let result = try await service.myDishSubmissions(page: max(1, page), size: pageSize)
                dishItems = result.items
                self.page = result.page
                total = result.total
            case .stalls:
                let result = try await service.myStallSubmissions(page: max(1, page), size: pageSize)
                stallItems = result.items
                self.page = result.page
                total = result.total
            case .images:
                let result = try await service.myImageSubmissions(page: max(1, page), size: pageSize)
                imageItems = result.items
                self.page = result.page
                total = result.total
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
struct MySubmissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: MySubmissionsViewModel

    init(session: AppSession) {
        _model = StateObject(wrappedValue: MySubmissionsViewModel(service: session.submissions))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        Picker("范围", selection: $model.tab) {
                            ForEach(MySubmissionsViewModel.Tab.allCases) { tab in
                                Text(tab.title).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: model.tab) { _, _ in
                            Task { await model.load(page: 1) }
                        }

                        if let error = model.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        content
                        if model.totalPages > 1 {
                            HStack {
                                Button("上一页") {
                                    Task { await model.load(page: model.page - 1) }
                                }
                                .buttonStyle(InkButtonStyle())
                                .disabled(model.page <= 1 || model.isLoading)
                                Text("第 \(model.page)/\(model.totalPages) 页")
                                    .font(.footnote)
                                    .foregroundStyle(Zine.muted)
                                Button("下一页") {
                                    Task { await model.load(page: model.page + 1) }
                                }
                                .buttonStyle(InkButtonStyle())
                                .disabled(model.page >= model.totalPages || model.isLoading)
                            }
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("我的投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.load(page: 1) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            LoadingStateView(message: "正在读取投稿…")
        } else {
            switch model.tab {
            case .dishes:
                if model.dishItems.isEmpty {
                    EmptyStateView(title: "暂无菜品投稿", message: nil)
                } else {
                    ForEach(model.dishItems) { item in
                        card(
                            title: item.name,
                            whereText: "\(item.diningHallName) · \(item.stallName)",
                            content: item.description,
                            status: item.status,
                            reason: item.reviewReason,
                            createdAt: item.createdAt
                        )
                    }
                }
            case .stalls:
                if model.stallItems.isEmpty {
                    EmptyStateView(title: "暂无档口投稿", message: nil)
                } else {
                    ForEach(model.stallItems) { item in
                        card(
                            title: item.name,
                            whereText: item.diningHallName,
                            content: item.description,
                            status: item.status,
                            reason: item.reviewReason,
                            createdAt: item.createdAt
                        )
                    }
                }
            case .images:
                if model.imageItems.isEmpty {
                    EmptyStateView(title: "暂无图片投稿", message: nil)
                } else {
                    ForEach(model.imageItems) { item in
                        card(
                            title: item.dishName,
                            whereText: "\(item.diningHallName) · \(item.stallName)",
                            content: nil,
                            status: item.status,
                            reason: item.reviewReason,
                            createdAt: item.createdAt
                        )
                    }
                }
            }
        }
    }

    private func card(
        title: String,
        whereText: String,
        content: String?,
        status: String,
        reason: String?,
        createdAt: Date?
    ) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Zine.ink)
                    Spacer()
                    Text(SubmissionStatus.label(status))
                        .font(.caption)
                        .foregroundStyle(status == "approved" ? Zine.green : status == "rejected" ? Zine.red : Zine.muted)
                }
                Text(whereText)
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
                if let content, !content.isEmpty {
                    Text(content)
                        .font(.subheadline)
                        .foregroundStyle(Zine.muted)
                        .lineLimit(3)
                }
                if let reason, !reason.isEmpty {
                    Text("审核说明：\(reason)")
                        .font(.footnote)
                        .foregroundStyle(Zine.red)
                }
                Text(DisplayFormat.dateTime(createdAt))
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
        }
    }
}
