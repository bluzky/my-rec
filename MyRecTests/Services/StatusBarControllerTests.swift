//
//  StatusBarControllerTests.swift
//  MyRecTests
//
//  Created by Week 2 Implementation
//

import XCTest
@testable import MyRec
#if canImport(MyRecCore)
@testable import MyRecCore
#endif

final class StatusBarControllerTests: XCTestCase {
    var notificationExpectation: XCTestExpectation?

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        notificationExpectation = nil
        super.tearDown()
    }

    // MARK: - Notification Names Tests

    func testNotificationNamesExist() {
        // Verify notification names are properly defined
        XCTAssertEqual(Notification.Name.startRecording.rawValue, "startRecording")
        XCTAssertEqual(Notification.Name.pauseRecording.rawValue, "pauseRecording")
        XCTAssertEqual(Notification.Name.stopRecording.rawValue, "stopRecording")
        XCTAssertEqual(Notification.Name.openSettings.rawValue, "openSettings")
        XCTAssertEqual(Notification.Name.recordingStateChanged.rawValue, "recordingStateChanged")
    }

    // MARK: - Notification Posting Tests

    func testStartRecordingNotificationCanBePosted() {
        notificationExpectation = expectation(description: "Start recording notification posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .startRecording,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notificationExpectation?.fulfill()
        }

        NotificationCenter.default.post(name: .startRecording, object: nil)

        wait(for: [notificationExpectation!], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
    }

    func testPauseRecordingNotificationCanBePosted() {
        notificationExpectation = expectation(description: "Pause recording notification posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .pauseRecording,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notificationExpectation?.fulfill()
        }

        NotificationCenter.default.post(name: .pauseRecording, object: nil)

        wait(for: [notificationExpectation!], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
    }

    func testStopRecordingNotificationCanBePosted() {
        notificationExpectation = expectation(description: "Stop recording notification posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .stopRecording,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notificationExpectation?.fulfill()
        }

        NotificationCenter.default.post(name: .stopRecording, object: nil)

        wait(for: [notificationExpectation!], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
    }

    func testOpenSettingsNotificationCanBePosted() {
        notificationExpectation = expectation(description: "Open settings notification posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .openSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notificationExpectation?.fulfill()
        }

        NotificationCenter.default.post(name: .openSettings, object: nil)

        wait(for: [notificationExpectation!], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - RecordingState Tests

    func testRecordingStateIdle() {
        let state = RecordingState.idle
        XCTAssertTrue(state.isIdle, "State should be idle")
        XCTAssertFalse(state.isRecording, "State should not be recording")
        XCTAssertFalse(state.isPaused, "State should not be paused")
    }

    func testRecordingStateRecording() {
        let state = RecordingState.recording(startTime: Date())
        XCTAssertFalse(state.isIdle, "State should not be idle")
        XCTAssertTrue(state.isRecording, "State should be recording")
        XCTAssertFalse(state.isPaused, "State should not be paused")
    }

    func testRecordingStatePaused() {
        let state = RecordingState.paused(elapsedTime: 10.0)
        XCTAssertFalse(state.isIdle, "State should not be idle")
        XCTAssertFalse(state.isRecording, "State should not be recording")
        XCTAssertTrue(state.isPaused, "State should be paused")
    }
}
