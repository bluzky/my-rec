import Foundation
import Combine
import CoreMedia
import CoreVideo
import OSLog

/// Central coordinator for screen recording
/// Manages the complete recording lifecycle: start → capture → encode → stop
@MainActor
class RecordingManager: ObservableObject {

    // MARK: - Types

    enum RecordingError: LocalizedError {
        case alreadyRecording
        case notRecording
        case captureSetupFailed(Error)
        case encodingSetupFailed(Error)
        case recordingFailed(Error)
        case saveFailed(Error)
        case invalidState(String)

        var errorDescription: String? {
            switch self {
            case .alreadyRecording:
                return "A recording is already in progress."
            case .notRecording:
                return "No recording is currently active."
            case .captureSetupFailed(let error):
                return "Failed to setup screen capture: \(error.localizedDescription)"
            case .encodingSetupFailed(let error):
                return "Failed to setup video encoder: \(error.localizedDescription)"
            case .recordingFailed(let error):
                return "Recording failed: \(error.localizedDescription)"
            case .saveFailed(let error):
                return "Failed to save recording: \(error.localizedDescription)"
            case .invalidState(let message):
                return "Invalid recording state: \(message)"
            }
        }
    }

    // MARK: - Published Properties

    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var duration: TimeInterval = 0

    // MARK: - Dependencies

    private let captureEngine: ScreenCaptureEngine
    private let videoEncoder: VideoEncoder
    private let settingsManager: SettingsManager

    // MARK: - State

    private var recordingStartTime: Date?
    private var currentOutputURL: URL?
    private var timer: Timer?
    private var frameCount = 0

    private let logger = Logger(subsystem: "com.myrec.app", category: "RecordingManager")

    // MARK: - Initialization

    init(
        captureEngine: ScreenCaptureEngine = ScreenCaptureEngine(),
        videoEncoder: VideoEncoder = VideoEncoder(),
        settingsManager: SettingsManager = SettingsManager.shared
    ) {
        self.captureEngine = captureEngine
        self.videoEncoder = videoEncoder
        self.settingsManager = settingsManager
    }

    // MARK: - Public Interface

    /// Start recording with specified region
    /// - Parameter region: The screen region to capture (nil for full screen)
    /// - Throws: RecordingError if recording cannot start
    func startRecording(region: CGRect?) async throws {
        guard state.isIdle else {
            logger.warning("Attempted to start recording while state is \(String(describing: self.state))")
            throw RecordingError.alreadyRecording
        }

        logger.info("Starting recording for region: \(String(describing: region))")

        // Generate output URL
        let outputURL = generateOutputURL()
        currentOutputURL = outputURL

        // Get settings
        let settings = settingsManager.defaultSettings

        do {
            // Setup capture engine
            try captureEngine.configure(
                region: region,
                resolution: settings.resolution,
                frameRate: settings.frameRate,
                showCursor: settings.cursorEnabled
            )

            // Setup video encoder
            try videoEncoder.startEncoding(
                outputURL: outputURL,
                resolution: settings.resolution,
                frameRate: settings.frameRate
            )

            // Connect capture to encoder
            captureEngine.videoFrameHandler = { [weak self] pixelBuffer, presentationTime in
                self?.handleFrame(pixelBuffer, presentationTime)
            }

            // Start capture
            try await captureEngine.startCapture()

            // Update state
            let startTime = Date()
            recordingStartTime = startTime
            state = .recording(startTime: startTime)
            duration = 0
            frameCount = 0

            // Start duration timer
            startDurationTimer()

            // Post notification
            NotificationCenter.default.post(name: .recordingStateChanged, object: state)

            logger.info("Recording started successfully: \(outputURL.lastPathComponent)")

        } catch let error as ScreenCaptureEngine.CaptureError {
            cleanup()
            throw RecordingError.captureSetupFailed(error)
        } catch let error as VideoEncoder.EncoderError {
            cleanup()
            throw RecordingError.encodingSetupFailed(error)
        } catch {
            cleanup()
            throw RecordingError.recordingFailed(error)
        }
    }

    /// Stop recording and save the video
    /// - Returns: VideoMetadata for the saved recording
    /// - Throws: RecordingError if recording cannot be stopped
    func stopRecording() async throws -> VideoMetadata {
        guard !state.isIdle else {
            logger.warning("Attempted to stop recording while state is idle")
            throw RecordingError.notRecording
        }

        logger.info("Stopping recording (captured \(self.frameCount) frames)...")

        // Stop duration timer
        stopDurationTimer()

        do {
            // Stop capture
            try await captureEngine.stopCapture()

            // Finish encoding
            let finalURL = try await videoEncoder.finishEncoding()

            // Create metadata
            let metadata = try await createVideoMetadata(url: finalURL)

            // Update state
            state = .idle
            duration = 0

            // Post notification
            NotificationCenter.default.post(name: .recordingStateChanged, object: state)

            // Cleanup
            cleanup()

            logger.info("Recording saved: \(finalURL.lastPathComponent) (\(metadata.fileSizeString))")

            return metadata

        } catch {
            cleanup()
            throw RecordingError.saveFailed(error)
        }
    }

    /// Cancel recording without saving
    func cancelRecording() async {
        guard !state.isIdle else { return }

        logger.warning("Cancelling recording...")

        // Stop timer
        stopDurationTimer()

        // Stop capture
        try? await captureEngine.stopCapture()

        // Cancel encoding (deletes temp file)
        videoEncoder.cancelEncoding()

        // Update state
        state = .idle
        duration = 0

        // Post notification
        NotificationCenter.default.post(name: .recordingStateChanged, object: state)

        // Cleanup
        cleanup()

        logger.info("Recording cancelled")
    }

    // MARK: - Frame Handling

    private func handleFrame(_ pixelBuffer: CVPixelBuffer, _ presentationTime: CMTime) {
        do {
            try videoEncoder.appendFrame(pixelBuffer, at: presentationTime)
            frameCount += 1

            // Log progress every 30 frames (once per second @ 30fps)
            if frameCount % 30 == 0 {
                Task { @MainActor in
                    logger.debug("Recording frame \(self.frameCount) at \(presentationTime.seconds)s")
                }
            }
        } catch {
            Task { @MainActor in
                logger.error("Failed to encode frame: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        // Run timer on main thread
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }
    }

    private func stopDurationTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateDuration() {
        guard let startTime = recordingStartTime else { return }
        duration = Date().timeIntervalSince(startTime)
    }

    // MARK: - File Management

    private func generateOutputURL() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let filename = "REC-\(timestamp).mp4"

        // Use save location from settings
        let saveDirectory = settingsManager.savePath

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: saveDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return saveDirectory.appendingPathComponent(filename)
    }

    private func createVideoMetadata(url: URL) async throws -> VideoMetadata {
        let asset = AVAsset(url: url)

        // Load asset properties
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)

        guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            throw RecordingError.invalidState("No video track found in recording")
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        return VideoMetadata(
            filename: url.lastPathComponent,
            fileURL: url,
            fileSize: fileSize,
            duration: duration.seconds,
            resolution: naturalSize,
            frameRate: Int(nominalFrameRate),
            createdAt: Date(),
            format: "MP4/H.264"
        )
    }

    // MARK: - Cleanup

    private func cleanup() {
        recordingStartTime = nil
        currentOutputURL = nil
        frameCount = 0
        captureEngine.videoFrameHandler = nil
    }
}

// MARK: - AVAsset Import

import AVFoundation
