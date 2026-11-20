import Combine
import Foundation

@MainActor
final class AdminHomeViewModel: ObservableObject {
    @Published private(set) var dashboard: AdminDashboard?
    @Published private(set) var users: [AdminUser] = []
    @Published var query = ""
    @Published private(set) var days = 7
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoadingDashboard = false
    @Published private(set) var isLoadingUsers = false
    @Published private(set) var updatingUserID: String?
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: AdminService
    private var queryTask: Task<Void, Never>?
    private let pageSize = 20

    init(service: AdminService) {
        self.service = service
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / Double(pageSize))))
    }

    func load() async {
        await loadDashboard()
        await loadUsers(page: 1)
    }

    func loadDashboard() async {
        guard !isLoadingDashboard else { return }
        isLoadingDashboard = true
        errorMessage = nil
        defer { isLoadingDashboard = false }
        do {
            dashboard = try await service.dashboard(days: days)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDays(_ next: Int) async {
        days = [7, 30, 31].contains(next) ? next : 7
        await loadDashboard()
    }

    func loadUsers(page: Int) async {
        guard !isLoadingUsers else { return }
        isLoadingUsers = true
        errorMessage = nil
        defer { isLoadingUsers = false }
        do {
            let result = try await service.users(query: query, page: max(1, page), size: pageSize)
            users = result.items
            self.page = result.page
            total = result.total
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func queryChanged() {
        queryTask?.cancel()
        queryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.loadUsers(page: 1)
        }
    }

    func updateUser(_ user: AdminUser, role: String, status: String) async {
        guard updatingUserID == nil else { return }
        updatingUserID = user.id
        errorMessage = nil
        infoMessage = nil
        defer { updatingUserID = nil }
        do {
            try await service.updateUser(id: user.id, role: role, status: status)
            infoMessage = "已更新 \(user.displayName) 的角色/状态。"
            await loadUsers(page: page)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
