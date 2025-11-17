//
//  ScreenCaptureTest.swift
//  MyRec - Manual Test
//
//  Manual test for ScreenCaptureEngine
//  Run this to verify frame capture works correctly
//
//  Usage: Build and run this in Xcode or via command line
//

import Foundation
import ScreenCaptureKit
import CoreMedia

#if canImport(MyRecCore)
@testable import MyRecCore
#else
@testable import MyRec
#endif

@available(macOS 13.0, *)
@main
struct ScreenCaptureTest {
    static func main() async throws {
        print("🎥 ScreenCaptureEngine Manual Test")
        print("=====================================")
        print("")

        // Create engine
        let engine = ScreenCaptureEngine()

        // Configure for 1080p @ 30fps
        print("⚙️  Configuring capture: 1080p @ 30fps")
        try engine.configure(
            region: nil,  // Full screen
            resolution: .fullHD,
            frameRate: .fps30,
            showCursor: true
        )
        print("✅ Configuration successful")
        print("")

        // Set up frame handler
        var frameCount = 0
        var startTime: Date?
        var lastFrameTime: CMTime?

        engine.videoFrameHandler = { pixelBuffer, presentationTime in
            if startTime == nil {
                startTime = Date()
                print("🎬 First frame received!")
            }

            frameCount += 1
            lastFrameTime = presentationTime

            // Log every 30 frames (1 second @ 30fps)
            if frameCount % 30 == 0 {
                let elapsed = Date().timeIntervalSince(startTime!)
                let fps = Double(frameCount) / elapsed

                print("📊 Frame \(frameCount): \(String(format: "%.1f", fps)) fps (time: \(String(format: "%.2f", presentationTime.seconds))s)")
            }
        }

        // Start capture
        print("🚀 Starting capture...")
        do {
            try await engine.startCapture()
            print("✅ Capture started successfully")
        } catch {
            print("❌ Failed to start capture: \(error)")
            print("")
            print("⚠️  Make sure screen recording permission is granted:")
            print("   System Settings > Privacy & Security > Screen Recording")
            return
        }
        print("")

        // Capture for 5 seconds
        print("⏱️  Capturing for 5 seconds...")
        try await Task.sleep(nanoseconds: 5_000_000_000)

        // Stop capture
        print("🛑 Stopping capture...")
        try await engine.stopCapture()
        print("✅ Capture stopped")
        print("")

        // Print statistics
        print("📈 Statistics")
        print("=====================================")
        print("Total frames captured: \(frameCount)")

        if let start = startTime {
            let elapsed = Date().timeIntervalSince(start)
            let averageFps = Double(frameCount) / elapsed
            print("Elapsed time: \(String(format: "%.2f", elapsed)) seconds")
            print("Average FPS: \(String(format: "%.1f", averageFps))")

            // Verify frame rate is close to 30fps
            let expectedFrames = 30 * 5  // 30fps * 5 seconds = 150 frames
            let tolerance = 10

            print("")
            print("Expected frames: ~\(expectedFrames) ± \(tolerance)")

            if abs(frameCount - expectedFrames) <= tolerance {
                print("✅ Frame rate is within acceptable range")
            } else {
                print("⚠️  Frame rate variance is higher than expected")
            }
        }

        print("")
        print("🎉 Test completed successfully!")
    }
}
