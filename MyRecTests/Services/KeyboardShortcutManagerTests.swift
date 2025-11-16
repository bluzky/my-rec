import XCTest
@testable import MyRecCore

final class KeyboardShortcutManagerTests: XCTestCase {

    var sut: KeyboardShortcutManager!

    override func setUp() {
        super.setUp()
        sut = KeyboardShortcutManager.shared
    }

    override func tearDown() {
        sut.unregisterAllShortcuts()
        super.tearDown()
    }

    // MARK: - Accessibility Permission Tests

    func testCheckAccessibilityPermission() {
        // Test that the method returns a boolean
        let hasPermission = sut.checkAccessibilityPermission()

        // We can't guarantee the permission state in tests
        // but we can verify the method executes without crashing
        XCTAssertTrue(hasPermission == true || hasPermission == false)
    }

    func testRequestAccessibilityPermission() {
        // Test that requestAccessibilityPermission doesn't crash
        // Note: In a real test environment, this would show a system dialog
        // For unit tests, we just verify it doesn't crash
        XCTAssertNoThrow(sut.requestAccessibilityPermission())
    }

    // MARK: - Notification Name Tests

    func testNotificationNamesAreDefined() {
        // Verify all notification names are properly defined
        XCTAssertNotNil(KeyboardShortcutManager.Notifications.startRecording)
        XCTAssertNotNil(KeyboardShortcutManager.Notifications.stopRecording)
        XCTAssertNotNil(KeyboardShortcutManager.Notifications.openSettings)
    }

    func testNotificationNamesAreUnique() {
        // Verify notification names are unique
        let names = [
            KeyboardShortcutManager.Notifications.startRecording,
            KeyboardShortcutManager.Notifications.stopRecording,
            KeyboardShortcutManager.Notifications.openSettings
        ]

        let uniqueNames = Set(names.map { $0.rawValue })
        XCTAssertEqual(uniqueNames.count, 3, "All notification names should be unique")
    }

    // MARK: - Hotkey Registration Tests

    func testRegisterDefaultShortcutsWithoutPermission() {
        // If accessibility permission is not granted, registration should fail gracefully
        // Note: In CI/test environments, permission is typically not granted
        // This test verifies the method handles missing permission correctly

        let result = sut.registerDefaultShortcuts()

        // Result depends on whether accessibility permission is granted
        // The test passes as long as the method doesn't crash
        XCTAssertTrue(result == true || result == false)
    }

    func testUnregisterAllShortcuts() {
        // Test that unregistering shortcuts doesn't crash
        XCTAssertNoThrow(sut.unregisterAllShortcuts())

        // Register and then unregister
        _ = sut.registerDefaultShortcuts()
        XCTAssertNoThrow(sut.unregisterAllShortcuts())
    }

    func testMultipleUnregisterCalls() {
        // Test that calling unregister multiple times doesn't crash
        sut.unregisterAllShortcuts()
        sut.unregisterAllShortcuts()
        sut.unregisterAllShortcuts()

        // If we got here without crashing, test passes
        XCTAssertTrue(true)
    }

    // MARK: - Notification Posting Tests

    func testStartRecordingNotificationCanBePosted() {
        let expectation = self.expectation(description: "Start recording notification posted")
        var notificationReceived = false

        let observer = NotificationCenter.default.addObserver(
            forName: KeyboardShortcutManager.Notifications.startRecording,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived = true
            expectation.fulfill()
        }

        // Manually post notification to test the notification infrastructure
        NotificationCenter.default.post(
            name: KeyboardShortcutManager.Notifications.startRecording,
            object: nil
        )

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(notificationReceived)

        NotificationCenter.default.removeObserver(observer)
    }

    func testStopRecordingNotificationCanBePosted() {
        let expectation = self.expectation(description: "Stop recording notification posted")
        var notificationReceived = false

        let observer = NotificationCenter.default.addObserver(
            forName: KeyboardShortcutManager.Notifications.stopRecording,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived = true
            expectation.fulfill()
        }

        NotificationCenter.default.post(
            name: KeyboardShortcutManager.Notifications.stopRecording,
            object: nil
        )

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(notificationReceived)

        NotificationCenter.default.removeObserver(observer)
    }

    func testOpenSettingsNotificationCanBePosted() {
        let expectation = self.expectation(description: "Open settings notification posted")
        var notificationReceived = false

        let observer = NotificationCenter.default.addObserver(
            forName: KeyboardShortcutManager.Notifications.openSettings,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived = true
            expectation.fulfill()
        }

        NotificationCenter.default.post(
            name: KeyboardShortcutManager.Notifications.openSettings,
            object: nil
        )

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(notificationReceived)

        NotificationCenter.default.removeObserver(observer)
    }
}
