//
//  EndToEndEncodingTest.swift
//  MyRec - Manual Test
//
//  End-to-end test combining ScreenCaptureEngine + VideoEncoder
//  Run this to verify the complete capture → encode → save pipeline
//
//  Usage: Build and run this in Xcode or via command line
//

import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreMedia

#if canImport(MyRecCore)
@testable import MyRecCore
#else
@testable import MyRec
#endif

@available(macOS 13.0, *)
@main
struct EndToEndEncodingTest {
    static func main() async throws {
        print("🎬 End-to-End Encoding Test")
        print("=========================================")
        print("Testing: ScreenCaptureEngine → VideoEncoder → MP4")
        print("")

        // Configuration
        let resolution = Resolution.hd  // 720p for faster test
        let frameRate = FrameRate.fps30
        let duration: TimeInterval = 5.0  // 5 seconds
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_recording_\(Date().timeIntervalSince1970).mp4")

        print("⚙️  Configuration:")
        print("   Resolution: \(resolution.rawValue)")
        print("   Frame Rate: \(frameRate.value) fps")
        print("   Duration: \(duration) seconds")
        print("   Output: \(outputURL.lastPathComponent)")
        print("")

        // Create engines
        let captureEngine = ScreenCaptureEngine()
        let videoEncoder = VideoEncoder()

        // Configure capture
        print("📹 Configuring screen capture...")
        try captureEngine.configure(
            region: nil,
            resolution: resolution,
            frameRate: frameRate,
            showCursor: true
        )
        print("✅ Capture configured")

        // Start encoding
        print("🎥 Starting video encoder...")
        try videoEncoder.startEncoding(
            outputURL: outputURL,
            resolution: resolution,
            frameRate: frameRate
        )
        print("✅ Encoder started")
        print("")

        // Connect capture to encoder
        var frameCount = 0
        var startTime: Date?

        captureEngine.videoFrameHandler = { pixelBuffer, presentationTime in
            if startTime == nil {
                startTime = Date()
            }

            do {
                try videoEncoder.appendFrame(pixelBuffer, at: presentationTime)
                frameCount += 1

                if frameCount % 30 == 0 {
                    print("📊 Encoded \(frameCount) frames (\(presentationTime.seconds)s)")
                }
            } catch {
                print("❌ Failed to append frame: \(error)")
            }
        }

        // Start capture
        print("🚀 Starting screen capture...")
        do {
            try await captureEngine.startCapture()
            print("✅ Capture started")
        } catch {
            print("❌ Failed to start capture: \(error)")
            print("")
            print("⚠️  Make sure screen recording permission is granted:")
            print("   System Settings > Privacy & Security > Screen Recording")
            return
        }
        print("")

        // Capture for specified duration
        print("⏱️  Recording for \(duration) seconds...")
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        // Stop capture
        print("🛑 Stopping capture...")
        try await captureEngine.stopCapture()
        print("✅ Capture stopped")
        print("")

        // Finish encoding
        print("🎬 Finishing encoding...")
        let finalURL = try await videoEncoder.finishEncoding()
        print("✅ Encoding completed")
        print("")

        // Verify output
        print("📊 Verification")
        print("=========================================")

        guard FileManager.default.fileExists(atPath: finalURL.path) else {
            print("❌ Output file does not exist!")
            return
        }

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: finalURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        print("✅ File exists: \(finalURL.path)")
        print("   File size: \(String(format: "%.2f", Double(fileSize) / 1024 / 1024)) MB")

        // Verify with AVAsset
        let asset = AVAsset(url: finalURL)
        let isPlayable = try await asset.load(.isPlayable)
        let assetDuration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)

        print("   Playable: \(isPlayable ? "✅" : "❌")")
        print("   Duration: \(String(format: "%.2f", assetDuration.seconds)) seconds")
        print("   Tracks: \(tracks.count)")

        // Verify video track
        if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
            let naturalSize = try await videoTrack.load(.naturalSize)
            let estimatedDataRate = try await videoTrack.load(.estimatedDataRate)

            print("")
            print("📹 Video Track:")
            print("   Resolution: \(Int(naturalSize.width))x\(Int(naturalSize.height))")
            print("   Data Rate: \(String(format: "%.2f", estimatedDataRate / 1_000_000)) Mbps")
        }

        // Statistics
        print("")
        print("📈 Statistics")
        print("=========================================")
        print("Total frames captured: \(frameCount)")

        if let start = startTime {
            let elapsed = Date().timeIntervalSince(start)
            let averageFps = Double(frameCount) / elapsed
            print("Capture duration: \(String(format: "%.2f", elapsed)) seconds")
            print("Average FPS: \(String(format: "%.1f", averageFps))")

            let expectedFrames = frameRate.value * Int(duration)
            let tolerance = 10
            print("Expected frames: ~\(expectedFrames) ± \(tolerance)")

            if abs(frameCount - expectedFrames) <= tolerance {
                print("✅ Frame count is within acceptable range")
            } else {
                print("⚠️  Frame count variance is higher than expected")
            }
        }

        print("")
        print("🎉 Test completed successfully!")
        print("")
        print("💡 You can play the video with:")
        print("   open \(finalURL.path)")
        print("")
        print("   Or in QuickTime Player:")
        print("   open -a 'QuickTime Player' '\(finalURL.path)'")
    }
}
