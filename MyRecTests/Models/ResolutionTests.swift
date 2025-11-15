import XCTest
@testable import MyRec

class ResolutionTests: XCTestCase {
    func testResolutionDimensions() {
        XCTAssertEqual(Resolution.hd.width, 1280)
        XCTAssertEqual(Resolution.hd.height, 720)
        XCTAssertEqual(Resolution.fullHD.width, 1920)
        XCTAssertEqual(Resolution.fullHD.height, 1080)
        XCTAssertEqual(Resolution.twoK.width, 2560)
        XCTAssertEqual(Resolution.twoK.height, 1440)
        XCTAssertEqual(Resolution.fourK.width, 3840)
        XCTAssertEqual(Resolution.fourK.height, 2160)
    }

    func testResolutionCodable() throws {
        let resolution = Resolution.fullHD
        let encoded = try JSONEncoder().encode(resolution)
        let decoded = try JSONDecoder().decode(Resolution.self, from: encoded)
        XCTAssertEqual(resolution, decoded)
    }

    func testAllCases() {
        XCTAssertEqual(Resolution.allCases.count, 5)
        XCTAssertTrue(Resolution.allCases.contains(.hd))
        XCTAssertTrue(Resolution.allCases.contains(.fullHD))
        XCTAssertTrue(Resolution.allCases.contains(.twoK))
        XCTAssertTrue(Resolution.allCases.contains(.fourK))
        XCTAssertTrue(Resolution.allCases.contains(.custom))
    }
}
