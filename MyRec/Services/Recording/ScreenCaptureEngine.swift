import ScreenCaptureKit
import AVFoundation
import CoreMedia

/// Handles screen capture using ScreenCaptureKit (macOS 13+)
class ScreenCaptureEngine: NSObject, SCStreamDelegate, SCStreamOutput {
    // MARK: - Properties
    private var stream: SCStream?
    private var captureRegion: CGRect = .zero
    private var frameCount: Int = 0
    private var isCapturing = false
    private var startTime: CMTime?

    // ADD: VideoEncoder integration
    private var videoEncoder: VideoEncoder?
    private var tempURL: URL?

    // MARK: - Callbacks
    var onFrameCaptured: ((Int, CMTime) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Public Interface

    /// Start capturing the screen
    /// - Parameters:
    ///   - region: The screen region to capture
    ///   - resolution: The output resolution
    ///   - frameRate: The capture frame rate
    func startCapture(region: CGRect, resolution: Resolution, frameRate: FrameRate) async throws {
        guard !isCapturing else { return }

        self.captureRegion = region
        self.frameCount = 0
        self.startTime = nil

        // ADD: Create temp file URL
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).mp4")

        // ADD: Create and start encoder
        guard let tempURL = tempURL else {
            throw CaptureError.configurationFailed
        }

        videoEncoder = VideoEncoder(
            outputURL: tempURL,
            resolution: resolution,
            frameRate: frameRate
        )

        videoEncoder?.onFrameEncoded = { frame in
            print("💾 Frame \(frame) encoded to MP4")
        }

        videoEncoder?.onError = { error in
            print("❌ Encoding error: \(error)")
        }

        try videoEncoder?.startEncoding()
        print("✅ Encoder started - Output: \(tempURL.lastPathComponent)")

        // Setup stream (permission already checked in AppDelegate)
        try await setupStream(resolution: resolution, frameRate: frameRate)

        isCapturing = true
        print("✅ ScreenCaptureEngine: Capture started")
    }

    /// Stop capturing the screen
    func stopCapture() async throws -> URL {
        guard isCapturing else {
            print("⚠️ ScreenCaptureEngine: Not currently capturing")
            throw CaptureError.notCapturing
        }

        print("🔄 ScreenCaptureEngine: Stopping capture...")
        isCapturing = false

        // Stop stream first with error handling
        do {
            try await stream?.stopCapture()
            stream = nil
            print("✅ ScreenCaptureEngine: Stream stopped")
        } catch {
            print("❌ ScreenCaptureEngine: Error stopping stream: \(error)")
            // Continue with encoder cleanup even if stream fails
        }

        // Finish encoding
        guard let encoder = videoEncoder else {
            print("❌ ScreenCaptureEngine: No encoder initialized")
            throw CaptureError.encoderNotInitialized
        }

        do {
            let outputURL = try await encoder.finishEncoding()
            print("✅ ScreenCaptureEngine: Encoding finished - File: \(outputURL.path)")

            // Reset
            videoEncoder = nil
            let result = outputURL
            tempURL = nil
            let finalFrameCount = frameCount
            frameCount = 0
            startTime = nil

            print("✅ ScreenCaptureEngine: Capture stopped - \(finalFrameCount) frames")
            return result
        } catch {
            print("❌ ScreenCaptureEngine: Error during encoding: \(error)")
            // Cleanup on error
            videoEncoder = nil
            tempURL = nil
            frameCount = 0
            startTime = nil
            throw error
        }
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        frameCount += 1

        // Send frame to encoder
        videoEncoder?.appendFrame(sampleBuffer)

        // Log every 30 frames
        if frameCount % 30 == 0 {
            print("📹 Frame \(frameCount) → Encoder")
        }

        // Get presentation time
        let presentationTime = sampleBuffer.presentationTimeStamp

        // Store start time
        if startTime == nil {
            startTime = presentationTime
        }

        // Calculate elapsed time from start
        let elapsed = presentationTime - (startTime ?? .zero)

        // Notify callback
        onFrameCaptured?(frameCount, elapsed)
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("❌ ScreenCaptureEngine: Stream stopped with error: \(error)")
        onError?(error)
    }

    // MARK: - Private Methods

    /// Validates and clamps region to display bounds with minimum size enforcement
    private func validateRegion(_ region: CGRect, for display: SCDisplay) -> CGRect {
        var validated = region

        // Enforce minimum size (100x100 pixels)
        let minSize: CGFloat = 100
        validated.size.width = max(minSize, region.width)
        validated.size.height = max(minSize, region.height)

        // Clamp to display bounds
        let maxX = CGFloat(display.width) - validated.width
        let maxY = CGFloat(display.height) - validated.height

        validated.origin.x = max(0, min(region.origin.x, maxX))
        validated.origin.y = max(0, min(region.origin.y, maxY))

        // Ensure width and height don't exceed display bounds
        validated.size.width = min(validated.width, CGFloat(display.width))
        validated.size.height = min(validated.height, CGFloat(display.height))

        if validated != region {
            print("⚠️ Region adjusted from \(region) to \(validated)")
        }

        return validated
    }

    /// Converts NSWindow/macOS coordinates to ScreenCaptureKit coordinates
    /// macOS NSWindow coordinates: origin at bottom-left of screen
    /// ScreenCaptureKit coordinates: origin at top-left of screen
    private func convertToScreenCaptureCoordinates(_ region: CGRect, displayHeight: Int) -> CGRect {
        // NSWindow coordinates have origin at bottom-left
        // ScreenCaptureKit expects origin at top-left
        // Formula: sck_y = displayHeight - nswindow_y - height

        let sckY = CGFloat(displayHeight) - region.origin.y - region.height

        return CGRect(
            x: region.origin.x,
            y: sckY,
            width: region.width,
            height: region.height
        )
    }

    private func setupStream(resolution: Resolution, frameRate: FrameRate) async throws {
        // Get available content
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first else {
            throw CaptureError.captureUnavailable
        }

        // Create filter for entire display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure stream
        let config = SCStreamConfiguration()

        // Use custom region if provided, otherwise use resolution dimensions
        if captureRegion != .zero {
            // Validate and clamp region to display bounds
            let validatedRegion = validateRegion(captureRegion, for: display)

            // Convert to ScreenCaptureKit coordinate system (origin at top-left)
            let sckRegion = convertToScreenCaptureCoordinates(validatedRegion, displayHeight: display.height)

            // Set the source rect to capture only the selected region
            config.sourceRect = sckRegion

            // Set output dimensions to match the region size
            config.width = Int(validatedRegion.width)
            config.height = Int(validatedRegion.height)

            print("📐 Using custom region: \(validatedRegion)")
            print("📐 SCK coordinates: \(sckRegion)")
            print("📐 Output size: \(config.width)x\(config.height)")
        } else {
            // Full screen capture using resolution settings
            config.width = resolution.width
            config.height = resolution.height
            print("📐 Using full screen with resolution: \(resolution.displayName)")
        }

        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate.value))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.queueDepth = 5

        // Create stream
        stream = SCStream(filter: filter, configuration: config, delegate: self)

        // Add stream output
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())

        // Start capture
        try await stream?.startCapture()
    }
}

// MARK: - Errors

enum CaptureError: LocalizedError {
    case permissionDenied
    case captureUnavailable
    case configurationFailed
    case notCapturing
    case encoderNotInitialized

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission denied. Please enable in System Settings > Privacy & Security > Screen Recording"
        case .captureUnavailable:
            return "Screen capture is unavailable. Please ensure macOS 13 or later."
        case .configurationFailed:
            return "Failed to configure screen capture."
        case .notCapturing:
            return "Not currently capturing."
        case .encoderNotInitialized:
            return "Video encoder was not initialized."
        }
    }
}
