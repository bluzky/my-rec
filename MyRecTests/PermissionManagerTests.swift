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
}
