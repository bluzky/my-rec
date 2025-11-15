import XCTest
@testable import MyRecCore

class SettingsManagerTests: XCTestCase {
    var sut: SettingsManager!

    override func setUp() {
        super.setUp()
        sut = SettingsManager.shared
        // Reset to defaults before each test to ensure clean state
        sut.reset()
    }

    func testDefaultSettings() {
        // After reset, should have default values
        XCTAssertEqual(sut.defaultResolution, .fullHD)
        XCTAssertEqual(sut.defaultFrameRate, .fps30)
        XCTAssertFalse(sut.launchAtLogin)
    }

    func testSaveAndLoad() {
        sut.defaultResolution = .fourK
        sut.defaultFrameRate = .fps60
        sut.launchAtLogin = true

        sut.save()

        XCTAssertEqual(sut.defaultResolution, .fourK)
        XCTAssertEqual(sut.defaultFrameRate, .fps60)
        XCTAssertTrue(sut.launchAtLogin)
    }

    func testReset() {
        sut.defaultResolution = .fourK
        sut.launchAtLogin = true

        sut.reset()

        XCTAssertEqual(sut.defaultResolution, .fullHD)
        XCTAssertFalse(sut.launchAtLogin)
    }
}
