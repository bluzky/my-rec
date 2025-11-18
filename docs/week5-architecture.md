# Week 5: Backend Architecture Design

**Date:** November 18, 2025
**Phase:** Backend Integration
**Goal:** Design interfaces for screen recording backend services

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (Existing)                      │
│  - AppDelegate                                              │
│  - StatusBarController                                      │
│  - HomePageView                                             │
│  - PreviewDialogView                                        │
│  - RegionSelectionView                                      │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   RecordingManager                          │
│  - Central coordinator (state machine)                      │
│  - Published properties for UI binding                      │
│  - NotificationCenter integration                           │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌──────────────────────────┬──────────────────────────────────┐
│   ScreenCaptureEngine    │      VideoEncoder                │
│  - ScreenCaptureKit      │  - AVAssetWriter                 │
│  - Frame capture         │  - H.264 encoding                │
│  - CVPixelBuffer         │  - MP4 output                    │
└──────────────────────────┴──────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   FileManagerService                        │
│  - File naming (MyRecord-{timestamp}.mp4)                   │
│  - Save to ~/Movies/                                        │
│  - Metadata extraction                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. RecordingManager Interface

### Purpose
Central coordinator that manages the entire recording lifecycle and exposes state to UI components.

### Interface Definition

```swift
/// Central coordinator for screen recording
/// Manages state machine, coordinates capture/encoding, and notifies UI of changes
@MainActor
class RecordingManager: ObservableObject {

    // MARK: - Published Properties (for UI binding)

    /// Current recording state (idle, recording, paused)
    @Published private(set) var state: RecordingState = .idle

    /// Current recording duration in seconds
    @Published private(set) var duration: TimeInterval = 0

    /// Error state for UI display
    @Published private(set) var error: RecordingError?


    // MARK: - Dependencies (injected)

    private let captureEngine: ScreenCaptureEngine
    private let videoEncoder: VideoEncoder
    private let fileManager: FileManagerService
    private let settingsManager: SettingsManager


    // MARK: - Internal State

    private var recordingStartTime: Date?
    private var currentOutputURL: URL?
    private var durationTimer: Timer?
    private var frameCount: Int = 0


    // MARK: - Initialization

    init(
        captureEngine: ScreenCaptureEngine = ScreenCaptureEngine(),
        videoEncoder: VideoEncoder = VideoEncoder(),
        fileManager: FileManagerService = FileManagerService(),
        settingsManager: SettingsManager = .shared
    ) {
        self.captureEngine = captureEngine
        self.videoEncoder = videoEncoder
        self.fileManager = fileManager
        self.settingsManager = settingsManager
    }


    // MARK: - Public API

    /// Start recording with the specified capture region
    /// - Parameter region: Screen region to capture (in screen coordinates)
    /// - Throws: RecordingError if capture or encoding setup fails
    func startRecording(region: CGRect) async throws {
        guard state == .idle else {
            throw RecordingError.invalidState("Cannot start recording from \(state) state")
        }

        // Update state
        state = .recording
        recordingStartTime = Date()
        frameCount = 0

        // Generate output URL
        currentOutputURL = fileManager.generateRecordingURL()

        // Configure capture engine
        try await captureEngine.configure(
            region: region,
            resolution: settingsManager.resolution,
            frameRate: settingsManager.frameRate,
            showCursor: settingsManager.showCursor
        )

        // Configure video encoder
        try videoEncoder.startEncoding(
            outputURL: currentOutputURL!,
            resolution: settingsManager.resolution,
            frameRate: settingsManager.frameRate
        )

        // Set up frame handler
        captureEngine.onFrameCaptured = { [weak self] pixelBuffer, presentationTime in
            self?.handleCapturedFrame(pixelBuffer, at: presentationTime)
        }

        // Start capture
        try await captureEngine.startCapture()

        // Start duration timer
        startDurationTimer()

        // Notify UI
        NotificationCenter.default.post(name: .recordingDidStart, object: nil)
    }

    /// Stop recording and finalize the video file
    /// - Returns: VideoMetadata for the completed recording
    /// - Throws: RecordingError if encoding finalization fails
    func stopRecording() async throws -> VideoMetadata {
        guard state == .recording else {
            throw RecordingError.invalidState("Cannot stop recording from \(state) state")
        }

        // Update state
        state = .idle

        // Stop duration timer
        stopDurationTimer()

        // Stop capture
        await captureEngine.stopCapture()

        // Finalize encoding
        try await videoEncoder.finishEncoding()

        // Extract metadata
        guard let outputURL = currentOutputURL else {
            throw RecordingError.noOutputFile
        }

        let metadata = try fileManager.extractMetadata(from: outputURL)

        // Reset state
        currentOutputURL = nil
        duration = 0

        // Notify UI
        NotificationCenter.default.post(
            name: .recordingDidStop,
            object: metadata
        )

        return metadata
    }

    /// Pause the current recording (Week 7 implementation)
    func pauseRecording() throws {
        guard state == .recording else {
            throw RecordingError.invalidState("Cannot pause from \(state) state")
        }

        state = .paused
        stopDurationTimer()
        // TODO: Implement pause logic in Week 7

        NotificationCenter.default.post(name: .recordingDidPause, object: nil)
    }

    /// Resume a paused recording (Week 7 implementation)
    func resumeRecording() throws {
        guard state == .paused else {
            throw RecordingError.invalidState("Cannot resume from \(state) state")
        }

        state = .recording
        startDurationTimer()
        // TODO: Implement resume logic in Week 7

        NotificationCenter.default.post(name: .recordingDidResume, object: nil)
    }

    /// Cancel the current recording without saving
    func cancelRecording() async {
        guard state != .idle else { return }

        state = .idle
        stopDurationTimer()

        await captureEngine.stopCapture()
        videoEncoder.cancelEncoding()

        // Delete incomplete file
        if let url = currentOutputURL {
            try? fileManager.deleteFile(at: url)
        }

        currentOutputURL = nil
        duration = 0

        NotificationCenter.default.post(name: .recordingDidCancel, object: nil)
    }


    // MARK: - Private Methods

    private func handleCapturedFrame(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime) {
        // Encode frame
        videoEncoder.appendFrame(pixelBuffer, at: presentationTime)
        frameCount += 1
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.duration = Date().timeIntervalSince(startTime)
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}


// MARK: - RecordingError

enum RecordingError: LocalizedError {
    case invalidState(String)
    case permissionDenied
    case captureSetupFailed(Error)
    case encodingFailed(Error)
    case noOutputFile
    case fileSystemError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidState(let message):
            return message
        case .permissionDenied:
            return "Screen recording permission denied. Please enable in System Settings."
        case .captureSetupFailed(let error):
            return "Failed to set up screen capture: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode video: \(error.localizedDescription)"
        case .noOutputFile:
            return "No output file was created"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        }
    }
}
```

### Key Design Decisions

1. **@MainActor**: All RecordingManager operations run on main thread for UI safety
2. **@Published Properties**: Direct SwiftUI binding for reactive UI updates
3. **Dependency Injection**: Testable design with injected services
4. **NotificationCenter**: Backward-compatible with existing StatusBarController
5. **Async/Await**: Modern Swift concurrency for async operations
6. **Error Handling**: Comprehensive RecordingError enum with user-friendly messages

---

## 2. ScreenCaptureEngine Interface

### Purpose
Abstracts screen capture using ScreenCaptureKit (macOS 13+) with fallback to CGDisplayStream.

### Interface Definition

```swift
/// Handles screen capture using ScreenCaptureKit (macOS 13+)
/// Delivers CVPixelBuffer frames to a callback handler
actor ScreenCaptureEngine {

    // MARK: - Public Properties

    /// Callback for captured frames
    /// Called on a background thread - do NOT update UI directly
    var onFrameCaptured: ((CVPixelBuffer, CMTime) -> Void)?


    // MARK: - Private Properties

    private var stream: SCStream?
    private var streamOutput: CaptureStreamOutput?
    private var configuration: SCStreamConfiguration?
    private var filter: SCContentFilter?

    private var captureRegion: CGRect = .zero
    private var isCapturing: Bool = false
    private var frameStartTime: CMTime?


    // MARK: - Configuration

    /// Configure the capture engine with recording settings
    /// - Parameters:
    ///   - region: Screen region to capture (in screen coordinates)
    ///   - resolution: Target resolution for encoding
    ///   - frameRate: Target frame rate
    ///   - showCursor: Whether to capture the cursor
    func configure(
        region: CGRect,
        resolution: Resolution,
        frameRate: FrameRate,
        showCursor: Bool
    ) async throws {
        guard !isCapturing else {
            throw CaptureError.alreadyCapturing
        }

        self.captureRegion = region

        // Check for ScreenCaptureKit availability (macOS 13+)
        guard #available(macOS 13.0, *) else {
            throw CaptureError.unsupportedOS("ScreenCaptureKit requires macOS 13.0 or later")
        }

        // Check screen recording permission
        let hasPermission = await checkScreenRecordingPermission()
        guard hasPermission else {
            throw CaptureError.permissionDenied
        }

        // Create stream configuration
        let config = SCStreamConfiguration()
        config.width = resolution.width
        config.height = resolution.height
        config.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(frameRate.value)
        )
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = showCursor
        config.queueDepth = 5

        self.configuration = config

        // Create content filter for the specified region
        // For Week 5: capture entire display, ignore region (implement region in Week 6)
        let displays = try await SCShareableContent.current.displays
        guard let display = displays.first else {
            throw CaptureError.noDisplayFound
        }

        self.filter = SCContentFilter(display: display, excludingWindows: [])
    }


    // MARK: - Capture Control

    /// Start capturing frames
    func startCapture() async throws {
        guard let configuration = configuration, let filter = filter else {
            throw CaptureError.notConfigured
        }

        guard !isCapturing else {
            throw CaptureError.alreadyCapturing
        }

        // Create stream output handler
        let output = CaptureStreamOutput()
        output.onFrameCaptured = { [weak self] sampleBuffer, type in
            guard let self = self else { return }

            Task {
                await self.handleSampleBuffer(sampleBuffer, type: type)
            }
        }
        self.streamOutput = output

        // Create and start stream
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))

        self.stream = stream
        self.isCapturing = true
        self.frameStartTime = CMTime.zero

        try await stream.startCapture()
    }

    /// Stop capturing frames
    func stopCapture() async {
        guard isCapturing else { return }

        if let stream = stream {
            try? await stream.stopCapture()
        }

        stream = nil
        streamOutput = nil
        isCapturing = false
        frameStartTime = nil
    }


    // MARK: - Private Methods

    private func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer, type: SCStreamOutputType) {
        guard type == .screen else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("⚠️ Failed to get pixel buffer from sample buffer")
            return
        }

        // Get presentation timestamp
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Normalize timestamp (start from zero)
        if frameStartTime == nil || frameStartTime == .zero {
            frameStartTime = presentationTime
        }

        let normalizedTime = CMTimeSubtract(presentationTime, frameStartTime!)

        // Deliver frame to callback
        onFrameCaptured?(pixelBuffer, normalizedTime)
    }

    private func checkScreenRecordingPermission() async -> Bool {
        // Check if screen recording is allowed
        // For macOS 13+, ScreenCaptureKit will prompt automatically
        return true
    }
}


// MARK: - CaptureStreamOutput

/// SCStreamOutput implementation for receiving captured frames
@available(macOS 13.0, *)
private class CaptureStreamOutput: NSObject, SCStreamOutput {

    var onFrameCaptured: ((CMSampleBuffer, SCStreamOutputType) -> Void)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        onFrameCaptured?(sampleBuffer, type)
    }
}


// MARK: - CaptureError

enum CaptureError: LocalizedError {
    case unsupportedOS(String)
    case permissionDenied
    case notConfigured
    case alreadyCapturing
    case noDisplayFound
    case streamCreationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedOS(let message):
            return message
        case .permissionDenied:
            return "Screen recording permission denied"
        case .notConfigured:
            return "Capture engine not configured. Call configure() first."
        case .alreadyCapturing:
            return "Already capturing"
        case .noDisplayFound:
            return "No display found for capture"
        case .streamCreationFailed(let error):
            return "Failed to create capture stream: \(error.localizedDescription)"
        }
    }
}
```

### Key Design Decisions

1. **Actor Isolation**: Thread-safe access to capture state
2. **Callback Pattern**: Frame delivery via closure (performance)
3. **macOS 13+ Only**: Week 5 uses ScreenCaptureKit (fallback in Week 7)
4. **CMTime Management**: Normalized timestamps starting from zero
5. **SCStreamOutput**: Separate class for handling stream callbacks
6. **Error Handling**: Comprehensive error cases

---

## 3. VideoEncoder Interface

### Purpose
Encodes CVPixelBuffer frames to H.264/MP4 using AVAssetWriter.

### Interface Definition

```swift
/// Encodes video frames to H.264/MP4 using AVAssetWriter
actor VideoEncoder {

    // MARK: - Private Properties

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var outputURL: URL?
    private var resolution: Resolution?
    private var frameRate: FrameRate?
    private var isEncoding: Bool = false
    private var frameCount: Int = 0


    // MARK: - Public API

    /// Start encoding session with output configuration
    /// - Parameters:
    ///   - outputURL: File URL for MP4 output
    ///   - resolution: Video resolution
    ///   - frameRate: Video frame rate
    /// - Throws: EncodingError if setup fails
    func startEncoding(
        outputURL: URL,
        resolution: Resolution,
        frameRate: FrameRate
    ) throws {
        guard !isEncoding else {
            throw EncodingError.alreadyEncoding
        }

        self.outputURL = outputURL
        self.resolution = resolution
        self.frameRate = frameRate

        // Create asset writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Create video input
        let videoSettings = createVideoSettings(resolution: resolution, frameRate: frameRate)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true

        // Create pixel buffer adaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: resolution.width,
            kCVPixelBufferHeightKey as String: resolution.height
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        // Add input to writer
        guard writer.canAdd(input) else {
            throw EncodingError.cannotAddInput
        }
        writer.add(input)

        // Start writing session
        guard writer.startWriting() else {
            throw EncodingError.failedToStartWriting(writer.error)
        }
        writer.startSession(atSourceTime: .zero)

        self.assetWriter = writer
        self.videoInput = input
        self.pixelBufferAdaptor = adaptor
        self.isEncoding = true
        self.frameCount = 0
    }

    /// Append a video frame to the encoding session
    /// - Parameters:
    ///   - pixelBuffer: The frame to encode
    ///   - presentationTime: Frame timestamp
    func appendFrame(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime) {
        guard isEncoding else {
            print("⚠️ Attempted to append frame when not encoding")
            return
        }

        guard let videoInput = videoInput,
              let adaptor = pixelBufferAdaptor else {
            print("⚠️ Video input or adaptor not initialized")
            return
        }

        // Wait for input to be ready
        guard videoInput.isReadyForMoreMediaData else {
            print("⚠️ Video input not ready for more data, dropping frame")
            return
        }

        // Append frame
        let success = adaptor.append(pixelBuffer, withPresentationTime: presentationTime)

        if success {
            frameCount += 1
        } else {
            print("⚠️ Failed to append frame at time \(presentationTime.seconds)")
        }
    }

    /// Finish encoding and finalize the video file
    /// - Throws: EncodingError if finalization fails
    func finishEncoding() async throws {
        guard isEncoding else {
            throw EncodingError.notEncoding
        }

        guard let writer = assetWriter,
              let input = videoInput else {
            throw EncodingError.notInitialized
        }

        // Mark input as finished
        input.markAsFinished()

        // Finish writing
        await writer.finishWriting()

        // Check for errors
        if writer.status == .failed {
            if let error = writer.error {
                throw EncodingError.writingFailed(error)
            } else {
                throw EncodingError.writingFailed(nil)
            }
        }

        // Clean up
        self.isEncoding = false
        self.assetWriter = nil
        self.videoInput = nil
        self.pixelBufferAdaptor = nil

        print("✅ Encoding finished successfully: \(frameCount) frames written")
    }

    /// Cancel encoding and delete the output file
    func cancelEncoding() {
        guard isEncoding else { return }

        assetWriter?.cancelWriting()

        // Delete incomplete file
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
        }

        self.isEncoding = false
        self.assetWriter = nil
        self.videoInput = nil
        self.pixelBufferAdaptor = nil
    }


    // MARK: - Private Methods

    private func createVideoSettings(resolution: Resolution, frameRate: FrameRate) -> [String: Any] {
        let bitrate = calculateBitrate(resolution: resolution, frameRate: frameRate)

        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: resolution.width,
            AVVideoHeightKey: resolution.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: frameRate.value * 2, // Keyframe every 2 seconds
                AVVideoAllowFrameReorderingKey: true,
                AVVideoExpectedSourceFrameRateKey: frameRate.value,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
            ]
        ]
    }

    private func calculateBitrate(resolution: Resolution, frameRate: FrameRate) -> Int {
        let baseRate: Int

        switch resolution {
        case .hd720p:   baseRate = 2_500_000  // 2.5 Mbps
        case .fullHD:   baseRate = 5_000_000  // 5 Mbps
        case .twoK:     baseRate = 8_000_000  // 8 Mbps
        case .fourK:    baseRate = 15_000_000 // 15 Mbps
        case .custom:   baseRate = 5_000_000  // Default
        }

        // Adjust for frame rate (60fps needs ~1.5x bitrate)
        let fpsMultiplier = Double(frameRate.value) / 30.0
        return Int(Double(baseRate) * fpsMultiplier)
    }
}


// MARK: - EncodingError

enum EncodingError: LocalizedError {
    case alreadyEncoding
    case notEncoding
    case notInitialized
    case cannotAddInput
    case failedToStartWriting(Error?)
    case writingFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .alreadyEncoding:
            return "Already encoding"
        case .notEncoding:
            return "Not currently encoding"
        case .notInitialized:
            return "Encoder not initialized"
        case .cannotAddInput:
            return "Cannot add video input to asset writer"
        case .failedToStartWriting(let error):
            return "Failed to start writing: \(error?.localizedDescription ?? "unknown error")"
        case .writingFailed(let error):
            return "Writing failed: \(error?.localizedDescription ?? "unknown error")"
        }
    }
}
```

### Key Design Decisions

1. **Actor Isolation**: Thread-safe encoding operations
2. **AVAssetWriter**: Native H.264 encoding with hardware acceleration
3. **Pixel Buffer Adaptor**: Direct CVPixelBuffer writing
4. **Real-time Encoding**: expectsMediaDataInRealTime = true
5. **Adaptive Bitrate**: Calculated based on resolution and frame rate
6. **Error Recovery**: Comprehensive error handling and cleanup

---

## 4. FileManagerService Interface

### Purpose
Handles file system operations for recordings (naming, saving, metadata extraction).

### Interface Definition

```swift
/// Handles file system operations for recordings
class FileManagerService {

    // MARK: - Properties

    private let settingsManager: SettingsManager
    private let fileManager = FileManager.default


    // MARK: - Initialization

    init(settingsManager: SettingsManager = .shared) {
        self.settingsManager = settingsManager
    }


    // MARK: - File Operations

    /// Generate a unique URL for a new recording
    /// - Returns: URL in format: ~/Movies/MyRecord-20251118143022.mp4
    func generateRecordingURL() -> URL {
        let timestamp = Date()
        let filename = formatFilename(for: timestamp)

        let saveDirectory = settingsManager.saveLocationURL
        ensureDirectoryExists(at: saveDirectory)

        return saveDirectory.appendingPathComponent(filename)
    }

    /// Extract metadata from a recorded video file
    /// - Parameter url: File URL of the recording
    /// - Returns: VideoMetadata object
    /// - Throws: FileError if metadata extraction fails
    func extractMetadata(from url: URL) throws -> VideoMetadata {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileError.fileNotFound(url)
        }

        let asset = AVAsset(url: url)

        // Extract duration
        let duration = try await asset.load(.duration).seconds

        // Extract video track info
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw FileError.noVideoTrack(url)
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)

        // Get file size
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Get creation date
        let creationDate = attributes[.creationDate] as? Date ?? Date()

        // Determine resolution
        let resolution = Resolution.fromDimensions(
            width: Int(naturalSize.width),
            height: Int(naturalSize.height)
        ) ?? .fullHD

        // Determine frame rate
        let frameRate = FrameRate.fromValue(Int(nominalFrameRate)) ?? .fps30

        return VideoMetadata(
            fileURL: url,
            filename: url.lastPathComponent,
            duration: duration,
            fileSize: fileSize,
            resolution: resolution,
            frameRate: frameRate,
            createdDate: creationDate
        )
    }

    /// Delete a recording file
    /// - Parameter url: File URL to delete
    /// - Throws: FileError if deletion fails
    func deleteFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileError.fileNotFound(url)
        }

        try fileManager.removeItem(at: url)
    }

    /// Get all recordings from the save directory
    /// - Returns: Array of VideoMetadata sorted by creation date (newest first)
    func getAllRecordings() throws -> [VideoMetadata] {
        let saveDirectory = settingsManager.saveLocationURL

        guard fileManager.fileExists(atPath: saveDirectory.path) else {
            return []
        }

        let files = try fileManager.contentsOfDirectory(
            at: saveDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )

        // Filter for MP4 files starting with "MyRecord-"
        let recordingFiles = files.filter { url in
            url.pathExtension == "mp4" && url.lastPathComponent.hasPrefix("MyRecord-")
        }

        // Extract metadata for each file
        let recordings = recordingFiles.compactMap { url -> VideoMetadata? in
            try? extractMetadata(from: url)
        }

        // Sort by creation date (newest first)
        return recordings.sorted { $0.createdDate > $1.createdDate }
    }


    // MARK: - Private Methods

    private func formatFilename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        let timestamp = formatter.string(from: date)
        return "MyRecord-\(timestamp).mp4"
    }

    private func ensureDirectoryExists(at url: URL) {
        guard !fileManager.fileExists(atPath: url.path) else { return }

        try? fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}


// MARK: - FileError

enum FileError: LocalizedError {
    case fileNotFound(URL)
    case noVideoTrack(URL)
    case metadataExtractionFailed(Error)
    case deletionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .noVideoTrack(let url):
            return "No video track found in: \(url.lastPathComponent)"
        case .metadataExtractionFailed(let error):
            return "Failed to extract metadata: \(error.localizedDescription)"
        case .deletionFailed(let error):
            return "Failed to delete file: \(error.localizedDescription)"
        }
    }
}
```

### Key Design Decisions

1. **Synchronous API**: File operations are fast enough for main thread
2. **Filename Convention**: MyRecord-{YYYYMMDDHHMMSS}.mp4
3. **Metadata Extraction**: Uses AVAsset for accurate video info
4. **Directory Management**: Auto-creates save directory if missing
5. **Error Handling**: Comprehensive file system error cases

---

## 5. Notification Flow

### New Notifications

```swift
extension Notification.Name {
    // Recording lifecycle
    static let recordingDidStart = Notification.Name("recordingDidStart")
    static let recordingDidStop = Notification.Name("recordingDidStop")
    static let recordingDidPause = Notification.Name("recordingDidPause")
    static let recordingDidResume = Notification.Name("recordingDidResume")
    static let recordingDidCancel = Notification.Name("recordingDidCancel")

    // Recording updates
    static let recordingDurationUpdated = Notification.Name("recordingDurationUpdated")

    // Errors
    static let recordingDidFail = Notification.Name("recordingDidFail")
}
```

### Notification Flow Diagram

```
User Action (UI)
    ↓
RecordingManager.startRecording()
    ↓
[ScreenCaptureKit] → [VideoEncoder]
    ↓
Post .recordingDidStart
    ↓
StatusBarController receives notification
    ↓
Update menu items (show timer, pause/stop buttons)
    ↓
Timer ticks...
    ↓
RecordingManager.stopRecording()
    ↓
Post .recordingDidStop (with VideoMetadata)
    ↓
StatusBarController + AppDelegate receive notification
    ↓
Open PreviewDialogView with VideoMetadata
```

---

## 6. Data Flow

### Recording Flow

```
1. User clicks "Record Screen"
   ↓
2. RegionSelectionView captures region
   ↓
3. AppDelegate calls RecordingManager.startRecording(region)
   ↓
4. RecordingManager configures ScreenCaptureEngine + VideoEncoder
   ↓
5. ScreenCaptureEngine starts capturing frames
   ↓
6. Frames delivered via callback → RecordingManager
   ↓
7. RecordingManager forwards frames to VideoEncoder
   ↓
8. VideoEncoder writes frames to MP4 file
   ↓
9. Timer updates duration (UI binding via @Published)
   ↓
10. User clicks "Stop"
    ↓
11. RecordingManager.stopRecording()
    ↓
12. ScreenCaptureEngine stops capture
    ↓
13. VideoEncoder finalizes MP4 file
    ↓
14. FileManagerService extracts metadata
    ↓
15. Return VideoMetadata to UI
    ↓
16. Open PreviewDialogView with real video
```

---

## 7. Testing Strategy

### Unit Tests

**RecordingManagerTests:**
- ✅ Test state transitions (idle → recording → idle)
- ✅ Test duration tracking accuracy
- ✅ Test error handling (invalid state, permissions)
- ✅ Test notification posting

**ScreenCaptureEngineTests:**
- ✅ Test configuration with different resolutions
- ✅ Test frame delivery callback
- ✅ Test start/stop lifecycle
- ✅ Test permission checking

**VideoEncoderTests:**
- ✅ Test encoding with synthetic frames
- ✅ Test bitrate calculation
- ✅ Test file creation
- ✅ Test cancellation

**FileManagerServiceTests:**
- ✅ Test filename generation
- ✅ Test metadata extraction
- ✅ Test file operations
- ✅ Test directory creation

### Integration Tests

- ✅ End-to-end recording (5 seconds)
- ✅ Verify MP4 file is playable
- ✅ Verify metadata accuracy
- ✅ Test multiple consecutive recordings

---

## Implementation Order (Week 5)

### Day 20: ScreenCaptureEngine
1. Create ScreenCaptureEngine.swift
2. Implement configure() and startCapture()
3. Test with simple frame logging
4. Verify CVPixelBuffer format

### Day 21: VideoEncoder
1. Create VideoEncoder.swift
2. Implement AVAssetWriter setup
3. Test with synthetic frames
4. Verify MP4 output

### Day 22: RecordingManager + FileManagerService
1. Create RecordingManager.swift
2. Create FileManagerService.swift
3. Wire up all components
4. Integration test (full flow)

### Day 23: UI Integration
1. Update AppDelegate to use RecordingManager
2. Update StatusBarController for notifications
3. Wire PreviewDialogView to AVPlayer
4. Update HomePageView to load real recordings
5. End-to-end testing

---

## Success Criteria

By end of Week 5:
- ✅ Can record 5-second screen capture
- ✅ MP4 file saves to ~/Movies/
- ✅ File is playable in QuickTime Player
- ✅ Duration and metadata are accurate
- ✅ UI shows real recording in preview
- ✅ All tests passing
- ✅ Clean build with no warnings

---

**Status:** Architecture design complete ✅
**Next:** Implement ScreenCaptureEngine (Day 20)
