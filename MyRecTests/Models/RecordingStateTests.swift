import XCTest
@testable import MyRec

class RecordingStateTests: XCTestCase {
    func testIdleState() {
        let state = RecordingState.idle

        XCTAssertTrue(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertFalse(state.isPaused)
    }

    func testRecordingState() {
        let state = RecordingState.recording(startTime: Date())

        XCTAssertFalse(state.isIdle)
        XCTAssertTrue(state.isRecording)
        XCTAssertFalse(state.isPaused)
    }

    func testPausedState() {
        let state = RecordingState.paused(elapsedTime: 10.0)

        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertTrue(state.isPaused)
    }

    func testEquatable() {
        let state1 = RecordingState.idle
        let state2 = RecordingState.idle
        XCTAssertEqual(state1, state2)

        let date = Date()
        let state3 = RecordingState.recording(startTime: date)
        let state4 = RecordingState.recording(startTime: date)
        XCTAssertEqual(state3, state4)

        let state5 = RecordingState.paused(elapsedTime: 10.0)
        let state6 = RecordingState.paused(elapsedTime: 10.0)
        XCTAssertEqual(state5, state6)
    }
}
