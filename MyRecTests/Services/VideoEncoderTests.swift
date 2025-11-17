//
//  VideoEncoderTests.swift
//  MyRecTests
//
//  Created by Week 5 Backend Integration - Day 21
//

import XCTest
@testable import MyRec
#if canImport(MyRecCore)
@testable import MyRecCore
#endif
import AVFoundation
import CoreMedia
import CoreVideo

final class VideoEncoderTests: XCTestCase {
    var encoder: VideoEncoder!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        encoder = VideoEncoder()

        // Create temp directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoEncoderTests_\(UUID().uuidString)")

        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        encoder = nil

        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)

        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testStartEncodingCreatesWriter() throws {
        // Given
        let outputURL = tempDirectory.appendingPathComponent("test.mp4")

        // When
        try encoder.startEncoding(
            outputURL: outputURL,
            resolution: .fullHD,
            frameRate: .fps30
        )

        // Then - should not throw
        XCTAssertTrue(true, "Encoder should start without error")

        // Cleanup
        encoder.cancelEncoding()
    }

    func testStartEncodingWithDifferentResolutions() throws {
        for resolution in [Resolution.hd, .fullHD, .twoK, .fourK] {
            // Given
            let outputURL = tempDirectory.appendingPathComponent("test_\(resolution.rawValue).mp4")

            // When
            try encoder.startEncoding(
                outputURL: outputURL,
                resolution: resolution,
                frameRate: .fps30
            )

            // Then
            XCTAssertTrue(true, "Should start encoding for \(resolution.rawValue)")

            // Cleanup
            encoder.cancelEncoding()
        }
    }

    func testStartEncodingWithDifferentFrameRates() throws {
        for frameRate in FrameRate.allCases {
            // Given
            let outputURL = tempDirectory.appendingPathComponent("test_\(frameRate.value)fps.mp4")

            // When
            try encoder.startEncoding(
                outputURL: outputURL,
                resolution: .fullHD,
                frameRate: frameRate
            )

            // Then
            XCTAssertTrue(true, "Should start encoding at \(frameRate.value) fps")

            // Cleanup
            encoder.cancelEncoding()
        }
    }

    func testStartEncodingTwiceThrowsError() throws {
        // Given
        let outputURL = tempDirectory.appendingPathComponent("test.mp4")
        try encoder.startEncoding(
            outputURL: outputURL,
            resolution: .fullHD,
            frameRate: .fps30
        )

        // When/Then
        XCTAssertThrowsError(
            try encoder.startEncoding(
                outputURL: outputURL,
                resolution: .fullHD,
                frameRate: .fps30
            )
        ) { error in
            XCTAssertTrue(error is VideoEncoder.EncoderError)
        }

        // Cleanup
        encoder.cancelEncoding()
    }

    // MARK: - Frame Appending Tests

    func testAppendFrameWithoutStartThrowsError() throws {
        // Given
        let pixelBuffer = createTestPixelBuffer(width: 1920, height: 1080)
        let time = CMTime(seconds: 0, preferredTimescale: 600)

        // When/Then
        XCTAssertThrowsError(
            try encoder.appendFrame(pixelBuffer, at: time)
        ) { error in
            XCTAssertTrue(error is VideoEncoder.EncoderError)
        }
    }

    func testAppendSingleFrame() throws {
        // Given
        let outputURL = tempDirectory.appendingPathComponent("single_frame.mp4")
        try encoder.startEncoding(
            outputURL: outputURL,
            resolution: .fullHD,
            frameRate: .fps30
        )

        let pixelBuffer = createTestPixelBuffer(width: 1920, height: 1080)
        let time = CMTime(seconds: 0, preferredTimescale: 600)

        // When
        try encoder.appendFrame(pixelBuffer, at: time)

        // Then - should not throw
        XCTAssertTrue(true, "Should append frame without error")

        // Cleanup
        encoder.cancelEncoding()
    }

    // MARK: - Cancel Tests

    func testCancelEncoding() throws {
        // Given
        let outputURL = tempDirectory.appendingPathComponent("cancelled.mp4")
        try encoder.startEncoding(
            outputURL: outputURL,
            resolution: .fullHD,
            frameRate: .fps30
        )

        // When
        encoder.cancelEncoding()

        // Then - should be able to cancel without error
        XCTAssertTrue(true, "Should cancel without error")

        // Verify temp file is cleaned up (will have UUID name)
        let tempFiles = try? FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        )
        let hasTempFiles = tempFiles?.contains { $0.lastPathComponent.starts(with: "temp_") } ?? false
        XCTAssertFalse(hasTempFiles, "Temp files should be cleaned up")
    }

    func testCancelWithoutStartDoesNotCrash() {
        // When/Then - should not crash
        encoder.cancelEncoding()
        XCTAssertTrue(true, "Cancel without start should not crash")
    }

    // MARK: - Error Description Tests

    func testEncoderErrorDescriptions() {
        let errors: [(VideoEncoder.EncoderError, String)] = [
            (.notConfigured, "configured"),
            (.alreadyEncoding, "already"),
            (.notEncoding, "not currently"),
            (.writerCreationFailed(NSError(domain: "test", code: 1)), "create"),
            (.inputConfigurationFailed("test"), "configure"),
            (.startWritingFailed(NSError(domain: "test", code: 1)), "start writing"),
            (.appendFrameFailed(NSError(domain: "test", code: 1)), "append"),
            (.finishWritingFailed(NSError(domain: "test", code: 1)), "finish"),
            (.invalidFrameData, "invalid"),
            (.fileOperationFailed(NSError(domain: "test", code: 1)), "file")
        ]

        for (error, expectedSubstring) in errors {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(
                description.lowercased().contains(expectedSubstring.lowercased()),
                "Error description should contain '\(expectedSubstring)' for \(error)"
            )
        }
    }

    // MARK: - End-to-End Tests (require real encoding)

    /*
    // MANUAL TEST: End-to-end encoding with synthetic frames
    func testCompleteEncodingFlow() async throws {
        // Given
        let outputURL = tempDirectory.appendingPathComponent("complete.mp4")
        let resolution = Resolution.hd
        let frameRate = FrameRate.fps30

        try encoder.startEncoding(
            outputURL: outputURL,
            resolution: resolution,
            frameRate: frameRate
        )

        // Generate 90 frames (3 seconds @ 30fps)
        let frameCount = 90
        for i in 0..<frameCount {
            let pixelBuffer = createColoredPixelBuffer(
                width: resolution.width,
                height: resolution.height,
                hue: Float(i) / Float(frameCount)
            )

            let time = CMTime(
                value: CMTimeValue(i),
                timescale: CMTimeScale(frameRate.value)
            )

            try encoder.appendFrame(pixelBuffer, at: time)
        }

        // When
        let finalURL = try await encoder.finishEncoding()

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))

        // Verify video metadata
        let asset = AVAsset(url: finalURL)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)

        XCTAssertEqual(tracks.count, 1, "Should have 1 video track")
        XCTAssertGreaterThan(duration.seconds, 2.5, "Duration should be ~3 seconds")
        XCTAssertLessThan(duration.seconds, 3.5, "Duration should be ~3 seconds")

        // Verify resolution
        if let videoTrack = tracks.first {
            let size = try await videoTrack.load(.naturalSize)
            XCTAssertEqual(Int(size.width), resolution.width)
            XCTAssertEqual(Int(size.height), resolution.height)
        }
    }
    */

    // MARK: - Helper Methods

    private func createTestPixelBuffer(width: Int, height: Int) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            fatalError("Failed to create pixel buffer")
        }

        // Fill with gray
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let baseAddress = CVPixelBufferGetBaseAddress(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        for y in 0..<height {
            let rowData = baseAddress! + y * bytesPerRow
            memset(rowData, 128, width * 4) // Gray color
        }

        return buffer
    }

    private func createColoredPixelBuffer(width: Int, height: Int, hue: Float) -> CVPixelBuffer {
        let buffer = createTestPixelBuffer(width: width, height: height)

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let baseAddress = CVPixelBufferGetBaseAddress(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        // Create rainbow gradient based on hue
        for y in 0..<height {
            let rowData = baseAddress! + y * bytesPerRow
            let pixels = rowData.assumingMemoryBound(to: UInt8.self)

            for x in 0..<width {
                let offset = x * 4
                // Simple color based on hue
                pixels[offset] = UInt8(hue * 255)     // B
                pixels[offset + 1] = 128              // G
                pixels[offset + 2] = UInt8((1 - hue) * 255)  // R
                pixels[offset + 3] = 255              // A
            }
        }

        return buffer
    }
}
