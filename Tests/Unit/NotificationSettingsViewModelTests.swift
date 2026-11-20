import XCTest
@testable import FoodtimeNeo

@MainActor
final class NotificationSettingsViewModelTests: XCTestCase {
    func testLoadReadsPreferencesAndPermission() async {
        let service = FakeNotificationService()
        service.preferencesResult = .success(
            NotificationPreferences(items: [TestFixtures.notificationPreference])
        )
        let authorizer = FakeNotificationAuthorizer()
        authorizer.currentStatus = .authorized
        let model = NotificationSettingsViewModel(service: service, authorizer: authorizer)

        await model.load()

        XCTAssertEqual(model.preferences.count, 1)
        XCTAssertEqual(model.permission, .authorized)
        XCTAssertEqual(model.permissionDescription, "系统已允许通知。")
    }

    func testEnablingWhenPermissionDeniedDoesNotSave() async throws {
        let service = FakeNotificationService()
        service.preferencesResult = .success(
            NotificationPreferences(
                items: [NotificationPreference(category: "message", enabled: false, revision: 1)]
            )
        )
        let authorizer = FakeNotificationAuthorizer()
        authorizer.currentStatus = .denied
        authorizer.requestResult = .success(false)
        let model = NotificationSettingsViewModel(service: service, authorizer: authorizer)
        await model.load()
        let item = try XCTUnwrap(model.preferences.first)

        await model.setEnabled(item, enabled: true)

        XCTAssertEqual(authorizer.requestCalls, 1)
        XCTAssertTrue(service.updates.isEmpty)
        XCTAssertNotNil(model.errorMessage)
    }

    func testEnablingWithPermissionSavesExpectedRevision() async throws {
        let service = FakeNotificationService()
        service.preferencesResult = .success(
            NotificationPreferences(
                items: [NotificationPreference(category: "message", enabled: false, revision: 1)]
            )
        )
        let authorizer = FakeNotificationAuthorizer()
        authorizer.currentStatus = .authorized
        let model = NotificationSettingsViewModel(service: service, authorizer: authorizer)
        await model.load()
        let item = try XCTUnwrap(model.preferences.first)

        await model.setEnabled(item, enabled: true)

        XCTAssertEqual(service.updates.count, 1)
        XCTAssertEqual(service.updates[0].category, "message")
        XCTAssertEqual(service.updates[0].enabled, true)
        XCTAssertEqual(service.updates[0].revision, 1)
        XCTAssertEqual(model.preferences.first?.enabled, true)
        XCTAssertEqual(model.preferences.first?.revision, 2)
        XCTAssertNotNil(model.infoMessage)
    }

    func testConflictReloadsServerRevision() async throws {
        let service = FakeNotificationService()
        service.preferencesResult = .success(
            NotificationPreferences(
                items: [NotificationPreference(category: "message", enabled: true, revision: 1)]
            )
        )
        let authorizer = FakeNotificationAuthorizer()
        authorizer.currentStatus = .authorized
        let model = NotificationSettingsViewModel(service: service, authorizer: authorizer)
        await model.load()
        let item = try XCTUnwrap(model.preferences.first)
        service.updateResult = .failure(
            AppError.business(code: "REVISION_CONFLICT", message: "设置已被其他设备更新")
        )
        service.preferencesResult = .success(
            NotificationPreferences(
                items: [NotificationPreference(category: "message", enabled: false, revision: 2)]
            )
        )

        await model.setEnabled(item, enabled: false)

        XCTAssertEqual(service.preferenceCalls, 2)
        XCTAssertEqual(model.preferences.first?.revision, 2)
        XCTAssertEqual(model.preferences.first?.enabled, false)
        XCTAssertEqual(model.errorMessage, "设置已被其他设备更新")
    }

    func testRequestPermissionUpdatesStatus() async {
        let authorizer = FakeNotificationAuthorizer()
        authorizer.currentStatus = .notDetermined
        authorizer.requestResult = .success(true)
        authorizer.statusAfterRequest = .authorized
        let model = NotificationSettingsViewModel(
            service: FakeNotificationService(),
            authorizer: authorizer
        )

        let granted = await model.requestPermission()

        XCTAssertTrue(granted)
        XCTAssertEqual(model.permission, .authorized)
    }
}
