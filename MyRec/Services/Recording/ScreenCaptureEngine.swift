import ScreenCaptureKit
import AVFoundation
import CoreMedia
import Combine

/// Handles screen capture using ScreenCaptureKit (macOS 13+)
@available(macOS 12.3, *)
public class ScreenCaptureEngine: NSObject, SCStreamDelegate, SCStreamOutput, ObservableObject {
    // MARK: - Properties
    private var stream: SCStream?
    private var captureRegion: CGRect = .zero
    private var frameCount: Int = 0
    private var isCapturing = false
    private var startTime: CMTime?

    // ADD: VideoEncoder integration
    private var videoEncoder: VideoEncoder?
    private var tempURL: URL?

    // Audio settings
    private var captureAudio: Bool = false
    private var captureMicrophone: Bool = false

    // Audio level monitoring
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

        try videoEncoder?.startEncoding(withAudio: captureAudio || captureMicrophone)
        print("✅ Encoder started - Output: \(tempURL.lastPathComponent)")
        print("🎵 System audio enabled: \(captureAudio)")
        print("🎤 Microphone enabled: \(captureMicrophone)")

        // Setup stream (permission already checked in AppDelegate)
        try await setupStream(resolution: resolution, frameRate: frameRate)

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

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if #available(macOS 15.0, *) {
            switch type {
            case .screen:
                handleVideoSampleBuffer(sampleBuffer)

            case .audio:
                handleAudioSampleBuffer(sampleBuffer)

            case .microphone:
                handleMicrophoneSampleBuffer(sampleBuffer)

            @unknown default:
                break
            }
        } else if #available(macOS 13.0, *) {
            switch type {
            case .screen:
                handleVideoSampleBuffer(sampleBuffer)

            case .audio:
                handleAudioSampleBuffer(sampleBuffer)

            case .microphone:
                // Microphone not available on macOS 13-14
                break

            @unknown default:
                break
            }
        } else {
            // macOS 12.3 only supports screen output
            if type == .screen {
                handleVideoSampleBuffer(sampleBuffer)
            }
        }
    }

    private func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
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

    private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Send audio to video encoder
        videoEncoder?.appendAudio(sampleBuffer)

        // Update audio level for UI
        updateAudioLevel(from: sampleBuffer)
    }

    private func handleMicrophoneSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Send microphone audio to video encoder for recording
        videoEncoder?.appendAudio(sampleBuffer)

        // Update microphone level for UI
        updateMicrophoneLevel(from: sampleBuffer)
    }

    // MARK: - Audio Level Calculation

    private func updateAudioLevel(from sampleBuffer: CMSampleBuffer) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &length,
            totalLengthOut: nil,
            dataPointerOut: &dataPointer
        )

        guard status == kCMBlockBufferNoErr,
              let data = dataPointer,
              length > 0 else {
            return
        }

        // Calculate RMS assuming Float32 PCM format from ScreenCaptureKit
        let samples = UnsafeRawPointer(data).assumingMemoryBound(to: Float.self)
        let count = length / MemoryLayout<Float>.size

        guard count > 0 else { return }

        var sum: Float = 0
        for i in 0..<count {
            let sample = samples[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(count))

        // Update on main thread for UI binding
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = min(rms, 1.0)
        }
    }

    private func updateMicrophoneLevel(from sampleBuffer: CMSampleBuffer) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &length,
            totalLengthOut: nil,
            dataPointerOut: &dataPointer
        )

        guard status == kCMBlockBufferNoErr,
              let data = dataPointer,
              length > 0 else {
            return
        }

        // Calculate RMS assuming Float32 PCM format from ScreenCaptureKit
        let samples = UnsafeRawPointer(data).assumingMemoryBound(to: Float.self)
        let count = length / MemoryLayout<Float>.size

        guard count > 0 else { return }

        var sum: Float = 0
        for i in 0..<count {
            let sample = samples[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(count))

        // Update on main thread for UI binding
        DispatchQueue.main.async { [weak self] in
            // Scale RMS to 0-1 range
            let scaledLevel = min(rms * 10.0, 1.0)
            self?.microphoneLevel = scaledLevel
        }
    }

    // MARK: - SCStreamDelegate

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
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

        // Configure audio capture (macOS 13+)
        if captureAudio {
            if #available(macOS 13.0, *) {
                config.capturesAudio = true
                config.sampleRate = 48000
                config.channelCount = 2
                print("🎵 Audio capture enabled: 48kHz stereo")
            } else {
                print("⚠️ Audio capture requires macOS 13.0 or later")
            }
        }

        // Configure microphone capture (macOS 15+)
        if captureMicrophone {
            if #available(macOS 15.0, *) {
                config.captureMicrophone = true
                print("🎤 Microphone capture enabled via ScreenCaptureKit")
            } else {
                print("⚠️ Microphone capture via ScreenCaptureKit requires macOS 15.0 or later")
            }
        }

        // Create stream
        stream = SCStream(filter: filter, configuration: config, delegate: self)

        // Add stream output for video
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())

        // Add stream output for audio if enabled (macOS 13+)
        if captureAudio {
            if #available(macOS 13.0, *) {
                try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
            }
        }

        // Add stream output for microphone if enabled (macOS 15+)
        if captureMicrophone {
            if #available(macOS 15.0, *) {
                try stream?.addStreamOutput(self, type: .microphone, sampleHandlerQueue: .global())
                print("🎤 Microphone stream output registered")
            }
        }

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
