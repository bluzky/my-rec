import XCTest
@testable import MyRec

class FrameRateTests: XCTestCase {
    func testFrameRateValues() {
        XCTAssertEqual(FrameRate.fps15.value, 15)
        XCTAssertEqual(FrameRate.fps24.value, 24)
        XCTAssertEqual(FrameRate.fps30.value, 30)
        XCTAssertEqual(FrameRate.fps60.value, 60)
    }

    func testDisplayName() {
        XCTAssertEqual(FrameRate.fps30.displayName, "30 FPS")
        XCTAssertEqual(FrameRate.fps60.displayName, "60 FPS")
    }

    func testCodable() throws {
        let frameRate = FrameRate.fps30
        let encoded = try JSONEncoder().encode(frameRate)
        let decoded = try JSONDecoder().decode(FrameRate.self, from: encoded)
        XCTAssertEqual(frameRate, decoded)
    }

    func testAllCases() {
        XCTAssertEqual(FrameRate.allCases.count, 4)
        XCTAssertTrue(FrameRate.allCases.contains(.fps15))
        XCTAssertTrue(FrameRate.allCases.contains(.fps24))
        XCTAssertTrue(FrameRate.allCases.contains(.fps30))
        XCTAssertTrue(FrameRate.allCases.contains(.fps60))
    }
}
