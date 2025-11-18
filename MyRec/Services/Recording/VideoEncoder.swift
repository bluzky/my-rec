import AVFoundation
import Foundation

/// Encodes video frames to H.264/MP4 using AVAssetWriter
class VideoEncoder {
    // MARK: - Properties
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var isEncoding = false
    private var frameCount: Int = 0
    private var startTime: CMTime?

    private let outputURL: URL
    private let resolution: Resolution
    private let frameRate: FrameRate

    // MARK: - Callbacks
    var onFrameEncoded: ((Int) -> Void)?
    var onEncodingFinished: ((URL, Int) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Lifecycle
    init(outputURL: URL, resolution: Resolution, frameRate: FrameRate) {
        self.outputURL = outputURL
        self.resolution = resolution
        self.frameRate = frameRate
    }

    // MARK: - Public Interface
    func startEncoding() throws {
        guard !isEncoding else { return }

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        startTime = nil

        // Configure video input
        let videoSettings = createVideoSettings()
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        videoInput?.transform = CGAffineTransform(rotationAngle: 0) // No rotation

        // Add input to writer
        guard let videoInput = videoInput,
              let assetWriter = assetWriter,
              assetWriter.canAdd(videoInput) else {
            throw EncodingError.configurationFailed
        }

        assetWriter.add(videoInput)

        // Start writing session
        guard assetWriter.startWriting() else {
            if let error = assetWriter.error {
                print("❌ AVAssetWriter failed to start: \(error)")
            }
            throw EncodingError.writerStartFailed
        }

        isEncoding = true
        frameCount = 0

        print("✅ VideoEncoder: Started encoding to \(outputURL.lastPathComponent)")
        print("✅ Video settings: \(videoSettings)")
    }

    func appendFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isEncoding,
              let videoInput = videoInput,
              let assetWriter = assetWriter else {
            return
        }

        // Ensure buffer is ready before appending
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        // If writer already failed, surface the error once and stop
        if assetWriter.status == .failed {
            if let error = assetWriter.error {
                onError?(error)
            }
            return
        }

        // Start session when the first frame arrives to respect real timestamps
        if startTime == nil {
            startTime = sampleBuffer.presentationTimeStamp
            if let startTime = startTime {
                assetWriter.startSession(atSourceTime: startTime)
                print("⏱️ VideoEncoder: Session started at \(startTime.seconds)s")
            }
        }

        // Only append if input is ready, otherwise silently drop the frame
        guard videoInput.isReadyForMoreMediaData else {
            return
        }

        if videoInput.append(sampleBuffer) {
            frameCount += 1

            // Log progress
            if frameCount % 30 == 0 {
                onFrameEncoded?(frameCount)
                print("💾 Frame \(frameCount) encoded to MP4")
            }
        } else {
            // Don't throw error, just log and continue
            if frameCount % 30 == 0 {
                print("⚠️ Frame dropped at frame \(frameCount) - input not ready")
            }
        }
    }

    func finishEncoding() async throws -> URL {
        guard isEncoding else {
            throw EncodingError.notEncoding
        }

        isEncoding = false

        print("🔄 VideoEncoder: Finishing encoding...")

        // Mark input as finished first
        if let videoInput = videoInput {
            videoInput.markAsFinished()
            print("✅ VideoEncoder: Input marked as finished")
        }

        // Wait a moment for pending frames to be processed
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Finish writing with proper error handling
        guard let assetWriter = assetWriter else {
            throw EncodingError.configurationFailed
        }

        // Bail early if writer is already in a failed state
        if assetWriter.status == .failed {
            throw assetWriter.error ?? EncodingError.configurationFailed
        }

        await assetWriter.finishWriting()

        // Check for errors during finishing
        if let error = assetWriter.error {
            print("❌ VideoEncoder: AVAssetWriter error during finish: \(error)")
            throw error
        }

        // Verify the file was actually created and has content
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw EncodingError.configurationFailed
        }

        let fileSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0
        if fileSize == 0 {
            throw EncodingError.configurationFailed
        }

        print("✅ VideoEncoder: Finished encoding - \(frameCount) frames written, file size: \(formatFileSize(fileSize))")
        onEncodingFinished?(outputURL, frameCount)

        return outputURL
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.2f MB", mb)
    }

    // MARK: - Private Methods
    private func createVideoSettings() -> [String: Any] {
        let bitrate = calculateBitrate()

        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: resolution.width,
            AVVideoHeightKey: resolution.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: frameRate.value * 2, // GOP = 2 seconds
                AVVideoAllowFrameReorderingKey: true,
                AVVideoExpectedSourceFrameRateKey: frameRate.value,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
            ]
        ]
    }

    private func calculateBitrate() -> Int {
        let baseRate: Int
        switch resolution {
        case .hd:       baseRate = 2_500_000  // 2.5 Mbps
        case .fullHD:   baseRate = 5_000_000  // 5 Mbps
        case .twoK:     baseRate = 8_000_000  // 8 Mbps
        case .fourK:    baseRate = 15_000_000 // 15 Mbps
        case .custom:
            // For custom resolution, calculate based on actual dimensions
            let pixels = resolution.width * resolution.height
            baseRate = Int(Double(pixels) * 0.002) // ~0.002 bits per pixel
        }

        // Adjust for frame rate
        let fpsMultiplier = Double(frameRate.value) / 30.0
        return Int(Double(baseRate) * fpsMultiplier)
    }
}

// MARK: - Errors
enum EncodingError: LocalizedError {
    case configurationFailed
    case writerStartFailed
    case appendFailed
    case notEncoding

    var errorDescription: String? {
        switch self {
        case .configurationFailed:
            return "Failed to configure video encoder"
        case .writerStartFailed:
            return "Failed to start AVAssetWriter"
        case .appendFailed:
            return "Failed to append frame to video"
        case .notEncoding:
            return "Encoder is not currently encoding"
        }
    }
}
