import Foundation

protocol AdminService: AnyObject {
    func dashboard(days: Int) async throws -> AdminDashboard
    func users(query: String, page: Int, size: Int) async throws -> Page<AdminUser>
    func updateUser(id: String, role: String, status: String) async throws
}
