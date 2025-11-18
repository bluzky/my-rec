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

        // Setup stream (permission already checked in AppDelegate)
        try await setupStream(resolution: resolution, frameRate: frameRate)

        isCapturing = true
        print("✅ ScreenCaptureEngine: Capture started")
    }

    /// Stop capturing the screen
    func stopCapture() async throws {
        guard isCapturing else { return }

        try await stream?.stopCapture()
        stream = nil
        isCapturing = false

        print("✅ ScreenCaptureEngine: Capture stopped - \(frameCount) frames")
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        frameCount += 1

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
        config.width = resolution.width
        config.height = resolution.height
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

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission denied. Please enable in System Settings > Privacy & Security > Screen Recording"
        case .captureUnavailable:
            return "Screen capture is unavailable. Please ensure macOS 13 or later."
        case .configurationFailed:
            return "Failed to configure screen capture."
        }
    }
}
