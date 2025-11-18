import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import OSLog

/// Handles screen capture using ScreenCaptureKit (macOS 13+)
/// Captures screen content and delivers CVPixelBuffer frames with timing information
@available(macOS 13.0, *)
class ScreenCaptureEngine: NSObject {

    // MARK: - Types

    enum CaptureError: LocalizedError {
        case permissionDenied
        case noDisplaysAvailable
        case invalidRegion
        case captureNotStarted
        case captureAlreadyRunning
        case configurationFailed(Error)
        case streamCreationFailed(Error)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Screen recording permission denied. Please enable in System Settings > Privacy & Security > Screen Recording."
            case .noDisplaysAvailable:
                return "No displays available for capture."
            case .invalidRegion:
                return "Invalid capture region specified."
            case .captureNotStarted:
                return "Capture has not been started."
            case .captureAlreadyRunning:
                return "Capture is already running."
            case .configurationFailed(let error):
                return "Failed to configure capture: \(error.localizedDescription)"
            case .streamCreationFailed(let error):
                return "Failed to create capture stream: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    private var stream: SCStream?
    private var streamConfiguration: SCStreamConfiguration?
    private var captureRegion: CGRect?
    private var isCapturing = false
    private let logger = Logger(subsystem: "com.myrec.app", category: "ScreenCapture")

    /// Handler called for each captured video frame
    /// Parameters:
    /// - pixelBuffer: The captured frame as CVPixelBuffer
    /// - presentationTime: CMTime indicating when the frame was captured
    var videoFrameHandler: ((CVPixelBuffer, CMTime) -> Void)?

    // MARK: - Permission Check

    /// Check if screen recording permission is granted
    /// - Returns: True if permission is granted, false otherwise
    static func checkPermission() async -> Bool {
        print("🔒 [PERMISSION] Starting permission check...")

        // Use a simpler approach: just try to get shareable content and check for error -3801
        // Creating a stream causes thread safety issues
        do {
            print("🔒 [PERMISSION] Attempting to get shareable content...")
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            guard !content.displays.isEmpty else {
                print("❌ [PERMISSION] No displays available")
                return false
            }

            print("✅ [PERMISSION] Successfully got shareable content with \(content.displays.count) displays")
            print("✅ [PERMISSION] Screen Recording permission appears to be granted")

            // Note: This only checks window picking permission, not full screen recording
            // The actual recording attempt will trigger the screen recording permission if needed
            return true

        } catch {
            let nsError = error as NSError
            print("❌ [PERMISSION] Failed to get shareable content:")
            print("❌ [PERMISSION]   Description: \(error.localizedDescription)")
            print("❌ [PERMISSION]   Domain: \(nsError.domain)")
            print("❌ [PERMISSION]   Code: \(nsError.code)")

            // Error -3801 means TCC permission denied
            if nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && nsError.code == -3801 {
                print("❌ [PERMISSION] TCC permission denial detected")
                return false
            }

            print("❌ [PERMISSION] Unknown error, assuming no permission")
            return false
        }
    }

    /// Request screen recording permission (shows system dialog)
    /// - Returns: True if permission is granted after request, false otherwise
    @discardableResult
    static func requestPermission() async -> Bool {
        // On macOS, requesting permission is done by attempting to use ScreenCaptureKit
        // The system will automatically show permission dialog on first use
        return await checkPermission()
    }

    // MARK: - Configuration

    /// Configure capture settings
    /// - Parameters:
    ///   - region: CGRect in screen coordinates to capture (nil for full display)
    ///   - resolution: Target resolution for capture
    ///   - frameRate: Target frame rate for capture
    ///   - showCursor: Whether to show cursor in capture
    func configure(
        region: CGRect?,
        resolution: Resolution,
        frameRate: FrameRate,
        showCursor: Bool = true
    ) throws {
        guard !isCapturing else {
            throw CaptureError.captureAlreadyRunning
        }

        // Create stream configuration
        let config = SCStreamConfiguration()

        // Set resolution
        config.width = resolution.width
        config.height = resolution.height

        // Set frame rate (minimumFrameInterval is inverse of frame rate)
        config.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(frameRate.value)
        )

        // Set pixel format (32-bit BGRA is standard for ScreenCaptureKit)
        config.pixelFormat = kCVPixelFormatType_32BGRA

        // Cursor visibility
        config.showsCursor = showCursor

        // Queue depth for buffering (5 frames is a good balance)
        config.queueDepth = 5

        // Store configuration
        self.streamConfiguration = config
        self.captureRegion = region

        logger.info("Configured capture: \(resolution.rawValue) @ \(frameRate.value)fps, cursor: \(showCursor)")
    }

    // MARK: - Capture Control

    /// Start capturing screen content
    /// - Throws: CaptureError if capture cannot be started
    func startCapture() async throws {
        guard !isCapturing else {
            throw CaptureError.captureAlreadyRunning
        }

        guard let config = streamConfiguration else {
            throw CaptureError.configurationFailed(
                NSError(domain: "ScreenCaptureEngine", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Must call configure() before starting capture"])
            )
        }

        // Get available content
        let availableContent: SCShareableContent
        do {
            availableContent = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            logger.error("Failed to get shareable content: \(error.localizedDescription)")
            throw CaptureError.configurationFailed(error)
        }

        // Get the display to capture
        guard let display = availableContent.displays.first else {
            throw CaptureError.noDisplaysAvailable
        }

        // Create content filter
        // For now, capture entire display (window/region filtering comes later)
        let filter: SCContentFilter
        if let region = captureRegion {
            // Validate region
            let displayRect = CGRect(
                x: 0,
                y: 0,
                width: display.width,
                height: display.height
            )

            guard displayRect.contains(region) else {
                throw CaptureError.invalidRegion
            }

            // Create filter for specific region
            filter = SCContentFilter(
                display: display,
                excludingWindows: []
            )

            // Note: Region-specific capture requires additional configuration
            // For now, we capture full display and crop in post-processing if needed
            logger.info("Capturing region: \(String(describing: region))")
        } else {
            // Capture entire display
            filter = SCContentFilter(
                display: display,
                excludingWindows: []
            )
            logger.info("Capturing full display")
        }

        // Create stream
        let newStream = SCStream(
            filter: filter,
            configuration: config,
            delegate: self
        )

        // Add stream output
        do {
            try newStream.addStreamOutput(
                self,
                type: .screen,
                sampleHandlerQueue: DispatchQueue(
                    label: "com.myrec.screencapture.output",
                    qos: .userInitiated
                )
            )
        } catch {
            logger.error("Failed to add stream output: \(error.localizedDescription)")
            throw CaptureError.streamCreationFailed(error)
        }

        // Start capture
        do {
            try await newStream.startCapture()
        } catch {
            logger.error("Failed to start capture: \(error.localizedDescription)")
            throw CaptureError.streamCreationFailed(error)
        }

        self.stream = newStream
        self.isCapturing = true

        logger.info("Screen capture started successfully")
    }

    /// Stop capturing screen content
    /// - Throws: CaptureError if capture cannot be stopped
    func stopCapture() async throws {
        guard isCapturing else {
            throw CaptureError.captureNotStarted
        }

        guard let stream = stream else {
            throw CaptureError.captureNotStarted
        }

        // Stop capture
        do {
            try await stream.stopCapture()
        } catch {
            logger.error("Failed to stop capture: \(error.localizedDescription)")
            throw error
        }

        self.stream = nil
        self.isCapturing = false

        logger.info("Screen capture stopped")
    }

    /// Pause capture (suspends frame delivery)
    /// Note: Pause/resume will be implemented in Week 7
    func pauseCapture() async throws {
        guard isCapturing else {
            throw CaptureError.captureNotStarted
        }

        // TODO: Implement pause functionality
        // For now, this is a placeholder
        logger.warning("Pause capture not yet implemented")
    }

    /// Resume capture after pause
    /// Note: Pause/resume will be implemented in Week 7
    func resumeCapture() async throws {
        guard !isCapturing else {
            throw CaptureError.captureAlreadyRunning
        }

        // TODO: Implement resume functionality
        // For now, this is a placeholder
        logger.warning("Resume capture not yet implemented")
    }
}

// MARK: - SCStreamDelegate

@available(macOS 13.0, *)
extension ScreenCaptureEngine: SCStreamDelegate {

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Stream stopped with error: \(error.localizedDescription)")
        isCapturing = false
        self.stream = nil
    }
}

// MARK: - SCStreamOutput

@available(macOS 13.0, *)
extension ScreenCaptureEngine: SCStreamOutput {

    private static var frameCount = 0

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        // Only process screen output
        guard type == .screen else { return }

        // Check if we're still capturing
        guard isCapturing else {
            logger.warning("⚠️ [CAPTURE] Received frame but not capturing - ignoring")
            return
        }

        // Get pixel buffer from sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            logger.warning("❌ [CAPTURE] Failed to get pixel buffer from sample")
            return
        }

        // Get presentation timestamp
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Log first frame
        Self.frameCount += 1
        if Self.frameCount == 1 {
            logger.info("📥 [CAPTURE] Received first frame from ScreenCaptureKit at \(presentationTime.seconds)s")
        }

        // Deliver frame to handler (already on a background queue)
        // The handler should be thread-safe
        guard let handler = videoFrameHandler else {
            if Self.frameCount == 1 {
                logger.warning("⚠️ [CAPTURE] No frame handler set!")
            }
            return
        }

        // Call handler with error protection
        autoreleasepool {
            handler(pixelBuffer, presentationTime)
        }
    }
}

