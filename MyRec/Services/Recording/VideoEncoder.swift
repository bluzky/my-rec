import AVFoundation
import Foundation

/// Encodes video frames to H.264/MP4 using AVAssetWriter
class VideoEncoder {
    // MARK: - Properties
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isEncoding = false
    private var frameCount: Int = 0
    private var startTime: CMTime?

    private let outputURL: URL
    private let resolution: Resolution
    private let frameRate: FrameRate

    // Audio support
    private var audioCaptureEngine: AudioCaptureEngine?
    private var includeAudio: Bool = false

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
    func startEncoding(withAudio: Bool = true) throws {
        guard !isEncoding else { return }

        self.includeAudio = withAudio

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        startTime = nil

        // Configure video input
        let videoSettings = createVideoSettings()
        print("🎥 VideoEncoder: Creating video input with settings: \(videoSettings)")

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        videoInput?.transform = CGAffineTransform(rotationAngle: 0) // No rotation

        // Add input to writer
        guard let videoInput = videoInput,
              let assetWriter = assetWriter else {
            print("❌ VideoEncoder: Failed to create video input or asset writer")
            throw EncodingError.configurationFailed
        }

        guard assetWriter.canAdd(videoInput) else {
            print("❌ VideoEncoder: Cannot add video input to asset writer")
            print("  Asset writer status: \(assetWriter.status)")
            if let error = assetWriter.error {
                print("  Asset writer error: \(error)")
            }
            throw EncodingError.configurationFailed
        }

        assetWriter.add(videoInput)

        // Create pixel buffer adaptor for BGRA format
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: resolution.width,
            kCVPixelBufferHeightKey as String: resolution.height
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        // Configure audio input if enabled
        if includeAudio {
            audioCaptureEngine = AudioCaptureEngine()
            if let audioEngine = audioCaptureEngine {
                try audioEngine.setupAudioInput(for: assetWriter)
                print("🎵 VideoEncoder: Audio input configured")
            }
        }

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
        print("✅ Pixel buffer adaptor created for BGRA format")
    }

    func appendFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isEncoding,
              let videoInput = videoInput,
              let assetWriter = assetWriter,
              let adaptor = pixelBufferAdaptor else {
            return
        }

        // If writer already failed, surface the error once and stop
        if assetWriter.status == .failed {
            print("❌ VideoEncoder: Asset writer failed, cannot append frame")
            if let error = assetWriter.error {
                print("  Error: \(error)")
                onError?(error)
            }
            return
        }

        // Ensure buffer is ready before appending
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("⚠️ VideoEncoder: Sample buffer not ready")
            return
        }

        // Extract pixel buffer from sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("⚠️ VideoEncoder: Could not get pixel buffer from sample buffer")
            return
        }

        // Get presentation timestamp
        let presentationTime = sampleBuffer.presentationTimeStamp

        // Start session when the first frame arrives to respect real timestamps
        if startTime == nil {
            startTime = presentationTime
            if let startTime = startTime {
                print("⏱️ VideoEncoder: Starting session at \(startTime.seconds)s")
                assetWriter.startSession(atSourceTime: startTime)
                print("✅ VideoEncoder: Session started successfully")
            }
        }

        // Only append if input is ready, otherwise silently drop the frame
        guard videoInput.isReadyForMoreMediaData else {
            return
        }

        // Append pixel buffer using adaptor
        if adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
            frameCount += 1

            // Log progress
            if frameCount % 30 == 0 {
                onFrameEncoded?(frameCount)
                print("💾 Frame \(frameCount) encoded successfully")
            }
        } else {
            // Log append failure for debugging
            print("❌ VideoEncoder: Failed to append frame \(frameCount + 1)")
            print("  Video input ready: \(videoInput.isReadyForMoreMediaData)")
            print("  Asset writer status: \(assetWriter.status)")
            if assetWriter.status == .failed, let error = assetWriter.error {
                print("  Asset writer error: \(error)")
            }
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard isEncoding, includeAudio else { return }

        // Pass audio buffer to audio capture engine
        audioCaptureEngine?.processSampleBuffer(sampleBuffer)
    }

    func finishEncoding() async throws -> URL {
        guard isEncoding else {
            throw EncodingError.notEncoding
        }

        isEncoding = false

        print("🔄 VideoEncoder: Finishing encoding...")

        // Stop audio capture first
        if includeAudio {
            audioCaptureEngine?.stopCapturing()
            print("✅ VideoEncoder: Audio input finished")
        }

        // Mark video input as finished
        if let videoInput = videoInput {
            videoInput.markAsFinished()
            print("✅ VideoEncoder: Video input marked as finished")
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

        print("🎥 VideoEncoder: Creating video settings...")
        print("  Codec: H.264")
        print("  Resolution: \(resolution.width)x\(resolution.height)")
        print("  Frame Rate: \(frameRate.value)")
        print("  Bitrate: \(bitrate)")

        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: frameRate.value * 2,
            AVVideoExpectedSourceFrameRateKey: frameRate.value
        ]

        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: resolution.width,
            AVVideoHeightKey: resolution.height,
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
    }

    private func calculateBitrate() -> Int {
        let baseRate: Int
        switch resolution {
        case .hd:       baseRate = 2_500_000  // 2.5 Mbps
        case .fullHD:   baseRate = 5_000_000  // 5 Mbps
        case .twoK:     baseRate = 8_000_000  // 8 Mbps
        case .fourK:    baseRate = 15_000_000 // 15 Mbps
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
