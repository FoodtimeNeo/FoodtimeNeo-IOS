import Combine
import Foundation

@MainActor
final class AdminNoticesViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var notices: [AdminNotice] = []
    @Published private(set) var page = 1
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var deletingID: String?
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

    func load(page: Int = 1) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.notices(
                query: query,
                page: max(1, page),
                size: pageSize
            )
            notices = result.items
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
            await self.load(page: 1)
        }
    }

    func delete(_ notice: AdminNotice) async -> Bool {
        guard deletingID == nil else { return false }
        deletingID = notice.id
        errorMessage = nil
        infoMessage = nil
        defer { deletingID = nil }
        do {
            try await service.deleteNotice(id: notice.id)
            infoMessage = "已删除公告。"
            await load(page: page)
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func changed(_ message: String) {
        infoMessage = message
        Task { await load(page: page) }
    }
}

@MainActor
final class AdminNoticeEditorViewModel: ObservableObject {
    @Published var content: String
    @Published var publishedAt: Date
    @Published var hasDisplayStart: Bool
    @Published var displayStartsAt: Date
    @Published var hasDisplayEnd: Bool
    @Published var displayEndsAt: Date
    @Published var hasExpiry: Bool
    @Published var expiresOn: Date
    @Published var isUpdate: Bool
    @Published var published: Bool
    @Published var enabled: Bool
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    let existing: AdminNotice?
    private let service: AdminService

    init(service: AdminService, existing: AdminNotice?) {
        self.service = service
        self.existing = existing
        content = existing?.content ?? ""
        publishedAt = existing?.publishedAt ?? Date()
        hasDisplayStart = existing?.displayStartsAt != nil
        displayStartsAt = existing?.displayStartsAt ?? Date()
        hasDisplayEnd = existing?.displayEndsAt != nil
        displayEndsAt = existing?.displayEndsAt ?? Date()
        hasExpiry = existing?.expiresOn != nil
        expiresOn = Self.day(existing?.expiresOn) ?? Date()
        isUpdate = existing?.isUpdate ?? false
        published = existing?.published ?? true
        enabled = existing?.enabled ?? true
    }

    func save() async -> Bool {
        guard !isSaving else { return false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "公告内容不能为空"
            return false
        }
        guard trimmed.count <= 20_000 else {
            errorMessage = "公告内容不能超过 20000 字"
            return false
        }
        let firstLine = trimmed.split(separator: "\n").first(where: {
            !String($0).trimmingCharacters(in: .whitespaces).isEmpty
        })
        guard let firstLine,
              String(firstLine).trimmingCharacters(in: .whitespaces).hasPrefix("#") else {
            errorMessage = "请用 Markdown 标题（# …）作为公告标题"
            return false
        }
        let schedule = AdminNoticeScheduleRequest(
            publishedAt: AdminNoticeDates.iso(publishedAt),
            displayStartsAt: hasDisplayStart ? AdminNoticeDates.iso(displayStartsAt) : nil,
            displayEndsAt: hasDisplayEnd ? AdminNoticeDates.iso(displayEndsAt) : nil,
            expiresOn: hasExpiry ? AdminNoticeDates.localDay(expiresOn) : nil,
            isUpdate: isUpdate,
            published: published,
            enabled: enabled
        )
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await service.saveNotice(
                id: existing?.id,
                content: trimmed,
                schedule: schedule
            )
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func day(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

@MainActor
final class AdminNoticeScheduleViewModel: ObservableObject {
    @Published var publishedAt: Date
    @Published var hasDisplayStart: Bool
    @Published var displayStartsAt: Date
    @Published var hasDisplayEnd: Bool
    @Published var displayEndsAt: Date
    @Published var hasExpiry: Bool
    @Published var expiresOn: Date
    @Published var isUpdate: Bool
    @Published var published: Bool
    @Published var enabled: Bool
    @Published var isSaving = false
    @Published var errorMessage: String?

    let notice: AdminNotice
    private let service: AdminService

    init(service: AdminService, notice: AdminNotice) {
        self.service = service
        self.notice = notice
        publishedAt = notice.publishedAt ?? Date()
        hasDisplayStart = notice.displayStartsAt != nil
        displayStartsAt = notice.displayStartsAt ?? Date()
        hasDisplayEnd = notice.displayEndsAt != nil
        displayEndsAt = notice.displayEndsAt ?? Date()
        hasExpiry = notice.expiresOn != nil
        expiresOn = Date()
        isUpdate = notice.isUpdate
        published = notice.published
        enabled = notice.enabled
        if let value = notice.expiresOn {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            formatter.dateFormat = "yyyy-MM-dd"
            expiresOn = formatter.date(from: value) ?? Date()
        }
    }

    func save() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let schedule = AdminNoticeScheduleRequest(
            publishedAt: AdminNoticeDates.iso(publishedAt),
            displayStartsAt: hasDisplayStart ? AdminNoticeDates.iso(displayStartsAt) : nil,
            displayEndsAt: hasDisplayEnd ? AdminNoticeDates.iso(displayEndsAt) : nil,
            expiresOn: hasExpiry ? AdminNoticeDates.localDay(expiresOn) : nil,
            isUpdate: isUpdate,
            published: published,
            enabled: enabled
        )
        do {
            _ = try await service.scheduleNotice(id: notice.id, schedule: schedule)
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class AdminNoticeSettingsViewModel: ObservableObject {
    @Published private(set) var notices: [AdminNotice] = []
    @Published var selectedID = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let service: AdminService

    init(service: AdminService) {
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let settings = service.noticeSettings()
            async let page = service.notices(query: "", page: 1, size: 100)
            let current = try await settings
            let all = try await page
            notices = all.items
            selectedID = current.noticeId ?? ""
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let settings = try await service.updateNoticeSettings(
                noticeID: selectedID.isEmpty ? nil : selectedID
            )
            selectedID = settings.noticeId ?? ""
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
