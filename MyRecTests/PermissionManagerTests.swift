import XCTest
@testable import MyRecCore

class PermissionManagerTests: XCTestCase {
    var sut: PermissionManager!

    override func setUp() {
        super.setUp()
        sut = PermissionManager.shared
    }

    func testCheckMicrophonePermission() {
        let status = sut.checkMicrophonePermission()
        XCTAssertTrue([.granted, .denied, .notDetermined].contains(status))
    }

    func testCheckCameraPermission() {
        let status = sut.checkCameraPermission()
        XCTAssertTrue([.granted, .denied, .notDetermined].contains(status))
    }

    func testScreenRecordingPermissionCheck() async {
        let status = await sut.checkScreenRecordingPermission()
        XCTAssertTrue([.granted, .denied].contains(status))
    }

    func testCheckAccessibilityPermission() {
        let status = sut.checkAccessibilityPermission()
        XCTAssertTrue([.granted, .denied].contains(status))
    }

    func testRequestAccessibilityPermission() {
        // Test that requesting accessibility permission doesn't crash
        // Note: In test environment, this typically returns false
        // as tests don't have accessibility permission granted
        let result = sut.requestAccessibilityPermission()
        XCTAssertTrue(result == true || result == false)
    }
}
