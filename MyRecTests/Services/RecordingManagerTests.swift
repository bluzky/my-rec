//
//  RecordingManagerTests.swift
//  MyRecTests
//
//  Created by Week 5 Backend Integration - Day 22
//

import XCTest
@testable import MyRec
#if canImport(MyRecCore)
@testable import MyRecCore
#endif
import AVFoundation
import CoreMedia

@MainActor
final class RecordingManagerTests: XCTestCase {
    var manager: RecordingManager!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create temp directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecordingManagerTests_\(UUID().uuidString)")

        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        // Create manager with custom settings
        let settingsManager = SettingsManager.shared
        settingsManager.savePath = tempDirectory

        manager = RecordingManager(settingsManager: settingsManager)
    }

    override func tearDown() async throws {
        // Cancel any active recording
        await manager.cancelRecording()
        manager = nil

        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)

        try await super.tearDown()
    }

    // MARK: - State Tests

    func testInitialState() {
        XCTAssertTrue(manager.state.isIdle, "Manager should start in idle state")
        XCTAssertEqual(manager.duration, 0, "Initial duration should be 0")
    }

    func testStateTransitionToRecording() async throws {
        // When - start recording
        try await manager.startRecording(region: CGRect(x: 0, y: 0, width: 1280, height: 720))

        // Then
        XCTAssertTrue(manager.state.isRecording, "State should be recording")
        XCTAssertGreaterThanOrEqual(manager.duration, 0, "Duration should be >= 0")

        // Cleanup
        await manager.cancelRecording()
    }

    func testStartRecordingTwiceThrowsError() async throws {
        // Given - recording is already started
        try await manager.startRecording(region: nil)

        // When/Then - attempting to start again should throw
        do {
            try await manager.startRecording(region: nil)
            XCTFail("Should throw error when starting recording twice")
        } catch let error as RecordingManager.RecordingError {
            XCTAssertEqual(error.localizedDescription, RecordingManager.RecordingError.alreadyRecording.localizedDescription)
        }

        // Cleanup
        await manager.cancelRecording()
    }

    func testStopRecordingWhenNotStartedThrowsError() async {
        // When/Then
        do {
            _ = try await manager.stopRecording()
            XCTFail("Should throw error when stopping recording that hasn't started")
        } catch let error as RecordingManager.RecordingError {
            XCTAssertEqual(error.localizedDescription, RecordingManager.RecordingError.notRecording.localizedDescription)
        }
    }

    // MARK: - Duration Tests

    func testDurationUpdates() async throws {
        // Given
        try await manager.startRecording(region: nil)

        // When - wait 1 second
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Then
        XCTAssertGreaterThan(manager.duration, 0.9, "Duration should be at least 0.9 seconds")
        XCTAssertLessThan(manager.duration, 1.5, "Duration should be less than 1.5 seconds")

        // Cleanup
        await manager.cancelRecording()
    }

    // MARK: - Cancel Tests

    func testCancelRecording() async throws {
        // Given
        try await manager.startRecording(region: nil)
        XCTAssertTrue(manager.state.isRecording, "Should be recording")

        // When
        await manager.cancelRecording()

        // Then
        XCTAssertTrue(manager.state.isIdle, "Should return to idle after cancel")
        XCTAssertEqual(manager.duration, 0, "Duration should be reset to 0")

        // Verify no files were created in temp directory
        let contents = try? FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        let mp4Files = contents?.filter { $0.pathExtension == "mp4" } ?? []
        XCTAssertTrue(mp4Files.isEmpty, "No MP4 files should remain after cancel")
    }

    func testCancelWhenNotRecordingDoesNotCrash() async {
        // When/Then - should not crash
        await manager.cancelRecording()
        XCTAssertTrue(true, "Cancel without recording should not crash")
    }

    // MARK: - Error Handling Tests

    func testRecordingErrorDescriptions() {
        let errors: [(RecordingManager.RecordingError, String)] = [
            (.alreadyRecording, "already"),
            (.notRecording, "not"),
            (.captureSetupFailed(NSError(domain: "test", code: 1)), "capture"),
            (.encodingSetupFailed(NSError(domain: "test", code: 1)), "encoder"),
            (.recordingFailed(NSError(domain: "test", code: 1)), "failed"),
            (.saveFailed(NSError(domain: "test", code: 1)), "save"),
            (.invalidState("test"), "invalid")
        ]

        for (error, expectedSubstring) in errors {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(
                description.lowercased().contains(expectedSubstring.lowercased()),
                "Error description should contain '\(expectedSubstring)' for \(error)"
            )
        }
    }

    // MARK: - Notification Tests

    func testRecordingStartPostsNotification() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Notification posted")
        var receivedState: RecordingState?

        let observer = NotificationCenter.default.addObserver(
            forName: .recordingStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            receivedState = notification.object as? RecordingState
            expectation.fulfill()
        }

        // When
        try await manager.startRecording(region: nil)

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertNotNil(receivedState, "Should receive state in notification")
        XCTAssertTrue(receivedState?.isRecording ?? false, "State should be recording")

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
        await manager.cancelRecording()
    }

    func testRecordingStopPostsNotification() async throws {
        // Given
        try await manager.startRecording(region: nil)

        let expectation = XCTestExpectation(description: "Stop notification posted")
        var receivedState: RecordingState?

        let observer = NotificationCenter.default.addObserver(
            forName: .recordingStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            receivedState = notification.object as? RecordingState
            if receivedState?.isIdle ?? false {
                expectation.fulfill()
            }
        }

        // When
        try await Task.sleep(nanoseconds: 500_000_000) // Record for 0.5 seconds
        _ = try await manager.stopRecording()

        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertNotNil(receivedState, "Should receive state in notification")
        XCTAssertTrue(receivedState?.isIdle ?? false, "State should be idle after stop")

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - End-to-End Tests (require screen permission)

    /*
    // MANUAL TEST: Complete recording flow
    func testCompleteRecordingFlow() async throws {
        // Given - start recording
        try await manager.startRecording(region: CGRect(x: 0, y: 0, width: 1280, height: 720))
        XCTAssertTrue(manager.state.isRecording)

        // When - record for 3 seconds
        try await Task.sleep(nanoseconds: 3_000_000_000)

        // Then - stop and verify
        let metadata = try await manager.stopRecording()

        XCTAssertTrue(FileManager.default.fileExists(atPath: metadata.fileURL.path))
        XCTAssertEqual(metadata.resolution.width, 1280)
        XCTAssertEqual(metadata.resolution.height, 720)
        XCTAssertGreaterThan(metadata.duration, 2.5)
        XCTAssertLessThan(metadata.duration, 3.5)
        XCTAssertGreaterThan(metadata.fileSize, 0)

        // Verify playable
        let asset = AVAsset(url: metadata.fileURL)
        let playable = try await asset.load(.isPlayable)
        XCTAssertTrue(playable)

        // Cleanup
        try? FileManager.default.removeItem(at: metadata.fileURL)
    }
    */

    /*
    // MANUAL TEST: Multiple consecutive recordings
    func testMultipleRecordings() async throws {
        var recordings: [VideoMetadata] = []

        // Record 3 short videos
        for i in 0..<3 {
            try await manager.startRecording(region: nil)
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let metadata = try await manager.stopRecording()
            recordings.append(metadata)

            XCTAssertTrue(FileManager.default.fileExists(atPath: metadata.fileURL.path))
            print("Recording \(i + 1): \(metadata.filename)")
        }

        // Verify all files exist and are unique
        XCTAssertEqual(recordings.count, 3)
        let filenames = Set(recordings.map { $0.filename })
        XCTAssertEqual(filenames.count, 3, "All filenames should be unique")

        // Cleanup
        for metadata in recordings {
            try? FileManager.default.removeItem(at: metadata.fileURL)
        }
    }
    */
}
