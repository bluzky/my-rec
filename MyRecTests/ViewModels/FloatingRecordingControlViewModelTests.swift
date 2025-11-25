//
//  FloatingRecordingControlViewModelTests.swift
//  MyRecTests
//
//  Unit tests for FloatingRecordingControlViewModel
//

import XCTest
@testable import MyRec
#if canImport(MyRecCore)
import MyRecCore
#endif

class FloatingRecordingControlViewModelTests: XCTestCase {

    var viewModel: FloatingRecordingControlViewModel!

    override func setUp() {
        super.setUp()
        viewModel = FloatingRecordingControlViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(viewModel.elapsedTime, 0, "Initial elapsed time should be 0")
        XCTAssertFalse(viewModel.isPaused, "Initial paused state should be false")
        XCTAssertEqual(viewModel.formattedElapsedTime, "00:00", "Initial formatted time should be 00:00")
    }

    // MARK: - Recording State Tests

    func testRecordingStateChangedToRecording() {
        let startTime = Date()
        let state = RecordingState.recording(startTime: startTime)

        // Post notification
        NotificationCenter.default.post(
            name: .recordingStateChanged,
            object: state
        )

        // Wait briefly for timer to update
        let expectation = XCTestExpectation(description: "Timer updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertFalse(viewModel.isPaused, "Should not be paused during recording")
        XCTAssertGreaterThan(viewModel.elapsedTime, 0, "Elapsed time should be greater than 0")
    }

    func testRecordingStateChangedToPaused() {
        let pausedTime: TimeInterval = 30.5
        let state = RecordingState.paused(elapsedTime: pausedTime)

        // Post notification
        NotificationCenter.default.post(
            name: .recordingStateChanged,
            object: state
        )

        // Wait for notification processing
        let expectation = XCTestExpectation(description: "State updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(viewModel.isPaused, "Should be paused")
        XCTAssertEqual(viewModel.elapsedTime, pausedTime, "Elapsed time should match paused time")
    }

    func testRecordingStateChangedToIdle() {
        // First start recording
        let startTime = Date()
        NotificationCenter.default.post(
            name: .recordingStateChanged,
            object: RecordingState.recording(startTime: startTime)
        )

        // Wait for timer to run
        let expectation1 = XCTestExpectation(description: "Timer started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)

        // Then stop recording
        NotificationCenter.default.post(
            name: .recordingStateChanged,
            object: RecordingState.idle
        )

        // Wait for state update
        let expectation2 = XCTestExpectation(description: "State reset")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)

        XCTAssertEqual(viewModel.elapsedTime, 0, "Elapsed time should be reset to 0")
        XCTAssertFalse(viewModel.isPaused, "Should not be paused")
    }

    // MARK: - Formatted Time Tests

    func testFormattedElapsedTimeMinutesSeconds() {
        // Simulate 1 minute 30 seconds
        let startTime = Date().addingTimeInterval(-90)
        NotificationCenter.default.post(
            name: .recordingStateChanged,
            object: RecordingState.recording(startTime: startTime)
        )

        // Wait for timer update
        let expectation = XCTestExpectation(description: "Timer updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(viewModel.formattedElapsedTime.hasPrefix("01:"), "Should show 01:XX format")
    }

    func testFormattedElapsedTimeHours() {
        // Simulate 1 hour 5 minutes 30 seconds
        let startTime = Date().addingTimeInterval(-3930)
        NotificationCenter.default.post(
            name: .recordingStateChanged,
            object: RecordingState.recording(startTime: startTime)
        )

        // Wait for timer update
        let expectation = XCTestExpectation(description: "Timer updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(viewModel.formattedElapsedTime.hasPrefix("01:"), "Should show hours format")
        XCTAssertTrue(viewModel.formattedElapsedTime.contains(":"), "Should contain hour:minute:second separators")
    }

    // MARK: - Action Tests

    func testTogglePauseFromRecording() {
        // Start recording first
        NotificationCenter.default.post(
            name: .recordingStateChanged,
            object: RecordingState.recording(startTime: Date())
        )

        // Wait for state update
        let expectation1 = XCTestExpectation(description: "Recording started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)

        // Set up notification expectation
        let expectation2 = XCTestExpectation(description: "Pause notification posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .recordingStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let state = notification.object as? RecordingState, state.isPaused {
                expectation2.fulfill()
            }
        }

        // Toggle pause
        viewModel.togglePause()

        wait(for: [expectation2], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testTogglePauseFromPaused() {
        // Set to paused state first
        NotificationCenter.default.post(
            name: .recordingStateChanged,
            object: RecordingState.paused(elapsedTime: 30)
        )

        // Wait for state update
        let expectation1 = XCTestExpectation(description: "Paused state set")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)

        // Set up notification expectation
        let expectation2 = XCTestExpectation(description: "Resume notification posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .recordingStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let state = notification.object as? RecordingState, state.isRecording {
                expectation2.fulfill()
            }
        }

        // Toggle resume
        viewModel.togglePause()

        wait(for: [expectation2], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testStopRecording() {
        // Set up notification expectation
        let expectation = XCTestExpectation(description: "Stop notification posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .stopRecording,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // Call stop
        viewModel.stopRecording()

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
