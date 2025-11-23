import AVFoundation
import CoreMedia
import Combine

/// Engine responsible for capturing and processing system audio and microphone input
public class AudioCaptureEngine: NSObject, ObservableObject {
    // MARK: - Published Properties

    /// Indicates whether audio is currently being captured
    @Published var isCapturing = false

    /// Current system audio level (0.0 to 1.0)
    @Published var audioLevel: Float = 0.0

    /// Current microphone audio level (0.0 to 1.0)
    @Published var microphoneLevel: Float = 0.0

    /// Indicates whether microphone is monitoring (for pre-recording level display)
    @Published var isMicrophoneMonitoring = false

    // MARK: - Private Properties

    private var assetWriterInput: AVAssetWriterInput?
    private var audioQueue = DispatchQueue(label: "com.myrec.audio", qos: .userInitiated)

    // Microphone-specific properties
    private var audioEngine: AVAudioEngine?
    private var microphoneInput: AVAudioInputNode?
    private var microphoneMonitoringTimer: Timer?

    // MARK: - Initialization

    public override init() {
        super.init()
    }

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
        stopMicrophoneCapture()
    }

    // MARK: - Microphone Methods

    /// Checks microphone permission status WITHOUT requesting
    /// - Returns: True if permission already granted, false otherwise
    func checkMicrophonePermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Requests microphone permission (shows system dialog if needed)
    /// - Returns: True if permission granted, false otherwise
    func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    /// Starts monitoring microphone level (for pre-recording display)
    /// This allows users to see their mic level before starting recording
    func startMicrophoneMonitoring() {
        guard !isMicrophoneMonitoring else { return }

        do {
            // Create audio engine
            let engine = AVAudioEngine()
            self.audioEngine = engine

            let inputNode = engine.inputNode
            self.microphoneInput = inputNode

            // Get the input format from the input node
            let inputFormat = inputNode.outputFormat(forBus: 0)

            print("🎤 Input format: \(inputFormat)")
            print("🎤 Sample rate: \(inputFormat.sampleRate)")
            print("🎤 Channels: \(inputFormat.channelCount)")

            // IMPORTANT: Use the input node's format, not a custom format
            // Install tap for monitoring only (not recording yet)
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                self?.updateMicrophoneLevel(from: buffer)
            }

            // Prepare the engine
            engine.prepare()

            // Start engine
            try engine.start()
            isMicrophoneMonitoring = true
            print("🎤 Microphone monitoring started successfully")
            print("🎤 Engine running: \(engine.isRunning)")
        } catch {
            print("❌ Failed to start microphone monitoring: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }

    /// Stops monitoring microphone level
    func stopMicrophoneMonitoring() {
        guard isMicrophoneMonitoring else { return }

        microphoneInput?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        microphoneInput = nil
        isMicrophoneMonitoring = false
        microphoneLevel = 0.0
        print("🎤 Microphone monitoring stopped")
    }

    /// Starts capturing microphone audio for recording
    func startMicrophoneCapture() throws {
        guard !isCapturing else { return }

        // If already monitoring, upgrade to capturing
        if isMicrophoneMonitoring {
            // Already set up, just mark as capturing
            isCapturing = true
            print("🎤 Microphone upgraded from monitoring to capturing")
        } else {
            // Start fresh
            let engine = AVAudioEngine()
            self.audioEngine = engine

            let inputNode = engine.inputNode
            self.microphoneInput = inputNode

            let inputFormat = inputNode.outputFormat(forBus: 0)

            // Install tap for both monitoring and recording
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
                self?.processMicrophoneBuffer(buffer, at: time)
            }

            try engine.start()
            isCapturing = true
            print("🎤 Microphone capture started")
        }
    }

    /// Stops capturing microphone audio
    func stopMicrophoneCapture() {
        guard audioEngine != nil else { return }

        microphoneInput?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        microphoneInput = nil
        microphoneLevel = 0.0
        isCapturing = false
        isMicrophoneMonitoring = false
        print("🎤 Microphone capture stopped")
    }

    // MARK: - Private Methods

    /// Processes microphone buffer for recording
    private func processMicrophoneBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        // Update level display
        updateMicrophoneLevel(from: buffer)

        // If capturing, convert and write to asset writer
        guard isCapturing,
              let assetWriterInput = assetWriterInput,
              assetWriterInput.isReadyForMoreMediaData else {
            return
        }

        // Convert PCM buffer to CMSampleBuffer
        guard let sampleBuffer = convertToCMSampleBuffer(buffer, at: time) else {
            return
        }

        // Write to asset writer
        audioQueue.async {
            assetWriterInput.append(sampleBuffer)
        }
    }

    /// Updates microphone level from audio buffer
    private func updateMicrophoneLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            print("⚠️ No channel data in buffer")
            return
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            print("⚠️ Buffer frame length is 0")
            return
        }

        let channelCount = Int(buffer.format.channelCount)

        // Calculate RMS (Root Mean Square) for audio level
        var sum: Float = 0

        // Average across all channels
        for channel in 0..<channelCount {
            let channelDataPointer = channelData[channel]
            for frame in 0..<frameLength {
                let sample = channelDataPointer[frame]
                sum += sample * sample
            }
        }

        let totalSamples = Float(frameLength * channelCount)
        let rms = sqrt(sum / totalSamples)

        // Update on main thread for UI binding
        DispatchQueue.main.async { [weak self] in
            // Scale RMS to 0-1 range (multiply by factor for better visibility)
            let scaledLevel = min(rms * 10.0, 1.0)
            self?.microphoneLevel = scaledLevel

            // Debug: print level occasionally
            if Int.random(in: 0...50) == 0 {
                print("🎤 Mic level: \(String(format: "%.2f", scaledLevel)) (RMS: \(String(format: "%.4f", rms)))")
            }
        }
    }

    /// Converts AVAudioPCMBuffer to CMSampleBuffer
    private func convertToCMSampleBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) -> CMSampleBuffer? {
        let formatDescription = buffer.format.formatDescription

        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(
                value: CMTimeValue(buffer.frameLength),
                timescale: CMTimeScale(buffer.format.sampleRate)
            ),
            presentationTimeStamp: CMTime(
                seconds: Double(time.sampleTime) / buffer.format.sampleRate,
                preferredTimescale: CMTimeScale(buffer.format.sampleRate)
            ),
            decodeTimeStamp: .invalid
        )

        let status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: CMItemCount(buffer.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr else {
            print("❌ Failed to create CMSampleBuffer from microphone audio")
            return nil
        }

        return sampleBuffer
    }

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
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .unsupportedSettings:
            return "The audio settings are not supported by the asset writer"
        case .cannotAddInput:
            return "Cannot add audio input to the asset writer"
        case .captureFailed:
            return "Audio capture failed"
        case .microphonePermissionDenied:
            return "Microphone permission denied. Please enable in System Settings > Privacy & Security > Microphone"
        }
    }
}
