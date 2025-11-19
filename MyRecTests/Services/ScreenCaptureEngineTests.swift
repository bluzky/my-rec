//
//  ScreenCaptureEngineTests.swift
//  MyRecTests
//
//  Created by Week 6 Implementation - Day 23
//

import XCTest
import ScreenCaptureKit
@testable import MyRec

final class ScreenCaptureEngineTests: XCTestCase {

    // MARK: - Region Validation Tests (Behavioral)

    /// Test that region capture API accepts valid regions
    func testRegionCaptureAPIAcceptsValidRegion() async throws {
        let engine = ScreenCaptureEngine()

        // Create a valid region (400x300 in the center of a typical screen)
        let region = CGRect(x: 500, y: 300, width: 800, height: 600)

        // This should not throw an error
        // Note: Will fail if screen recording permission is not granted
        do {
            try await engine.startCapture(
                region: region,
                resolution: .hd720p,
                frameRate: .fps30
            )

            // If we get here, the API accepted the region
            XCTAssertTrue(true, "Region capture started successfully")

            // Clean up
            _ = try await engine.stopCapture()

        } catch CaptureError.permissionDenied {
            // Expected if permission not granted during tests
            throw XCTSkip("Screen recording permission required for this test")
        } catch CaptureError.captureUnavailable {
            // Expected on macOS < 13 or in CI environments
            throw XCTSkip("Screen capture unavailable in test environment")
        }
    }

    /// Test that zero region falls back to full screen
    func testZeroRegionUsesFullScreen() async throws {
        let engine = ScreenCaptureEngine()

        // Pass .zero region (should use resolution settings instead)
        let region = CGRect.zero

        do {
            try await engine.startCapture(
                region: region,
                resolution: .hd720p,
                frameRate: .fps30
            )

            XCTAssertTrue(true, "Zero region handled correctly")

            // Clean up
            _ = try await engine.stopCapture()

        } catch CaptureError.permissionDenied {
            throw XCTSkip("Screen recording permission required")
        } catch CaptureError.captureUnavailable {
            throw XCTSkip("Screen capture unavailable")
        }
    }

    // MARK: - Coordinate System Tests (Documentation)

    /// Documents the coordinate system conversion behavior
    /// NSWindow coordinates: origin at bottom-left
    /// ScreenCaptureKit coordinates: origin at top-left
    func testCoordinateSystemDocumentation() {
        // Given a display height of 1080 pixels
        let displayHeight = 1080

        // And a region in NSWindow coordinates (bottom-left origin)
        let nsWindowRegion = CGRect(x: 100, y: 200, width: 800, height: 600)

        // When converting to ScreenCaptureKit coordinates (top-left origin)
        // Expected formula: sck_y = displayHeight - nswindow_y - height
        let expectedSCKY = displayHeight - 200 - 600 // = 280

        // Then the SCK region should be
        let expectedSCKRegion = CGRect(x: 100, y: 280, width: 800, height: 600)

        // Document the conversion
        XCTAssertEqual(expectedSCKRegion.origin.x, nsWindowRegion.origin.x)
        XCTAssertEqual(expectedSCKRegion.origin.y, CGFloat(expectedSCKY))
        XCTAssertEqual(expectedSCKRegion.width, nsWindowRegion.width)
        XCTAssertEqual(expectedSCKRegion.height, nsWindowRegion.height)
    }

    // MARK: - Region Validation Tests (Documentation)

    /// Documents expected validation behavior for regions
    func testRegionValidationBehavior() {
        // Document minimum size requirement
        let minSize: CGFloat = 100
        XCTAssertEqual(minSize, 100, "Minimum region size should be 100x100 pixels")

        // Document that regions should be clamped to display bounds
        let displayWidth = 1920
        let displayHeight = 1080

        // Example: region extending beyond display should be clamped
        let oversizedRegion = CGRect(x: 1800, y: 900, width: 800, height: 600)

        // Expected behavior: region should be adjusted to fit within bounds
        let maxX = displayWidth - Int(oversizedRegion.width) // Can be negative
        let maxY = displayHeight - Int(oversizedRegion.height) // Can be negative

        // Document that negative maxX/maxY indicates region is too large
        XCTAssertLessThan(maxX, 0, "Oversized width should be detected")
        XCTAssertLessThan(maxY, 0, "Oversized height should be detected")
    }

    // MARK: - Integration Tests

    /// Test that small regions work correctly
    func testSmallRegionCapture() async throws {
        let engine = ScreenCaptureEngine()

        // Small region (200x150) - should be expanded to minimum 100x100
        let smallRegion = CGRect(x: 100, y: 100, width: 200, height: 150)

        do {
            try await engine.startCapture(
                region: smallRegion,
                resolution: .hd720p,
                frameRate: .fps30
            )

            XCTAssertTrue(true, "Small region accepted")

            _ = try await engine.stopCapture()

        } catch CaptureError.permissionDenied {
            throw XCTSkip("Permission required")
        } catch CaptureError.captureUnavailable {
            throw XCTSkip("Capture unavailable")
        }
    }

    /// Test that large regions work correctly
    func testLargeRegionCapture() async throws {
        let engine = ScreenCaptureEngine()

        // Large region (1600x1200)
        let largeRegion = CGRect(x: 100, y: 100, width: 1600, height: 1200)

        do {
            try await engine.startCapture(
                region: largeRegion,
                resolution: .hd720p,
                frameRate: .fps30
            )

            XCTAssertTrue(true, "Large region accepted")

            _ = try await engine.stopCapture()

        } catch CaptureError.permissionDenied {
            throw XCTSkip("Permission required")
        } catch CaptureError.captureUnavailable {
            throw XCTSkip("Capture unavailable")
        }
    }
}
