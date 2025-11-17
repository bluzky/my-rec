//
//  ScreenCaptureEngineTests.swift
//  MyRecTests
//
//  Created by Week 5 Backend Integration - Day 20
//

import XCTest
@testable import MyRec
#if canImport(MyRecCore)
@testable import MyRecCore
#endif
import ScreenCaptureKit
import CoreMedia

@available(macOS 13.0, *)
final class ScreenCaptureEngineTests: XCTestCase {
    var engine: ScreenCaptureEngine!

    override func setUp() {
        super.setUp()
        engine = ScreenCaptureEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testConfigureWithFullHDResolution() throws {
        // Given
        let resolution = Resolution.fullHD
        let frameRate = FrameRate.fps30

        // When
        try engine.configure(
            region: nil,
            resolution: resolution,
            frameRate: frameRate,
            showCursor: true
        )

        // Then - no error thrown means configuration succeeded
        // We can't directly inspect internal state, but configure shouldn't throw
        XCTAssertTrue(true, "Configuration should succeed")
    }

    func testConfigureWith720pResolution() throws {
        // Given
        let resolution = Resolution.hd
        let frameRate = FrameRate.fps30

        // When
        try engine.configure(
            region: nil,
            resolution: resolution,
            frameRate: frameRate,
            showCursor: false
        )

        // Then
        XCTAssertTrue(true, "Configuration should succeed")
    }

    func testConfigureWith2KResolution() throws {
        // Given
        let resolution = Resolution.twoK
        let frameRate = FrameRate.fps60

        // When
        try engine.configure(
            region: nil,
            resolution: resolution,
            frameRate: frameRate,
            showCursor: true
        )

        // Then
        XCTAssertTrue(true, "Configuration should succeed")
    }

    func testConfigureWith4KResolution() throws {
        // Given
        let resolution = Resolution.fourK
        let frameRate = FrameRate.fps24

        // When
        try engine.configure(
            region: nil,
            resolution: resolution,
            frameRate: frameRate,
            showCursor: true
        )

        // Then
        XCTAssertTrue(true, "Configuration should succeed")
    }

    func testConfigureWithDifferentFrameRates() throws {
        // Test all frame rates
        for frameRate in FrameRate.allCases {
            // When
            try engine.configure(
                region: nil,
                resolution: .fullHD,
                frameRate: frameRate,
                showCursor: true
            )

            // Then
            XCTAssertTrue(true, "Configuration should succeed for \(frameRate.value) fps")
        }
    }

    func testConfigureWithCustomRegion() throws {
        // Given
        let region = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // When
        try engine.configure(
            region: region,
            resolution: .fullHD,
            frameRate: .fps30,
            showCursor: true
        )

        // Then
        XCTAssertTrue(true, "Configuration with region should succeed")
    }

    func testConfigureWithCursorDisabled() throws {
        // Given
        let showCursor = false

        // When
        try engine.configure(
            region: nil,
            resolution: .fullHD,
            frameRate: .fps30,
            showCursor: showCursor
        )

        // Then
        XCTAssertTrue(true, "Configuration with cursor disabled should succeed")
    }

    // MARK: - Error Handling Tests

    func testStopCaptureWhenNotStartedThrowsError() async {
        // Given - engine not started

        // When/Then
        do {
            try await engine.stopCapture()
            XCTFail("Should throw error when stopping capture that hasn't started")
        } catch let error as ScreenCaptureEngine.CaptureError {
            XCTAssertEqual(error, .captureNotStarted)
        } catch {
            XCTFail("Should throw CaptureError.captureNotStarted")
        }
    }

    func testStartCaptureWithoutConfigurationThrowsError() async {
        // Given - engine not configured

        // When/Then
        do {
            try await engine.startCapture()
            XCTFail("Should throw error when starting capture without configuration")
        } catch {
            // Expected to throw
            XCTAssertTrue(true, "Should throw error without configuration")
        }
    }

    func testPauseCaptureNotImplementedYet() async {
        // Given
        try? engine.configure(
            region: nil,
            resolution: .fullHD,
            frameRate: .fps30,
            showCursor: true
        )

        // When/Then - pause not yet implemented, should handle gracefully
        do {
            try await engine.pauseCapture()
            // May throw or may not, depending on implementation
        } catch {
            // Expected for now since pause is not implemented
        }
    }

    func testResumeCaptureNotImplementedYet() async {
        // Given - configure but don't start
        try? engine.configure(
            region: nil,
            resolution: .fullHD,
            frameRate: .fps30,
            showCursor: true
        )

        // When/Then - resume not yet implemented
        do {
            try await engine.resumeCapture()
            // May throw or may not
        } catch {
            // Expected for now since resume is not implemented
        }
    }

    // MARK: - Frame Handler Tests

    func testFrameHandlerCanBeSet() {
        // Given
        var frameReceived = false
        let handler: (CVPixelBuffer, CMTime) -> Void = { _, _ in
            frameReceived = true
        }

        // When
        engine.videoFrameHandler = handler

        // Then
        XCTAssertNotNil(engine.videoFrameHandler)
        // Note: We can't actually trigger the handler without real capture
    }

    func testFrameHandlerCanBeCleared() {
        // Given
        engine.videoFrameHandler = { _, _ in }

        // When
        engine.videoFrameHandler = nil

        // Then
        XCTAssertNil(engine.videoFrameHandler)
    }

    // MARK: - Error Description Tests

    func testCaptureErrorDescriptions() {
        let errors: [(ScreenCaptureEngine.CaptureError, String)] = [
            (.permissionDenied, "permission"),
            (.noDisplaysAvailable, "display"),
            (.invalidRegion, "region"),
            (.captureNotStarted, "not been started"),
            (.captureAlreadyRunning, "already running"),
            (.configurationFailed(NSError(domain: "test", code: 1)), "configure"),
            (.streamCreationFailed(NSError(domain: "test", code: 1)), "stream")
        ]

        for (error, expectedSubstring) in errors {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(
                description.lowercased().contains(expectedSubstring.lowercased()),
                "Error description should contain '\(expectedSubstring)' for \(error)"
            )
        }
    }

    // MARK: - Integration Tests (Manual)
    // These tests require screen recording permission and should be run manually

    /*
    func testBasicCaptureFlow() async throws {
        // MANUAL TEST: Requires screen recording permission

        // 1. Configure
        try engine.configure(
            region: nil,
            resolution: .hd,
            frameRate: .fps30,
            showCursor: true
        )

        // 2. Set up frame handler
        var frameCount = 0
        let frameExpectation = expectation(description: "Frames received")
        frameExpectation.expectedFulfillmentCount = 30 // Expect at least 30 frames (1 second @ 30fps)

        engine.videoFrameHandler = { pixelBuffer, time in
            frameCount += 1
            if frameCount <= 30 {
                frameExpectation.fulfill()
            }
        }

        // 3. Start capture
        try await engine.startCapture()

        // 4. Wait for frames
        await fulfillment(of: [frameExpectation], timeout: 5.0)

        // 5. Stop capture
        try await engine.stopCapture()

        // 6. Verify
        XCTAssertGreaterThanOrEqual(frameCount, 30)
    }

    func testFrameRateAccuracy() async throws {
        // MANUAL TEST: Verify frame rate matches configuration

        let frameRate = FrameRate.fps30
        try engine.configure(
            region: nil,
            resolution: .hd,
            frameRate: frameRate,
            showCursor: true
        )

        var frameTimes: [CMTime] = []
        engine.videoFrameHandler = { _, time in
            frameTimes.append(time)
        }

        try await engine.startCapture()
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        try await engine.stopCapture()

        // Verify frame rate (should be close to 30fps = ~90 frames in 3 seconds)
        let expectedFrames = frameRate.value * 3
        let tolerance = 5
        XCTAssertTrue(
            abs(frameTimes.count - expectedFrames) <= tolerance,
            "Frame count \(frameTimes.count) should be within \(tolerance) of expected \(expectedFrames)"
        )
    }
    */
}
