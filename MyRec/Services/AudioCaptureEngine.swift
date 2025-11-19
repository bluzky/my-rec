import AVFoundation
import CoreMedia
import Combine

/// Engine responsible for capturing and processing system audio
class AudioCaptureEngine: NSObject, ObservableObject {
    // MARK: - Published Properties

    /// Indicates whether audio is currently being captured
    @Published var isCapturing = false

    /// Current audio level (0.0 to 1.0)
    @Published var audioLevel: Float = 0.0

    // MARK: - Private Properties

    private var assetWriterInput: AVAssetWriterInput?
    private var audioQueue = DispatchQueue(label: "com.myrec.audio", qos: .userInitiated)

    /// Audio encoding settings for AAC at 48kHz stereo
    private var audioSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
    }

    // MARK: - Public Methods

    /// Sets up the audio input for the asset writer
    /// - Parameter assetWriter: The AVAssetWriter to configure
    /// - Throws: AudioError if setup fails
    func setupAudioInput(for assetWriter: AVAssetWriter) throws {
        guard assetWriter.canApply(outputSettings: audioSettings,
                                   forMediaType: .audio) else {
            throw AudioError.unsupportedSettings
        }

        let input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: audioSettings
        )

        input.expectsMediaDataInRealTime = true

        if assetWriter.canAdd(input) {
            assetWriter.add(input)
            self.assetWriterInput = input
        } else {
            throw AudioError.cannotAddInput
        }
    }

    /// Processes an audio sample buffer
    /// - Parameter sampleBuffer: The audio sample buffer to process
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let input = assetWriterInput,
              input.isReadyForMoreMediaData else {
            return
        }

        // Calculate audio level for monitoring
        updateAudioLevel(from: sampleBuffer)

        // Write to asset writer on background queue
        let bufferCopy = sampleBuffer
        audioQueue.async { [weak input] in
            guard let input = input else { return }
            input.append(bufferCopy)
        }
    }

    /// Starts audio capture
    func startCapturing() {
        isCapturing = true
        audioLevel = 0.0
    }

    /// Stops audio capture and marks the input as finished
    func stopCapturing() {
        isCapturing = false
        audioLevel = 0.0
        assetWriterInput?.markAsFinished()
        assetWriterInput = nil
    }

    // MARK: - Private Methods

    /// Updates the audio level based on the sample buffer's RMS value
    /// - Parameter sampleBuffer: The audio sample buffer to analyze
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

        // Calculate RMS (Root Mean Square) for audio level
        let samples = UnsafeBufferPointer(
            start: UnsafeMutableRawPointer(data)
                .assumingMemoryBound(to: Int16.self),
            count: length / MemoryLayout<Int16>.size
        )

        guard samples.count > 0 else { return }

        var sum: Float = 0
        for sample in samples {
            let normalized = Float(sample) / Float(Int16.max)
            sum += normalized * normalized
        }

        let rms = sqrt(sum / Float(samples.count))

        // Update on main thread for UI binding
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = min(rms, 1.0)
        }
    }
}

// MARK: - Errors

enum AudioError: Error, LocalizedError {
    case unsupportedSettings
    case cannotAddInput
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedSettings:
            return "The audio settings are not supported by the asset writer"
        case .cannotAddInput:
            return "Cannot add audio input to the asset writer"
        case .captureFailed:
            return "Audio capture failed"
        }
    }
}
