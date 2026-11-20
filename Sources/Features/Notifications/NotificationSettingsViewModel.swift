import Foundation

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    @Published private(set) var preferences: [NotificationPreference] = []
    @Published private(set) var permission: NotificationPermissionStatus = .notDetermined
    @Published private(set) var isLoading = false
    @Published private(set) var savingCategory: String?
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: NotificationService
    private let authorizer: NotificationAuthorizing

    init(service: NotificationService, authorizer: NotificationAuthorizing) {
        self.service = service
        self.authorizer = authorizer
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        permission = await authorizer.status()
        do {
            preferences = try await service.preferences().items
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setEnabled(_ item: NotificationPreference, enabled: Bool) async {
        guard savingCategory == nil else { return }
        guard enabled != item.enabled else { return }
        if enabled, !permission.allowsDelivery {
            let granted = await requestPermission()
            guard granted else { return }
        }
        savingCategory = item.category
        errorMessage = nil
        infoMessage = nil
        defer { savingCategory = nil }
        do {
            let saved = try await service.update(
                category: item.category,
                enabled: enabled,
                expectedRevision: item.revision
            )
            if let index = preferences.firstIndex(where: { $0.category == saved.category }) {
                preferences[index] = saved
            }
            infoMessage = "已保存「\(saved.title)」提醒设置；开启前的历史事件不会补发。"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            // A revision conflict means another device changed the switch;
            // show the server's current value instead of keeping a stale toggle.
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestPermission() async -> Bool {
        errorMessage = nil
        do {
            let granted = try await authorizer.requestAuthorization()
            permission = await authorizer.status()
            if !granted {
                errorMessage = "系统未允许通知，可在系统通知设置中开启。"
            }
            return granted
        } catch {
            errorMessage = "无法请求系统通知权限：\(error.localizedDescription)"
            return false
        }
    }

    func openSystemSettings() {
        authorizer.openSystemSettings()
    }

    var permissionDescription: String {
        switch permission {
        case .authorized, .provisional, .ephemeral:
            return "系统已允许通知。"
        case .denied:
            return "系统尚未允许通知，允许后才能收到系统提醒。"
        case .notDetermined:
            return "还没有询问系统通知权限。"
        }
    }
}
