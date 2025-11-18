//
//  MockRecordingTests.swift
//  MyRecTests
//
//  Tests for MockRecording data model and generator
//

import XCTest
@testable import MyRecCore

final class MockRecordingTests: XCTestCase {

    // MARK: - MockRecording Tests

    func testMockRecordingInitialization() {
        let date = Date()
        let recording = MockRecording(
            filename: "test.mp4",
            duration: 300,
            resolution: .fullHD,
            frameRate: .fps30,
            fileSize: 100_000_000,
            createdDate: date
        )

        XCTAssertEqual(recording.filename, "test.mp4")
        XCTAssertEqual(recording.duration, 300)
        XCTAssertEqual(recording.resolution, .fullHD)
        XCTAssertEqual(recording.frameRate, .fps30)
        XCTAssertEqual(recording.fileSize, 100_000_000)
        XCTAssertEqual(recording.createdDate, date)
    }

    func testDurationString_ShortDuration() {
        let recording = MockRecording(
            filename: "test.mp4",
            duration: 125, // 2:05
            resolution: .fullHD,
            frameRate: .fps30,
            fileSize: 100_000_000,
            createdDate: Date()
        )

        XCTAssertEqual(recording.durationString, "02:05")
    }

    func testDurationString_LongDuration() {
        let recording = MockRecording(
            filename: "test.mp4",
            duration: 3665, // 1:01:05
            resolution: .fullHD,
            frameRate: .fps30,
            fileSize: 100_000_000,
            createdDate: Date()
        )

        XCTAssertEqual(recording.durationString, "01:01:05")
    }

    func testFileSizeString() {
        let recording = MockRecording(
            filename: "test.mp4",
            duration: 300,
            resolution: .fullHD,
            frameRate: .fps30,
            fileSize: 150_000_000, // ~150 MB
            createdDate: Date()
        )

        let sizeString = recording.fileSizeString
        XCTAssertTrue(sizeString.contains("MB") || sizeString.contains("GB"))
    }

    func testDateString_Today() {
        let recording = MockRecording(
            filename: "test.mp4",
            duration: 300,
            resolution: .fullHD,
            frameRate: .fps30,
            fileSize: 100_000_000,
            createdDate: Date() // Today
        )

        XCTAssertEqual(recording.dateString, "Today")
    }

    func testDateString_Yesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let recording = MockRecording(
            filename: "test.mp4",
            duration: 300,
            resolution: .fullHD,
            frameRate: .fps30,
            fileSize: 100_000_000,
            createdDate: yesterday
        )

        XCTAssertEqual(recording.dateString, "Yesterday")
    }

    func testDateString_DaysAgo() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let recording = MockRecording(
            filename: "test.mp4",
            duration: 300,
            resolution: .fullHD,
            frameRate: .fps30,
            fileSize: 100_000_000,
            createdDate: threeDaysAgo
        )

        XCTAssertEqual(recording.dateString, "3 days ago")
    }

    func testMetadataString() {
        let recording = MockRecording(
            filename: "test.mp4",
            duration: 332, // 5:32
            resolution: .fullHD,
            frameRate: .fps30,
            fileSize: 142_300_000,
            createdDate: Date()
        )

        let metadata = recording.metadataString
        XCTAssertTrue(metadata.contains("1920×1080"))
        XCTAssertTrue(metadata.contains("30 FPS"))
        XCTAssertTrue(metadata.contains("05:32"))
        XCTAssertTrue(metadata.contains("MB"))
    }

    func testIdentifiableConformance() {
        let recording1 = MockRecording(
            filename: "test1.mp4",
            duration: 300,
            resolution: .fullHD,
            frameRate: .fps30,
            fileSize: 100_000_000,
            createdDate: Date()
        )

        let recording2 = MockRecording(
            filename: "test2.mp4",
            duration: 300,
            resolution: .fullHD,
            frameRate: .fps30,
            fileSize: 100_000_000,
            createdDate: Date()
        )

        XCTAssertNotEqual(recording1.id, recording2.id)
    }

    // MARK: - MockRecordingGenerator Tests

    func testGenerateRandomRecording() {
        let recording = MockRecordingGenerator.randomRecording()

        XCTAssertFalse(recording.filename.isEmpty)
        XCTAssertTrue(recording.filename.hasPrefix("MyRecord-"))
        XCTAssertTrue(recording.filename.hasSuffix(".mp4"))
        XCTAssertGreaterThan(recording.duration, 0)
        XCTAssertGreaterThan(recording.fileSize, 0)
    }

    func testGenerateRandomRecording_DaysAgo() {
        let recording = MockRecordingGenerator.randomRecording(daysAgo: 3)
        let calendar = Calendar.current
        let now = Date()

        let daysDifference = calendar.dateComponents([.day], from: recording.createdDate, to: now).day ?? 0
        XCTAssertEqual(daysDifference, 3)
    }

    func testGenerateMultipleRecordings() {
        let recordings = MockRecordingGenerator.generate(count: 10)

        XCTAssertEqual(recordings.count, 10)

        // Check all recordings are unique
        let uniqueIds = Set(recordings.map { $0.id })
        XCTAssertEqual(uniqueIds.count, 10)

        // Check sorted by date (newest first)
        for i in 0..<recordings.count-1 {
            XCTAssertGreaterThanOrEqual(recordings[i].createdDate, recordings[i+1].createdDate)
        }
    }

    func testGenerateRecordingsInDateRange() {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!

        let recordings = MockRecordingGenerator.generate(from: startDate, to: endDate, count: 5)

        XCTAssertEqual(recordings.count, 5)

        // Check all recordings are within date range
        for recording in recordings {
            XCTAssertGreaterThanOrEqual(recording.createdDate, startDate)
            XCTAssertLessThanOrEqual(recording.createdDate, endDate)
        }

        // Check sorted by date (newest first)
        for i in 0..<recordings.count-1 {
            XCTAssertGreaterThanOrEqual(recordings[i].createdDate, recordings[i+1].createdDate)
        }
    }

    func testGenerateRecordings_VariedMetadata() {
        let recordings = MockRecordingGenerator.generate(count: 20)

        // Check we have variety in resolutions
        let resolutions = Set(recordings.map { $0.resolution })
        XCTAssertGreaterThan(resolutions.count, 1, "Should have varied resolutions")

        // Check we have variety in frame rates
        let frameRates = Set(recordings.map { $0.frameRate })
        XCTAssertGreaterThan(frameRates.count, 1, "Should have varied frame rates")

        // Check we have variety in durations
        let durations = Set(recordings.map { Int($0.duration / 60) }) // Group by minute
        XCTAssertGreaterThan(durations.count, 1, "Should have varied durations")
    }

    func testFileSizeCalculation_ScalesWithParameters() {
        let recordings = MockRecordingGenerator.generate(count: 100)

        // Higher resolution should generally mean larger file size for same duration
        let hdRecordings = recordings.filter { $0.resolution == .hd }
        let fourKRecordings = recordings.filter { $0.resolution == .fourK }

        if !hdRecordings.isEmpty && !fourKRecordings.isEmpty {
            let avgHDSize = hdRecordings.map { Double($0.fileSize) / $0.duration }.reduce(0, +) / Double(hdRecordings.count)
            let avg4kSize = fourKRecordings.map { Double($0.fileSize) / $0.duration }.reduce(0, +) / Double(fourKRecordings.count)

            XCTAssertGreaterThan(avg4kSize, avgHDSize, "4K should have larger average bitrate than 720p")
        }
    }

    func testSampleData() {
        // Test that sample data is accessible
        let sample = MockRecording.sample
        XCTAssertEqual(sample.filename, "MyRecord-20251116103045.mp4")
        XCTAssertEqual(sample.duration, 332)
        XCTAssertEqual(sample.resolution, .fullHD)

        let samples = MockRecording.samples
        XCTAssertEqual(samples.count, 10)
    }
}
