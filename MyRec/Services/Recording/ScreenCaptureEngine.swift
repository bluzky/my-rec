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

    // Audio mixer (macOS 15+ for mixing). Stored as Any? to avoid @available on stored property.
    private var audioMixer: Any?

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

        print("🎵 System audio enabled: \(captureAudio)")
        print("🎤 Microphone enabled: \(captureMicrophone)")

        // Setup stream (permission already checked in AppDelegate) and get output dimensions
        let streamSetup = try await setupStream(resolution: resolution, frameRate: frameRate)
        stream = streamSetup.stream

        // Prepare encoder using actual stream output dimensions to avoid scaling artifacts
        guard let tempURL = tempURL else {
            throw CaptureError.configurationFailed
        }

        print("🎯 Output dimensions: \(streamSetup.outputSize.width)x\(streamSetup.outputSize.height)")

        videoEncoder = VideoEncoder(
            outputURL: tempURL,
            width: streamSetup.outputSize.width,
            height: streamSetup.outputSize.height,
            frameRate: frameRate,
            nominalResolution: resolution
        )

        videoEncoder?.onFrameEncoded = { frame in
            print("💾 Frame \(frame) encoded to MP4")
        }

        videoEncoder?.onError = { error in
            print("❌ Encoding error: \(error)")
        }

        try videoEncoder?.startEncoding(withAudio: captureAudio || captureMicrophone)
        print("✅ Encoder started - Output: \(tempURL.lastPathComponent)")

        // Initialize mixer if both audio sources enabled (macOS 15+)
        if #available(macOS 15.0, *), captureAudio && captureMicrophone {
            audioMixer = SimpleMixer(encoder: videoEncoder) as Any
            print("🎚️ Audio mixer initialized for dual-source recording")
        } else {
            audioMixer = nil
        }

        // Start capture now that encoder is ready
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
        // Update audio level for UI
        updateAudioLevel(from: sampleBuffer)

        // Use mixer if both sources enabled, otherwise direct to encoder
        if #available(macOS 15.0, *), let mixer = audioMixer as? SimpleMixer {
            mixer.addSystem(sampleBuffer)
        } else {
            videoEncoder?.appendAudio(sampleBuffer)
        }
    }

    private func handleMicrophoneSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Update microphone level for UI
        updateMicrophoneLevel(from: sampleBuffer)

        // Use mixer if both sources enabled, otherwise direct to encoder
        if #available(macOS 15.0, *), let mixer = audioMixer as? SimpleMixer {
            mixer.addMic(sampleBuffer)
        } else {
            videoEncoder?.appendAudio(sampleBuffer)
        }
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

        // Configure audio capture (macOS 13+)
        if captureAudio {
            if #available(macOS 13.0, *) {
                config.capturesAudio = true
                config.sampleRate = 48000
                config.channelCount = 2
                config.excludesCurrentProcessAudio = true  // Prevent feedback from our own app
                print("🎵 Audio capture enabled: 48kHz stereo (excluding own process)")
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
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)

        // Add stream output for video
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())

        // Add stream output for audio if enabled (macOS 13+)
        if captureAudio {
            if #available(macOS 13.0, *) {
                try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
            }
        }

        // Add stream output for microphone if enabled (macOS 15+)
        if captureMicrophone {
            if #available(macOS 15.0, *) {
                try newStream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: .global())
                print("🎤 Microphone stream output registered")
            }
        }

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

// MARK: - SimpleMixer

/// Lightweight audio mixer for combining system audio and microphone
@available(macOS 15.0, *)
final class SimpleMixer {
    private var lastMic: CMSampleBuffer?
    private weak var encoder: VideoEncoder?
    private let mixerQueue = DispatchQueue(label: "com.myrec.audiomixer", qos: .userInitiated)

    // Output format: locked once from first system buffer and always interleaved Float32 for encoder stability
    private var outputFormat: CMAudioFormatDescription?
    private var formatLocked = false
    private var targetSampleRate: Double = 48_000
    private var targetChannels: Int = 2

    // Track last mic format to detect device changes
    private var lastMicFormat: AudioStreamBasicDescription?
    private var micConverter: AVAudioConverter?

    init(encoder: VideoEncoder?) {
        self.encoder = encoder
    }

    /// Reset mixer state when audio device changes
    func resetForDeviceChange() {
        mixerQueue.async { [weak self] in
            guard let self = self else { return }
            print("🔄 SimpleMixer: Resetting state for device change")
            self.lastMic = nil
            self.lastMicFormat = nil
            self.micConverter = nil
            // Keep output format so encoder format remains stable
        }
    }

    func addSystem(_ sampleBuffer: CMSampleBuffer) {
        mixerQueue.async { [weak self] in
            guard let self = self else { return }

            // Lock output format to system audio's native format on first system buffer
            if !self.formatLocked {
                guard let sysDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
                      let sysASBD = CMAudioFormatDescriptionGetStreamBasicDescription(sysDesc)?.pointee else {
                    print("⚠️ SimpleMixer: Cannot lock output format - missing system ASBD")
                    return
                }

                // Use system sample rate and channel count but force interleaved Float32 for encoder stability
                self.targetSampleRate = sysASBD.mSampleRate
                self.targetChannels = Int(sysASBD.mChannelsPerFrame)
                self.outputFormat = Self.makeInterleavedFloatFormat(sampleRate: self.targetSampleRate, channels: self.targetChannels)
                self.formatLocked = self.outputFormat != nil

                if let fmt = self.outputFormat,
                   let locked = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)?.pointee {
                    print("🎚️ SimpleMixer: Format locked for encoder: \(locked.mSampleRate)Hz \(locked.mChannelsPerFrame)ch interleaved Float32")
                } else {
                    print("⚠️ SimpleMixer: Failed to lock output format")
                }
            }

            guard let outputFormat = self.outputFormat else {
                print("⚠️ SimpleMixer: No output format, forwarding system as-is")
                self.forward(sampleBuffer)
                return
            }

            guard let mic = self.lastMic else {
                // No mic buffer yet, forward converted system audio only
                if let convertedSystem = self.convertBuffer(sampleBuffer, targetFormat: outputFormat) {
                    print("🔊 SimpleMixer: No mic buffer yet, forwarding converted system")
                    self.forward(convertedSystem)
                } else {
                    print("⚠️ SimpleMixer: Failed to convert system buffer, forwarding raw")
                    self.forward(sampleBuffer)
                }
                return
            }

            // Mix system (native format) with mic (needs conversion to match system format)
            if let mixed = self.mix(system: sampleBuffer, mic: mic) {
                print("🎚️ SimpleMixer: Successfully mixed system + mic")
                self.forward(mixed)
            } else {
                // Mix failed, forward converted system only
                print("⚠️ SimpleMixer: Mix failed, forwarding system as-is")
                if let convertedSystem = self.convertBuffer(sampleBuffer, targetFormat: outputFormat) {
                    self.forward(convertedSystem)
                } else {
                    self.forward(sampleBuffer)
                }
            }
        }
    }

    func addMic(_ sampleBuffer: CMSampleBuffer) {
        mixerQueue.async { [weak self] in
            guard let self = self else { return }

            // Get mic format
            guard let micFormatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
                  let micASBD = CMAudioFormatDescriptionGetStreamBasicDescription(micFormatDesc)?.pointee else {
                print("⚠️ SimpleMixer: Failed to get mic format")
                return
            }

            // Detect device change by comparing format
            if let lastFormat = self.lastMicFormat {
                if lastFormat.mSampleRate != micASBD.mSampleRate ||
                   lastFormat.mChannelsPerFrame != micASBD.mChannelsPerFrame ||
                   lastFormat.mFormatFlags != micASBD.mFormatFlags {
                    let isFloat = (micASBD.mFormatFlags & kAudioFormatFlagIsFloat) != 0
                    let isSigned = (micASBD.mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0
                    let formatName = isFloat ? "Float32" : (isSigned ? "Int16" : "Unknown")

                    print("🔄 SimpleMixer: Mic device/format changed - clearing cached buffer")
                    print("   Old: \(lastFormat.mSampleRate)Hz \(lastFormat.mChannelsPerFrame)ch Flags:\(lastFormat.mFormatFlags)")
                    print("   New: \(micASBD.mSampleRate)Hz \(micASBD.mChannelsPerFrame)ch Flags:\(micASBD.mFormatFlags) (\(formatName))")
                    self.lastMic = nil  // Clear stale mic buffer
                }
            }

            // Update tracked format
            self.lastMicFormat = micASBD

            let isFloat = (micASBD.mFormatFlags & kAudioFormatFlagIsFloat) != 0
            let formatType = isFloat ? "Float32" : "Int16"
            print("🎤 SimpleMixer: Received mic buffer (\(micASBD.mSampleRate)Hz \(micASBD.mChannelsPerFrame)ch \(formatType))")

            // Store mic buffer for mixing
            self.lastMic = sampleBuffer

            // Note: We don't forward mic independently to avoid timing issues
            // The mic buffer will be mixed with the next system buffer
        }
    }

    private func mix(system: CMSampleBuffer, mic: CMSampleBuffer) -> CMSampleBuffer? {
        // Get format info
        guard let sysDesc = CMSampleBufferGetFormatDescription(system),
              let micDesc = CMSampleBufferGetFormatDescription(mic),
              let sysFormat = CMAudioFormatDescriptionGetStreamBasicDescription(sysDesc)?.pointee,
              let micFormat = CMAudioFormatDescriptionGetStreamBasicDescription(micDesc)?.pointee else {
            print("⚠️ SimpleMixer: Failed to get format info")
            return nil
        }

        // Log format details
        let sysInterleaved = (sysFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
        let micInterleaved = (micFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
        print("📊 SimpleMixer: System - Rate:\(sysFormat.mSampleRate) Ch:\(sysFormat.mChannelsPerFrame) Flags:\(sysFormat.mFormatFlags) Interleaved:\(sysInterleaved)")
        print("📊 SimpleMixer: Mic    - Rate:\(micFormat.mSampleRate) Ch:\(micFormat.mChannelsPerFrame) Flags:\(micFormat.mFormatFlags) Interleaved:\(micInterleaved)")

        guard let outputFormat = outputFormat else {
            print("⚠️ SimpleMixer: No output format locked")
            return nil
        }

        // Convert both buffers to target interleaved float arrays
        guard let systemInterleaved = convertToInterleavedFloats(from: system, targetRate: targetSampleRate, targetChannels: targetChannels) else {
            print("⚠️ SimpleMixer: Failed to convert system buffer")
            return nil
        }

        guard let micInterleaved = convertMicToInterleavedFloats(from: mic, targetRate: targetSampleRate, targetChannels: targetChannels) else {
            print("⚠️ SimpleMixer: Failed to convert mic buffer")
            return nil
        }

        let count = min(systemInterleaved.count, micInterleaved.count)
        var mixed = [Float](repeating: 0, count: count)

        var sysRMS: Float = 0
        var micRMS: Float = 0
        for i in 0..<count {
            let s = systemInterleaved[i]
            let m = micInterleaved[i]
            sysRMS += s * s
            micRMS += m * m
            mixed[i] = tanh(s + m)
        }
        sysRMS = sqrt(sysRMS / Float(count))
        micRMS = sqrt(micRMS / Float(count))
        print("📊 SimpleMixer: System RMS: \(String(format: "%.4f", sysRMS)), Mic RMS: \(String(format: "%.4f", micRMS))")

        // Consume mic buffer so it isn't replayed on subsequent system buffers (prevents "sped up" mic)
        lastMic = nil

        return makeInterleavedBuffer(from: mixed, format: outputFormat, like: system)
    }


    /// Extract audio as interleaved Float32 samples at original rate
    private func extractInterleavedFloats(from sampleBuffer: CMSampleBuffer) -> (samples: [Float], channels: Int, sampleRate: Double)? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else {
            return nil
        }

        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let isSigned = (asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0
        let isNonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0
        let bitsPerChannel = asbd.mBitsPerChannel
        let channels = Int(asbd.mChannelsPerFrame)

        // Validate format is supported
        guard validateAudioFormat(asbd: asbd) else {
            let formatType = isFloat ? "Float\(bitsPerChannel)" : "Int\(bitsPerChannel)"
            print("⚠️ SimpleMixer: Unsupported audio format: \(formatType) \(channels)ch @ \(asbd.mSampleRate)Hz")
            return nil
        }

        // Get AudioBufferList
        var bufferListSizeNeeded: Int = 0
        var status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &bufferListSizeNeeded,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: nil
        )

        guard status == noErr || status == kCMSampleBufferError_ArrayTooSmall else {
            return nil
        }

        let audioBufferList = AudioBufferList.allocate(maximumBuffers: channels)
        defer { free(audioBufferList.unsafeMutablePointer) }

        var blockBuffer: CMBlockBuffer?
        status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList.unsafeMutablePointer,
            bufferListSize: bufferListSizeNeeded,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else {
            return nil
        }

        let bufferCount = Int(audioBufferList.count)
        guard bufferCount > 0 else {
            return nil
        }

        if isNonInterleaved {
            // Convert each channel then interleave
            var channelArrays: [[Float]] = []
            for ch in 0..<channels {
                guard let data = audioBufferList[ch].mData else { continue }
                let byteSize = Int(audioBufferList[ch].mDataByteSize)
                if let converted = convertToFloat(
                    data: data,
                    byteSize: byteSize,
                    isFloat: isFloat,
                    isSigned: isSigned,
                    bitsPerChannel: bitsPerChannel,
                    channels: 1
                ) {
                    channelArrays.append(converted)
                }
            }

            guard !channelArrays.isEmpty else { return nil }
            let frames = channelArrays[0].count
            var interleaved = [Float](repeating: 0, count: frames * channels)
            for ch in 0..<channels {
                for frame in 0..<frames {
                    interleaved[frame * channels + ch] = channelArrays[ch][frame]
                }
            }
            return (interleaved, channels, asbd.mSampleRate)
        } else {
            // Interleaved: convert directly
            let firstBuffer = audioBufferList[0]
            guard let data = firstBuffer.mData else { return nil }
            let byteSize = Int(firstBuffer.mDataByteSize)

            if let interleavedFloat = convertToFloat(
                data: data,
                byteSize: byteSize,
                isFloat: isFloat,
                isSigned: isSigned,
                bitsPerChannel: bitsPerChannel,
                channels: channels
            ) {
                return (interleavedFloat, channels, asbd.mSampleRate)
            }
        }

        return nil
    }

    /// Convert mic to target rate/channels, interleaved Float32 (uses AVAudioConverter when available)
    private func convertMicToInterleavedFloats(from sampleBuffer: CMSampleBuffer, targetRate: Double, targetChannels: Int) -> [Float]? {
        guard let micDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              var micASBD = CMAudioFormatDescriptionGetStreamBasicDescription(micDesc)?.pointee else {
            return nil
        }

        // Build converter if needed
        if micConverter == nil ||
            micConverter?.inputFormat.sampleRate != micASBD.mSampleRate ||
            micConverter?.inputFormat.channelCount != micASBD.mChannelsPerFrame {

            guard let inputFormat = AVAudioFormat(streamDescription: &micASBD) else {
                print("⚠️ SimpleMixer: Failed to build input format for mic converter")
                return nil
            }

            guard let outputFormat = AVAudioFormat(standardFormatWithSampleRate: targetRate, channels: AVAudioChannelCount(targetChannels)) else {
                print("⚠️ SimpleMixer: Failed to build output format for mic converter")
                return nil
            }

            micConverter = AVAudioConverter(from: inputFormat, to: outputFormat)
        }

        guard let converter = micConverter else {
            print("⚠️ SimpleMixer: Mic converter unavailable")
            return nil
        }

        // Create input PCM buffer from CMSampleBuffer
        let inputFormat = converter.inputFormat
        guard let inputPCM = makePCMBuffer(from: sampleBuffer, format: inputFormat) else {
            print("⚠️ SimpleMixer: Failed to create input PCM buffer for conversion")
            return nil
        }

        let frameCapacity = AVAudioFrameCount(Double(inputPCM.frameLength) * targetRate / inputFormat.sampleRate) + 1024
        guard let outputPCM = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: frameCapacity) else {
            print("⚠️ SimpleMixer: Failed to allocate output PCM buffer")
            return nil
        }

        var conversionError: NSError?
        let status = converter.convert(to: outputPCM, error: &conversionError) { _, outStatus in
            outStatus.pointee = .haveData
            return inputPCM
        }

        if status != .haveData || conversionError != nil {
            print("⚠️ SimpleMixer: Mic conversion failed: \(conversionError?.localizedDescription ?? "unknown error")")
            return nil
        }

        guard let interleaved = outputPCM.floatChannelData else { return nil }
        let frames = Int(outputPCM.frameLength)
        let channels = Int(outputPCM.format.channelCount)
        var result = [Float](repeating: 0, count: frames * channels)
        for frame in 0..<frames {
            for ch in 0..<channels {
                result[frame * channels + ch] = interleaved[ch][frame]
            }
        }
        return result
    }

    /// Convert any buffer to interleaved Float32 with given rate/channels (no channel duplication)
    private func convertToInterleavedFloats(from sampleBuffer: CMSampleBuffer, targetRate: Double, targetChannels: Int) -> [Float]? {
        guard let extracted = extractInterleavedFloats(from: sampleBuffer) else { return nil }
        var samples = extracted.samples

        // Channel up-mix if needed (duplicate mono)
        if extracted.channels == 1 && targetChannels == 2 {
            var stereo = [Float](repeating: 0, count: samples.count * 2)
            let frames = samples.count
            for i in 0..<frames {
                let s = samples[i]
                stereo[i * 2] = s
                stereo[i * 2 + 1] = s
            }
            samples = stereo
        }

        // Resample if needed
        if extracted.sampleRate != targetRate {
            samples = resample(samples, fromRate: extracted.sampleRate, toRate: targetRate, channels: targetChannels)
        }

        return samples
    }

    /// Convert buffer (system/mixed) to target format CMSampleBuffer
    private func convertBuffer(_ sampleBuffer: CMSampleBuffer, targetFormat: CMAudioFormatDescription) -> CMSampleBuffer? {
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(targetFormat)?.pointee else { return nil }
        let targetChannels = Int(asbd.mChannelsPerFrame)
        let targetRate = asbd.mSampleRate
        guard let interleaved = convertToInterleavedFloats(from: sampleBuffer, targetRate: targetRate, targetChannels: targetChannels) else {
            return nil
        }
        return makeInterleavedBuffer(from: interleaved, format: targetFormat, like: sampleBuffer)
    }

    /// Create sample buffer for interleaved Float32 data
    private func makeInterleavedBuffer(from pcmData: [Float], format: CMAudioFormatDescription, like template: CMSampleBuffer) -> CMSampleBuffer? {
        let dataSize = pcmData.count * MemoryLayout<Float>.size
        var blockBuffer: CMBlockBuffer?

        // Create block buffer
        let status = pcmData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> OSStatus in
            guard let baseAddress = ptr.baseAddress else { return -1 }
            return CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: dataSize,
                blockAllocator: kCFAllocatorDefault,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: dataSize,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
        }

        guard status == kCMBlockBufferNoErr, let block = blockBuffer else { return nil }

        // Copy data into block buffer
        _ = pcmData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> OSStatus in
            guard let baseAddress = ptr.baseAddress else { return -1 }
            return CMBlockBufferReplaceDataBytes(
                with: baseAddress,
                blockBuffer: block,
                offsetIntoDestination: 0,
                dataLength: dataSize
            )
        }

        // Create sample buffer
        var sampleBuffer: CMSampleBuffer?
        let numFrames = CMItemCount(pcmData.count / Int(CMAudioFormatDescriptionGetStreamBasicDescription(format)!.pointee.mChannelsPerFrame))
        let createStatus = CMAudioSampleBufferCreateWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: block,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleCount: numFrames,
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(template),
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard createStatus == noErr else {
            print("⚠️ SimpleMixer: Failed to create interleaved sample buffer: \(createStatus)")
            return nil
        }

        return sampleBuffer
    }

    private func forward(_ sampleBuffer: CMSampleBuffer) {
        encoder?.appendAudio(sampleBuffer)
    }

    // MARK: - Format Validation and Conversion Helpers

    /// Validate that audio format is supported
    private func validateAudioFormat(asbd: AudioStreamBasicDescription) -> Bool {
        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let isSigned = (asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0
        let bits = asbd.mBitsPerChannel

        // Check if format is supported
        if isFloat {
            // Support Float32 and Float64
            return bits == 32 || bits == 64
        } else if isSigned {
            // Support Int16 and Int32
            return bits == 16 || bits == 32
        }

        return false
    }

    /// Convert audio data to Float32 array
    /// Supports: Int16, Int32, Float32, Float64
    private func convertToFloat(
        data: UnsafeMutableRawPointer,
        byteSize: Int,
        isFloat: Bool,
        isSigned: Bool,
        bitsPerChannel: UInt32,
        channels: Int
    ) -> [Float]? {
        if isFloat {
            switch bitsPerChannel {
            case 32:
                // Float32 - direct copy
                let samples = data.assumingMemoryBound(to: Float.self)
                let count = byteSize / MemoryLayout<Float>.size
                return Array(UnsafeBufferPointer(start: samples, count: count))

            case 64:
                // Float64 - convert to Float32
                let samples = data.assumingMemoryBound(to: Double.self)
                let count = byteSize / MemoryLayout<Double>.size
                return (0..<count).map { Float(samples[$0]) }

            default:
                print("⚠️ SimpleMixer: Unsupported float bit depth: \(bitsPerChannel)")
                return nil
            }
        } else if isSigned {
            switch bitsPerChannel {
            case 16:
                // Int16 - normalize to -1.0 to 1.0
                let samples = data.assumingMemoryBound(to: Int16.self)
                let count = byteSize / MemoryLayout<Int16>.size
                return (0..<count).map { Float(samples[$0]) / Float(Int16.max) }

            case 32:
                // Int32 - normalize to -1.0 to 1.0
                let samples = data.assumingMemoryBound(to: Int32.self)
                let count = byteSize / MemoryLayout<Int32>.size
                return (0..<count).map { Float(samples[$0]) / Float(Int32.max) }

            default:
                print("⚠️ SimpleMixer: Unsupported integer bit depth: \(bitsPerChannel)")
                return nil
            }
        }

        print("⚠️ SimpleMixer: Unknown audio format (not float or signed int)")
        return nil
    }

    /// Helper to build interleaved Float32 format description (convenience)
    private static func makeInterleavedFloatFormat(sampleRate: Double, channels: Int) -> CMAudioFormatDescription? {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(MemoryLayout<Float>.size * channels),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(MemoryLayout<Float>.size * channels),
            mChannelsPerFrame: UInt32(channels),
            mBitsPerChannel: 32,
            mReserved: 0
        )

        var formatDesc: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDesc
        )

        if status != noErr {
            print("⚠️ SimpleMixer: Failed to create interleaved format: \(status)")
            return nil
        }
        return formatDesc
    }

    /// Build AVAudioPCMBuffer from CMSampleBuffer with matching format
    private func makePCMBuffer(from sampleBuffer: CMSampleBuffer, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        // Copy PCM data into AVAudioPCMBuffer
        var status: OSStatus = noErr
        status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: buffer.mutableAudioBufferList
        )

        if status != noErr {
            print("⚠️ SimpleMixer: Failed to copy PCM data into AVAudioPCMBuffer: \(status)")
            return nil
        }

        return buffer
    }

    /// Resample audio from one sample rate to another using linear interpolation
    private func resample(_ samples: [Float], fromRate: Double, toRate: Double, channels: Int) -> [Float] {
        guard channels > 0, fromRate > 0, toRate > 0, !samples.isEmpty else {
            print("⚠️ SimpleMixer: Invalid resample params - ch:\(channels) from:\(fromRate) to:\(toRate) samples:\(samples.count)")
            return samples
        }

        let ratio = toRate / fromRate
        let inputFrames = samples.count / channels
        let outputFrames = Int(Double(inputFrames) * ratio)
        let outputTotalSamples = outputFrames * channels

        print("🔄 SimpleMixer: Resample - input:\(inputFrames) frames → output:\(outputFrames) frames (ratio:\(String(format: "%.2f", ratio)))")

        var output = [Float](repeating: 0, count: outputTotalSamples)

        for outFrame in 0..<outputFrames {
            // Calculate source position
            let srcPos = Double(outFrame) / ratio
            let srcFrame = Int(srcPos)
            let frac = Float(srcPos - Double(srcFrame))

            // Clamp to valid range
            let frame1 = min(srcFrame, inputFrames - 1)
            let frame2 = min(srcFrame + 1, inputFrames - 1)

            // Interpolate each channel
            for ch in 0..<channels {
                let idx1 = frame1 * channels + ch
                let idx2 = frame2 * channels + ch

                let sample1 = samples[idx1]
                let sample2 = samples[idx2]

                output[outFrame * channels + ch] = sample1 * (1.0 - frac) + sample2 * frac
            }
        }

        return output
    }

}
