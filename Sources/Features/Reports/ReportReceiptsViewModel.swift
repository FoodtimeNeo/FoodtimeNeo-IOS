import Foundation

@MainActor
final class ReportReceiptsViewModel: ObservableObject {
    enum Segment: String, CaseIterable, Identifiable {
        case reports
        case decisions

        var id: String { rawValue }
        var title: String { self == .reports ? "我的举报" : "收到的决定" }
    }

    @Published var segment: Segment = .reports
    @Published private(set) var reports: [UserReport] = []
    @Published private(set) var decisions: [ModerationDecision] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?
    @Published private(set) var actionCache: [String: [ReportAction]] = [:]

    let service: ReportService
    private let pageSize = 20
    private var reportPage = 1
    private var decisionPage = 1
    private var reportTotal = 0
    private var decisionTotal = 0
    private var generation = 0

    init(service: ReportService) {
        self.service = service
    }

    var canLoadMore: Bool {
        switch segment {
        case .reports: return reportPage * pageSize < reportTotal
        case .decisions: return decisionPage * pageSize < decisionTotal
        }
    }

    var statusText: String {
        switch segment {
        case .reports:
            return reports.isEmpty ? "还没有举报记录。" : "共 \(reportTotal) 条"
        case .decisions:
            return decisions.isEmpty ? "还没有收到的处理决定。" : "共 \(decisionTotal) 条"
        }
    }

    func load(reset: Bool = true) async {
        if reset {
            generation += 1
        }
        let current = generation
        isLoading = true
        errorMessage = nil
        defer {
            if current == generation {
                isLoading = false
            }
        }
        do {
            switch segment {
            case .reports:
                let page = try await service.myReports(page: reset ? 1 : reportPage + 1, size: pageSize)
                guard current == generation else { return }
                reports = reset ? page.items : merged(reports, page.items, id: \.id)
                reportPage = reset ? 1 : reportPage + 1
                reportTotal = page.total
            case .decisions:
                let page = try await service.myDecisions(page: reset ? 1 : decisionPage + 1, size: pageSize)
                guard current == generation else { return }
                decisions = reset ? page.items : merged(decisions, page.items, id: \.id)
                decisionPage = reset ? 1 : decisionPage + 1
                decisionTotal = page.total
            }
        } catch let error as AppError {
            if current == generation { errorMessage = error.localizedDescription }
        } catch {
            if current == generation { errorMessage = error.localizedDescription }
        }
    }

    func switchSegment(_ next: Segment) async {
        segment = next
        await load(reset: true)
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await load(reset: false)
    }

    func loadActions(decisionID: String) async {
        guard actionCache[decisionID] == nil else { return }
        do {
            actionCache[decisionID] = try await service.decisionActions(decisionID: decisionID)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func actions(decisionID: String) -> [ReportAction]? {
        actionCache[decisionID]
    }

    private func merged<T>(_ current: [T], _ next: [T], id: KeyPath<T, String>) -> [T] {
        var seen = Set(current.map { $0[keyPath: id] })
        var result = current
        for item in next where seen.insert(item[keyPath: id]).inserted {
            result.append(item)
        }
        return result
    }
}
