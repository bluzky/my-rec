import XCTest
@testable import MyRecCore

class VideoMetadataTests: XCTestCase {
    func testFileSizeString() {
        let metadata = VideoMetadata(
            filename: "test.mp4",
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            fileSize: 1024 * 1024, // 1 MB
            duration: 60,
            resolution: CGSize(width: 1920, height: 1080),
            frameRate: 30,
            createdAt: Date(),
            format: "mp4"
        )

        XCTAssertTrue(metadata.fileSizeString.contains("MB"))
    }

    func testDurationString() {
        let metadata1 = VideoMetadata(
            filename: "test.mp4",
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            fileSize: 1024,
            duration: 65, // 1 min 5 sec
            resolution: CGSize(width: 1920, height: 1080),
            frameRate: 30,
            createdAt: Date(),
            format: "mp4"
        )
        XCTAssertEqual(metadata1.durationString, "01:05")

        let metadata2 = VideoMetadata(
            filename: "test.mp4",
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            fileSize: 1024,
            duration: 3665, // 1 hr 1 min 5 sec
            resolution: CGSize(width: 1920, height: 1080),
            frameRate: 30,
            createdAt: Date(),
            format: "mp4"
        )
        XCTAssertEqual(metadata2.durationString, "01:01:05")
    }

    func testResolutionString() {
        let metadata = VideoMetadata(
            filename: "test.mp4",
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            fileSize: 1024,
            duration: 60,
            resolution: CGSize(width: 1920, height: 1080),
            frameRate: 30,
            createdAt: Date(),
            format: "mp4"
        )

        XCTAssertEqual(metadata.resolutionString, "1920 × 1080")
    }
}
