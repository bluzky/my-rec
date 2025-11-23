@preconcurrency import ScreenCaptureKit
import AVFoundation
import CoreMedia
import Combine

/// Handles screen capture using ScreenCaptureKit with SCRecordingOutput (macOS 15+)
@available(macOS 15.0, *)
public class ScreenCaptureEngine: NSObject, SCStreamDelegate, SCRecordingOutputDelegate, ObservableObject {
    // MARK: - Properties
    private var stream: SCStream?
    private var captureRegion: CGRect = .zero
    private var frameCount: Int = 0
    private var isCapturing = false
    private var startTime: CMTime?

    // SCRecordingOutput integration (macOS 15+)
    private var recordingOutput: SCRecordingOutput?
    private var outputURL: URL?

    // Audio settings
    private var captureAudio: Bool = false
    private var captureMicrophone: Bool = false

    // Audio level monitoring (preserved for UI feedback)
    @Published var audioLevel: Float = 0.0
    @Published var microphoneLevel: Float = 0.0

    // MARK: - Callbacks
    var onFrameCaptured: ((Int, CMTime) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Public Interface

    /// Start capturing the screen
    /// - Parameters:
    ///   - region: The screen region to capture
    ///   - resolution: The output resolution
    ///   - frameRate: The capture frame rate
    ///   - withAudio: Whether to capture system audio (default: true)
    ///   - withMicrophone: Whether to capture microphone (default: false)
    public func startCapture(region: CGRect, resolution: Resolution, frameRate: FrameRate, withAudio: Bool = true, withMicrophone: Bool = false) async throws {
        guard !isCapturing else { return }

        self.captureRegion = region
        self.frameCount = 0
        self.startTime = nil
        self.captureAudio = withAudio
        self.captureMicrophone = withMicrophone

        // Create output file URL
        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).mp4")

        print("🎵 System audio enabled: \(captureAudio)")
        print("🎤 Microphone enabled: \(captureMicrophone)")

        // Setup stream (permission already checked in AppDelegate)
        let streamSetup = try await setupStream(resolution: resolution, frameRate: frameRate)
        stream = streamSetup.stream

        guard let outputURL = outputURL else {
            throw CaptureError.configurationFailed
        }

        print("🎯 Output dimensions: \(streamSetup.outputSize.width)x\(streamSetup.outputSize.height)")

        // Configure SCRecordingOutput (macOS 15+)
        let recordingConfig = SCRecordingOutputConfiguration()
        recordingConfig.outputURL = outputURL
        recordingConfig.videoCodecType = .h264
        // Note: Audio codec is automatically AAC - no need to set explicitly

        // Create recording output with delegate
        recordingOutput = SCRecordingOutput(configuration: recordingConfig, delegate: self)

        guard let recordingOutput = recordingOutput else {
            throw CaptureError.configurationFailed
        }

        // Add recording output to stream
        try stream?.addRecordingOutput(recordingOutput)
        print("✅ Recording output configured - File: \(outputURL.lastPathComponent)")

        // Start capture
        try await stream?.startCapture()

        isCapturing = true
        print("✅ ScreenCaptureEngine: Capture started")
    }

    /// Stop capturing the screen
    public func stopCapture() async throws -> URL {
        guard isCapturing else {
            print("⚠️ ScreenCaptureEngine: Not currently capturing")
            throw CaptureError.notCapturing
        }

        print("🔄 ScreenCaptureEngine: Stopping capture...")
        isCapturing = false

        guard let outputURL = outputURL, let recordingOutput = recordingOutput else {
            throw CaptureError.configurationFailed
        }

        // Remove recording output from stream to finalize the file
        do {
            try stream?.removeRecordingOutput(recordingOutput)
            print("✅ ScreenCaptureEngine: Recording output removed - file finalizing")
        } catch {
            print("❌ ScreenCaptureEngine: Error removing recording output: \(error)")
            throw error
        }

        // Wait a moment for the file to be fully written
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Stop stream
        do {
            try await stream?.stopCapture()
            print("✅ ScreenCaptureEngine: Stream stopped")
        } catch {
            print("❌ ScreenCaptureEngine: Error stopping stream: \(error)")
            // Continue cleanup even if stream stop fails
        }

        // Cleanup
        let finalFrameCount = frameCount
        let result = outputURL

        stream = nil
        self.recordingOutput = nil
        self.outputURL = nil
        frameCount = 0
        startTime = nil

        print("✅ ScreenCaptureEngine: Capture stopped - \(finalFrameCount) frames - File: \(result.path)")
        return result
    }

    // MARK: - SCStreamDelegate

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("❌ ScreenCaptureEngine: Stream stopped with error: \(error)")
        onError?(error)
    }

    // MARK: - SCRecordingOutputDelegate

    public func recordingOutput(_ output: SCRecordingOutput, didFailWithError error: Error) {
        print("❌ ScreenCaptureEngine: Recording failed: \(error)")
        onError?(error)
    }

    public func recordingOutputDidFinishRecording(_ output: SCRecordingOutput) {
        print("✅ ScreenCaptureEngine: Recording finished successfully")
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

    private func makeEven(_ value: Int) -> Int {
        return value % 2 == 0 ? value : value - 1
    }

    private func setupStream(resolution: Resolution, frameRate: FrameRate) async throws -> (stream: SCStream, outputSize: (width: Int, height: Int)) {
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
            config.width = makeEven(Int(validatedRegion.width))
            config.height = makeEven(Int(validatedRegion.height))

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

        // Configure audio capture
        if captureAudio {
            config.capturesAudio = true
            config.sampleRate = 48000
            config.channelCount = 2
            config.excludesCurrentProcessAudio = true  // Prevent feedback from our own app
            print("🎵 Audio capture enabled: 48kHz stereo (excluding own process)")
        }

        // Configure microphone capture
        if captureMicrophone {
            config.captureMicrophone = true
            print("🎤 Microphone capture enabled via ScreenCaptureKit")
        }

        // Create stream (SCRecordingOutput will handle sample buffers)
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)

        // NOTE: No need to add stream outputs - SCRecordingOutput handles encoding automatically
        print("✅ Stream configured - SCRecordingOutput will handle video/audio encoding")

        return (newStream, (config.width, config.height))
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
