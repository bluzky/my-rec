import XCTest
@testable import MyRecCore

class RecordingSettingsTests: XCTestCase {
    func testDefaultSettings() {
        let settings = RecordingSettings.default

        XCTAssertEqual(settings.resolution, .fullHD)
        XCTAssertEqual(settings.frameRate, .fps30)
        XCTAssertTrue(settings.audioEnabled)
        XCTAssertFalse(settings.microphoneEnabled)
        XCTAssertFalse(settings.cameraEnabled)
        XCTAssertTrue(settings.cursorEnabled)
    }

    func testCodable() throws {
        let settings = RecordingSettings.default
        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(RecordingSettings.self, from: encoded)

        XCTAssertEqual(settings, decoded)
    }

    func testEquatable() {
        let settings1 = RecordingSettings.default
        let settings2 = RecordingSettings.default

        XCTAssertEqual(settings1, settings2)

        var settings3 = settings1
        settings3.resolution = .fourK

        XCTAssertNotEqual(settings1, settings3)
    }
}
