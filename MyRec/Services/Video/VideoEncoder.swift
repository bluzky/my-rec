import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import OSLog

/// Encodes video frames to H.264/MP4 using AVAssetWriter
/// Handles frame appending, timing, and file output
class VideoEncoder {

    // MARK: - Types

    enum EncoderError: LocalizedError {
        case notConfigured
        case alreadyEncoding
        case notEncoding
        case writerCreationFailed(Error)
        case inputConfigurationFailed(String)
        case startWritingFailed(Error)
        case appendFrameFailed(Error)
        case finishWritingFailed(Error)
        case invalidFrameData
        case fileOperationFailed(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Encoder has not been configured. Call startEncoding() first."
            case .alreadyEncoding:
                return "Encoder is already encoding. Stop current encoding before starting a new one."
            case .notEncoding:
                return "Encoder is not currently encoding."
            case .writerCreationFailed(let error):
                return "Failed to create AVAssetWriter: \(error.localizedDescription)"
            case .inputConfigurationFailed(let message):
                return "Failed to configure video input: \(message)"
            case .startWritingFailed(let error):
                return "Failed to start writing: \(error.localizedDescription)"
            case .appendFrameFailed(let error):
                return "Failed to append frame: \(error.localizedDescription)"
            case .finishWritingFailed(let error):
                return "Failed to finish writing: \(error.localizedDescription)"
            case .invalidFrameData:
                return "Invalid frame data provided."
            case .fileOperationFailed(let error):
                return "File operation failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var outputURL: URL?
    private var tempOutputURL: URL?
    private var resolution: Resolution?
    private var frameRate: FrameRate?

    private var isEncoding = false
    private var frameCount = 0
    private var startTime: CMTime?

    private let logger = Logger(subsystem: "com.myrec.app", category: "VideoEncoder")

    // MARK: - Configuration

    /// Start encoding with specified settings
    /// - Parameters:
    ///   - outputURL: Final output URL for the encoded video
    ///   - resolution: Target resolution
    ///   - frameRate: Target frame rate
    /// - Throws: EncoderError if encoding cannot be started
    func startEncoding(outputURL: URL, resolution: Resolution, frameRate: FrameRate) throws {
        guard !isEncoding else {
            throw EncoderError.alreadyEncoding
        }

        // Store settings
        self.outputURL = outputURL
        self.resolution = resolution
        self.frameRate = frameRate

        // Create temporary file URL (atomic write)
        let tempURL = outputURL.deletingLastPathComponent()
            .appendingPathComponent("temp_\(UUID().uuidString).mp4")
        self.tempOutputURL = tempURL

        logger.info("Starting encoding: \(resolution.rawValue) @ \(frameRate.value)fps -> \(tempURL.path)")

        // Create asset writer
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: tempURL, fileType: .mp4)
        } catch {
            logger.error("Failed to create AVAssetWriter: \(error.localizedDescription)")
            throw EncoderError.writerCreationFailed(error)
        }

        // Create video settings
        let videoSettings = createVideoSettings(resolution: resolution, frameRate: frameRate)

        // Create video input
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true

        // Create pixel buffer adaptor
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: resolution.width,
            kCVPixelBufferHeightKey as String: resolution.height
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        // Add input to writer
        guard writer.canAdd(input) else {
            throw EncoderError.inputConfigurationFailed("Cannot add video input to writer")
        }

        writer.add(input)

        // Start writing session
        guard writer.startWriting() else {
            if let error = writer.error {
                throw EncoderError.startWritingFailed(error)
            }
            throw EncoderError.startWritingFailed(
                NSError(domain: "VideoEncoder", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Unknown error starting writing"])
            )
        }

        writer.startSession(atSourceTime: .zero)

        // Store references
        self.assetWriter = writer
        self.videoInput = input
        self.pixelBufferAdaptor = adaptor

        self.isEncoding = true
        self.frameCount = 0
        self.startTime = nil

        logger.info("Encoding started successfully")
    }

    // MARK: - Frame Appending

    /// Append a video frame to the encoding
    /// - Parameters:
    ///   - pixelBuffer: The frame to append
    ///   - presentationTime: The presentation timestamp for the frame
    /// - Throws: EncoderError if frame cannot be appended
    func appendFrame(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime) throws {
        guard isEncoding else {
            throw EncoderError.notEncoding
        }

        guard let input = videoInput, let adaptor = pixelBufferAdaptor else {
            throw EncoderError.notConfigured
        }

        // Store first frame time
        if startTime == nil {
            startTime = presentationTime
            logger.info("First frame at time: \(presentationTime.seconds)s")
        }

        // Wait for input to be ready
        // In real-time encoding, we should handle backpressure
        var waitCount = 0
        while !input.isReadyForMoreMediaData {
            if waitCount > 100 {
                logger.warning("Input not ready after 100 attempts, dropping frame")
                return
            }
            Thread.sleep(forTimeInterval: 0.01) // Wait 10ms
            waitCount += 1
        }

        // Append the frame
        let success = adaptor.append(pixelBuffer, withPresentationTime: presentationTime)

        if success {
            frameCount += 1
            if frameCount % 30 == 0 {
                logger.debug("Encoded frame \(self.frameCount) at \(presentationTime.seconds)s")
            }
        } else {
            if let error = assetWriter?.error {
                throw EncoderError.appendFrameFailed(error)
            }
            throw EncoderError.appendFrameFailed(
                NSError(domain: "VideoEncoder", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Unknown error appending frame"])
            )
        }
    }

    // MARK: - Finish Encoding

    /// Finish encoding and finalize the output file
    /// - Returns: URL of the final encoded video file
    /// - Throws: EncoderError if encoding cannot be finished
    @discardableResult
    func finishEncoding() async throws -> URL {
        guard isEncoding else {
            throw EncoderError.notEncoding
        }

        guard let writer = assetWriter,
              let input = videoInput,
              let tempURL = tempOutputURL,
              let finalURL = outputURL else {
            throw EncoderError.notConfigured
        }

        logger.info("Finishing encoding (\(self.frameCount) frames)...")

        // Mark input as finished
        input.markAsFinished()

        // Finish writing
        await writer.finishWriting()

        // Check for errors
        if writer.status == .failed {
            if let error = writer.error {
                logger.error("Encoding failed: \(error.localizedDescription)")
                throw EncoderError.finishWritingFailed(error)
            }
            throw EncoderError.finishWritingFailed(
                NSError(domain: "VideoEncoder", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Encoding failed with unknown error"])
            )
        }

        // Move temp file to final location (atomic write)
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }

            // Move temp file to final location
            try FileManager.default.moveItem(at: tempURL, to: finalURL)

            logger.info("Encoding completed: \(finalURL.path)")
        } catch {
            logger.error("Failed to move file: \(error.localizedDescription)")
            throw EncoderError.fileOperationFailed(error)
        }

        // Get file size
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: finalURL.path)[.size] as? Int64) ?? 0
        logger.info("Output file size: \(fileSize / 1024 / 1024) MB")

        // Cleanup
        cleanup()

        return finalURL
    }

    // MARK: - Cancel

    /// Cancel encoding and cleanup
    func cancelEncoding() {
        guard isEncoding else { return }

        logger.warning("Cancelling encoding...")

        if let input = videoInput {
            input.markAsFinished()
        }

        assetWriter?.cancelWriting()

        // Remove temp file
        if let tempURL = tempOutputURL {
            try? FileManager.default.removeItem(at: tempURL)
        }

        cleanup()

        logger.info("Encoding cancelled")
    }

    // MARK: - Private Methods

    private func cleanup() {
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        outputURL = nil
        tempOutputURL = nil
        resolution = nil
        frameRate = nil
        isEncoding = false
        frameCount = 0
        startTime = nil
    }

    private func createVideoSettings(resolution: Resolution, frameRate: FrameRate) -> [String: Any] {
        let bitrate = calculateBitrate(resolution: resolution, frameRate: frameRate)

        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: frameRate.value * 2, // Keyframe every 2 seconds
            AVVideoAllowFrameReorderingKey: true,
            AVVideoExpectedSourceFrameRateKey: frameRate.value,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
        ]

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: resolution.width,
            AVVideoHeightKey: resolution.height,
            AVVideoCompressionPropertiesKey: compressionProperties
        ]

        logger.debug("Video settings: \(resolution.rawValue) @ \(frameRate.value)fps, bitrate: \(bitrate / 1_000_000) Mbps")

        return videoSettings
    }

    private func calculateBitrate(resolution: Resolution, frameRate: FrameRate) -> Int {
        // Base bitrate for 30fps
        let baseRate: Int

        switch resolution {
        case .hd:       baseRate = 2_500_000   // 2.5 Mbps for 720p
        case .fullHD:   baseRate = 5_000_000   // 5 Mbps for 1080p
        case .twoK:     baseRate = 8_000_000   // 8 Mbps for 2K
        case .fourK:    baseRate = 15_000_000  // 15 Mbps for 4K
        case .custom:   baseRate = 5_000_000   // Default to 1080p equivalent
        }

        // Adjust for frame rate (60fps needs ~1.5x bitrate)
        let fpsMultiplier = Double(frameRate.value) / 30.0
        let adjustedBitrate = Int(Double(baseRate) * fpsMultiplier)

        return adjustedBitrate
    }
}
