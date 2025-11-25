# Camera-in-Video: Phased Implementation Plan

**Project:** MyRec - macOS Screen Recording Application
**Strategy:** Incremental implementation without breaking existing features
**Date:** 2025-11-25
**Version:** 1.0

---

## Table of Contents
1. [Overview](#overview)
2. [Phase 1: Foundation & Permissions](#phase-1-foundation--permissions)
3. [Phase 2: Basic Camera Capture](#phase-2-basic-camera-capture)
4. [Phase 3: Dual-Mode Architecture](#phase-3-dual-mode-architecture)
5. [Phase 4: Manual Composition Pipeline](#phase-4-manual-composition-pipeline)
6. [Phase 5: UI Integration & Draggable Overlay](#phase-5-ui-integration--draggable-overlay)
7. [Phase 6: Optimization & Polish](#phase-6-optimization--polish)
8. [Testing Strategy](#testing-strategy)
9. [Rollback Plan](#rollback-plan)

---

## Overview

### Current State
- **ScreenCaptureEngine**: ~383 lines using `SCRecordingOutput` (native, simple)
- **Recording**: Screen + System Audio + Microphone
- **Settings**: `cameraEnabled` flag exists but not implemented
- **macOS Target**: 15.0+ (currently using HEVC encoding)

### Implementation Strategy

**Key Principle:** Each phase is independently testable and doesn't break existing functionality.

```
Phase 1: Foundation (Week 1)          → Add camera permissions, no recording changes
Phase 2: Basic Camera (Week 2)        → Capture camera independently, test separately
Phase 3: Dual-Mode (Week 3)           → Run both pipelines side-by-side (feature flag)
Phase 4: Composition (Weeks 4-5)      → Build manual pipeline with composition
Phase 5: UI Integration (Week 6)      → Add draggable overlay, position control
Phase 6: Optimization (Week 7)        → Performance tuning, bug fixes, launch
```

### Success Criteria by Phase
| Phase | Test Criteria | Rollback Trigger |
|-------|--------------|------------------|
| 1 | Camera permission dialog works | Permission crashes app |
| 2 | Camera records to separate file | Camera capture fails |
| 3 | Both modes record successfully | Either mode degrades quality |
| 4 | Composition produces valid MP4 | A/V sync > 100ms drift |
| 5 | Overlay drag updates position | UI freezes during recording |
| 6 | CPU < 30%, Memory < 300MB | Performance targets missed |

---

## Phase 1: Foundation & Permissions
**Duration:** 3-4 days
**Goal:** Add camera infrastructure without touching recording pipeline
**Risk:** Low ⚠️

### 1.1 Update Info.plist
**File:** `Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>MyRec needs camera access to overlay your webcam in screen recordings.</string>
```

**Test:** Build succeeds, no runtime impact.

---

### 1.2 Create Camera Permission Manager
**New File:** `MyRec/Services/Permissions/CameraPermissionManager.swift`

```swift
import AVFoundation

@available(macOS 15.0, *)
public class CameraPermissionManager {

    public enum CameraPermissionStatus {
        case notDetermined
        case granted
        case denied
    }

    /// Check current camera permission status
    public static func checkPermission() -> CameraPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    /// Request camera permission
    public static func requestPermission() async -> Bool {
        return await AVCaptureDevice.requestAccess(for: .video)
    }

    /// Get list of available cameras
    public static func getAvailableCameras() -> [AVCaptureDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices
    }
}
```

**Test:**
```bash
swift test --filter CameraPermissionManagerTests
```

---

### 1.3 Add Permission UI Flow
**File:** `MyRec/AppDelegate.swift` (or wherever settings are triggered)

Add check when user toggles camera:
```swift
func handleCameraToggle() async {
    let status = CameraPermissionManager.checkPermission()

    switch status {
    case .notDetermined:
        let granted = await CameraPermissionManager.requestPermission()
        if !granted {
            showCameraPermissionDeniedAlert()
        }
    case .denied:
        showCameraPermissionDeniedAlert()
    case .granted:
        // Proceed with camera enablement
        break
    }
}

func showCameraPermissionDeniedAlert() {
    let alert = NSAlert()
    alert.messageText = "Camera Access Required"
    alert.informativeText = "Please enable camera access in System Settings > Privacy & Security > Camera"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Open Settings")
    alert.addButton(withTitle: "Cancel")

    if alert.runModal() == .alertFirstButtonReturn {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
    }
}
```

**Test:**
- Toggle camera in settings
- Verify permission dialog appears (first time)
- Verify alert appears if denied

---

### 1.4 Phase 1 Deliverables
- ✅ Camera permission infrastructure in place
- ✅ UI handles permission flow gracefully
- ✅ No changes to ScreenCaptureEngine
- ✅ All existing tests pass

**Manual Test:**
```bash
# Build and run app
./scripts/build.sh Debug

# Toggle camera setting → Permission dialog appears
# Deny permission → Alert shows with "Open Settings" button
# Grant permission → Setting enables without error
```

---

## Phase 2: Basic Camera Capture
**Duration:** 4-5 days
**Goal:** Capture camera to separate file (no composition yet)
**Risk:** Low ⚠️

### 2.1 Create Camera Capture Service
**New File:** `MyRec/Services/Recording/CameraCaptureEngine.swift`

```swift
import AVFoundation
import Combine

@available(macOS 15.0, *)
public class CameraCaptureEngine: NSObject, ObservableObject {
    // MARK: - Properties
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentDevice: AVCaptureDevice?
    private var outputURL: URL?

    @Published public var isCapturing = false
    @Published public var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Callbacks
    var onRecordingStarted: (() -> Void)?
    var onRecordingFinished: ((URL) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Public Interface

    /// Setup camera session for preview
    public func setupPreview() throws {
        guard let camera = CameraPermissionManager.getAvailableCameras().first else {
            throw CameraError.noDeviceAvailable
        }

        currentDevice = camera
        captureSession = AVCaptureSession()

        // Add input
        let input = try AVCaptureDeviceInput(device: camera)
        guard let session = captureSession, session.canAddInput(input) else {
            throw CameraError.configurationFailed
        }
        session.addInput(input)

        // Create preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill

        print("✅ CameraCaptureEngine: Preview setup complete")
    }

    /// Start camera preview
    public func startPreview() {
        guard let session = captureSession, !session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            print("✅ CameraCaptureEngine: Preview started")
        }
    }

    /// Stop camera preview
    public func stopPreview() {
        guard let session = captureSession, session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
            print("✅ CameraCaptureEngine: Preview stopped")
        }
    }

    /// Start recording camera to file
    public func startRecording(to url: URL) throws {
        guard let session = captureSession else {
            throw CameraError.configurationFailed
        }

        // Add movie file output if not already added
        if videoOutput == nil {
            let output = AVCaptureMovieFileOutput()
            guard session.canAddOutput(output) else {
                throw CameraError.configurationFailed
            }
            session.addOutput(output)
            videoOutput = output
        }

        guard let output = videoOutput else {
            throw CameraError.configurationFailed
        }

        outputURL = url
        output.startRecording(to: url, recordingDelegate: self)
        isCapturing = true

        print("✅ CameraCaptureEngine: Recording started to \(url.lastPathComponent)")
    }

    /// Stop recording camera
    public func stopRecording() {
        guard let output = videoOutput, output.isRecording else { return }

        output.stopRecording()
        print("🔄 CameraCaptureEngine: Stopping recording...")
    }

    /// Cleanup resources
    public func cleanup() {
        stopPreview()
        captureSession = nil
        videoOutput = nil
        currentDevice = nil
        previewLayer = nil
        print("✅ CameraCaptureEngine: Cleanup complete")
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraCaptureEngine: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        isCapturing = false

        if let error = error {
            print("❌ CameraCaptureEngine: Recording failed - \(error)")
            onError?(error)
            return
        }

        print("✅ CameraCaptureEngine: Recording finished - \(outputFileURL.lastPathComponent)")
        onRecordingFinished?(outputFileURL)
    }
}

// MARK: - Errors

enum CameraError: LocalizedError {
    case noDeviceAvailable
    case configurationFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noDeviceAvailable:
            return "No camera device available"
        case .configurationFailed:
            return "Failed to configure camera"
        case .permissionDenied:
            return "Camera permission denied"
        }
    }
}
```

**Test:**
```bash
swift test --filter CameraCaptureEngineTests
```

---

### 2.2 Test Camera Recording Separately
**File:** `MyRecTests/Services/CameraCaptureEngineTests.swift`

```swift
import XCTest
@testable import MyRec
import AVFoundation

@available(macOS 15.0, *)
final class CameraCaptureEngineTests: XCTestCase {
    var engine: CameraCaptureEngine!

    override func setUp() {
        super.setUp()
        engine = CameraCaptureEngine()
    }

    override func tearDown() {
        engine.cleanup()
        engine = nil
        super.tearDown()
    }

    func testPreviewSetup() throws {
        // This will fail if no camera available - expected
        do {
            try engine.setupPreview()
            XCTAssertNotNil(engine.previewLayer)
        } catch CameraError.noDeviceAvailable {
            XCTSkip("No camera available for testing")
        }
    }

    func testRecordingFlow() throws {
        // Skip if no camera
        guard !CameraPermissionManager.getAvailableCameras().isEmpty else {
            throw XCTSkip("No camera available")
        }

        try engine.setupPreview()

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-camera-\(UUID().uuidString).mov")

        let expectation = self.expectation(description: "Camera recording completes")

        engine.onRecordingFinished = { url in
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            expectation.fulfill()
        }

        try engine.startRecording(to: outputURL)

        // Record for 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.engine.stopRecording()
        }

        wait(for: [expectation], timeout: 5)
    }
}
```

---

### 2.3 Phase 2 Deliverables
- ✅ Camera captures to separate file successfully
- ✅ Preview layer works for UI integration
- ✅ Independent of ScreenCaptureEngine
- ✅ Tests validate camera-only recording

**Manual Test:**
```bash
# Run camera-only test
swift test --filter CameraCaptureEngineTests/testRecordingFlow

# Verify: ~/Library/Developer/.../test-camera-*.mov exists and plays
```

---

## Phase 3: Dual-Mode Architecture
**Duration:** 5-6 days
**Goal:** Run both capture engines in parallel (feature flag)
**Risk:** Medium ⚠️⚠️

### 3.1 Add Feature Flag
**File:** `MyRec/Models/RecordingSettings.swift`

```swift
struct RecordingSettings: Codable, Equatable {
    var resolution: Resolution
    var frameRate: FrameRate
    var audioEnabled: Bool
    var microphoneEnabled: Bool
    var cameraEnabled: Bool
    var cursorEnabled: Bool

    // NEW: Composition mode flag
    var useManualComposition: Bool  // false = SCRecordingOutput, true = Manual pipeline

    static let `default` = RecordingSettings(
        resolution: .fullHD,
        frameRate: .fps30,
        audioEnabled: true,
        microphoneEnabled: false,
        cameraEnabled: false,
        cursorEnabled: true,
        useManualComposition: false  // Default to existing pipeline
    )
}
```

---

### 3.2 Update ScreenCaptureEngine for Dual-Mode
**File:** `MyRec/Services/Recording/ScreenCaptureEngine.swift`

Add camera engine integration:
```swift
@available(macOS 15.0, *)
public class ScreenCaptureEngine: NSObject, SCStreamDelegate, SCRecordingOutputDelegate, ObservableObject {
    // ... existing properties ...

    // NEW: Camera integration (Phase 3)
    private var cameraEngine: CameraCaptureEngine?
    private var cameraOutputURL: URL?

    // ... existing methods ...

    public func startCapture(
        region: CGRect,
        resolution: Resolution,
        frameRate: FrameRate,
        withAudio: Bool = true,
        withMicrophone: Bool = false,
        withCamera: Bool = false  // NEW parameter
    ) async throws {
        guard !isCapturing else { return }

        self.captureRegion = region
        self.recordingStartTime = Date()
        self.captureAudio = withAudio
        self.captureMicrophone = withMicrophone

        // Create output file URL
        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).mp4")

        // NEW: Setup camera if enabled
        if withCamera {
            try setupCameraCapture()
        }

        // ... existing stream setup ...

        try await stream.startCapture()

        // NEW: Start camera recording if enabled
        if withCamera, let cameraURL = cameraOutputURL {
            try cameraEngine?.startRecording(to: cameraURL)
            print("✅ Camera recording started alongside screen")
        }

        isCapturing = true
        onRecordingStarted?()
        print("✅ ScreenCaptureEngine: Capture started (camera: \(withCamera))")
    }

    // NEW: Setup camera capture
    private func setupCameraCapture() throws {
        cameraEngine = CameraCaptureEngine()
        try cameraEngine?.setupPreview()

        cameraOutputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("camera-\(UUID().uuidString).mov")

        print("✅ Camera capture configured")
    }

    public func stopCapture() async throws -> URL {
        // ... existing stop logic ...

        // NEW: Stop camera if running
        if let camera = cameraEngine {
            camera.stopRecording()
            print("✅ Camera recording stopped")
        }

        // ... continue existing logic ...

        // Cleanup camera
        cameraEngine?.cleanup()
        cameraEngine = nil
        cameraOutputURL = nil

        return result
    }
}
```

---

### 3.3 Phase 3 Deliverables
- ✅ Both engines run simultaneously without interference
- ✅ Feature flag allows toggling between modes
- ✅ Screen recording quality unchanged
- ✅ Camera records to separate file during screen recording

**Manual Test:**
```bash
# Record with camera enabled
# Expected output:
# - recording-*.mp4 (screen + audio)
# - camera-*.mov (camera only)
# Both files should have same duration (±100ms)
```

---

## Phase 4: Manual Composition Pipeline
**Duration:** 7-10 days
**Goal:** Build SCStreamOutput + AVAssetWriter pipeline with composition
**Risk:** High ⚠️⚠️⚠️

### 4.1 Create Composition Engine
**New File:** `MyRec/Services/Recording/VideoCompositor.swift`

```swift
import CoreImage
import CoreVideo
import AVFoundation

@available(macOS 15.0, *)
public class VideoCompositor {
    private let context: CIContext
    private var overlayRect: CGRect

    public init(overlayRect: CGRect = CGRect(x: 20, y: 20, width: 200, height: 150)) {
        self.context = CIContext(options: [
            .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
            .useSoftwareRenderer: false  // Use GPU
        ])
        self.overlayRect = overlayRect
    }

    /// Update overlay position (call from UI drag handler)
    public func updateOverlayPosition(_ rect: CGRect) {
        overlayRect = rect
    }

    /// Composite camera onto screen buffer
    public func composite(
        screen: CVPixelBuffer,
        camera: CVPixelBuffer,
        outputBuffer: CVPixelBuffer
    ) -> Bool {
        let screenImage = CIImage(cvPixelBuffer: screen)
        let cameraImage = CIImage(cvPixelBuffer: camera)

        // Calculate scale to fit overlay rect
        let cameraWidth = cameraImage.extent.width
        let cameraHeight = cameraImage.extent.height
        let scaleX = overlayRect.width / cameraWidth
        let scaleY = overlayRect.height / cameraHeight

        // Scale and position camera
        let scaledCamera = cameraImage
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(
                translationX: overlayRect.origin.x,
                y: overlayRect.origin.y
            ))

        // Composite camera over screen
        let composited = scaledCamera.composited(over: screenImage)

        // Render to output buffer
        context.render(composited, to: outputBuffer)

        return true
    }
}
```

---

### 4.2 Create Manual Recording Engine
**New File:** `MyRec/Services/Recording/ManualRecordingEngine.swift`

This is a parallel implementation to ScreenCaptureEngine but uses SCStreamOutput:

```swift
import ScreenCaptureKit
import AVFoundation
import CoreMedia

@available(macOS 15.0, *)
public class ManualRecordingEngine: NSObject, SCStreamDelegate, SCStreamOutput, ObservableObject {
    // MARK: - Properties
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?

    private var captureRegion: CGRect = .zero
    private var isCapturing = false
    private var recordingStartTime: Date?
    private var outputURL: URL?

    // Camera integration
    private var cameraSession: AVCaptureSession?
    private var cameraOutput: AVCaptureVideoDataOutput?
    private var latestCameraBuffer: CVPixelBuffer?
    private let cameraQueue = DispatchQueue(label: "cameraQueue")

    // Composition
    private var compositor: VideoCompositor?

    // Audio settings
    private var captureAudio: Bool = false
    private var captureMicrophone: Bool = false

    // Callbacks
    var onRecordingStarted: (() -> Void)?
    var onRecordingFinished: ((TimeInterval, URL) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Public Interface

    public func startCapture(
        region: CGRect,
        resolution: Resolution,
        frameRate: FrameRate,
        withAudio: Bool = true,
        withMicrophone: Bool = false,
        withCamera: Bool = false,
        overlayRect: CGRect = CGRect(x: 20, y: 20, width: 200, height: 150)
    ) async throws {
        guard !isCapturing else { return }

        self.captureRegion = region
        self.recordingStartTime = Date()
        self.captureAudio = withAudio
        self.captureMicrophone = withMicrophone

        // Setup output file
        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-manual-\(UUID().uuidString).mp4")

        guard let outputURL = outputURL else {
            throw CaptureError.configurationFailed
        }

        // Setup compositor if camera enabled
        if withCamera {
            compositor = VideoCompositor(overlayRect: overlayRect)
            try setupCamera()
        }

        // Setup stream
        let streamSetup = try await setupStream(resolution: resolution, frameRate: frameRate)
        stream = streamSetup.stream

        // Setup AVAssetWriter
        try setupAssetWriter(
            outputURL: outputURL,
            videoSize: streamSetup.outputSize,
            frameRate: frameRate
        )

        // Add stream outputs for manual processing
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "screenQueue"))

        if captureAudio || captureMicrophone {
            try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "audioQueue"))
        }

        // Start camera session if enabled
        if withCamera {
            cameraSession?.startRunning()
        }

        // Start stream
        try await stream?.startCapture()

        isCapturing = true
        onRecordingStarted?()
        print("✅ ManualRecordingEngine: Capture started (camera: \(withCamera))")
    }

    public func stopCapture() async throws -> URL {
        guard isCapturing else { throw CaptureError.notCapturing }

        isCapturing = false

        // Stop camera
        cameraSession?.stopRunning()

        // Stop stream
        try await stream?.stopCapture()

        // Finalize asset writer
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await assetWriter?.finishWriting()

        guard let outputURL = outputURL else {
            throw CaptureError.configurationFailed
        }

        // Verify file
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw CaptureError.configurationFailed
        }

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        // Cleanup
        cleanup()

        onRecordingFinished?(duration, outputURL)
        return outputURL
    }

    // MARK: - SCStreamOutput

    public func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        switch type {
        case .screen:
            handleScreenSample(sampleBuffer)
        case .audio:
            handleAudioSample(sampleBuffer)
        @unknown default:
            break
        }
    }

    // MARK: - Private Methods

    private func setupCamera() throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CameraError.noDeviceAvailable
        }

        cameraSession = AVCaptureSession()
        cameraSession?.sessionPreset = .hd1920x1080

        let input = try AVCaptureDeviceInput(device: device)
        guard let session = cameraSession, session.canAddInput(input) else {
            throw CameraError.configurationFailed
        }
        session.addInput(input)

        cameraOutput = AVCaptureVideoDataOutput()
        cameraOutput?.setSampleBufferDelegate(self, queue: cameraQueue)
        cameraOutput?.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        guard session.canAddOutput(cameraOutput!) else {
            throw CameraError.configurationFailed
        }
        session.addOutput(cameraOutput!)

        print("✅ Camera session configured")
    }

    private func setupAssetWriter(
        outputURL: URL,
        videoSize: (width: Int, height: Int),
        frameRate: FrameRate
    ) throws {
        assetWriter = try AVAssetWriter(url: outputURL, fileType: .mp4)

        // Video input settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: calculateBitrate(width: videoSize.width, height: videoSize.height),
                AVVideoExpectedSourceFrameRateKey: frameRate.value,
                AVVideoMaxKeyFrameIntervalKey: frameRate.value * 2
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        guard let writer = assetWriter, let input = videoInput, writer.canAdd(input) else {
            throw CaptureError.configurationFailed
        }
        writer.add(input)

        // Audio input settings (if enabled)
        if captureAudio || captureMicrophone {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]

            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true

            if let audioIn = audioInput, writer.canAdd(audioIn) {
                writer.add(audioIn)
            }
        }

        // Start writing
        guard writer.startWriting() else {
            throw CaptureError.configurationFailed
        }
        writer.startSession(atSourceTime: .zero)

        print("✅ AVAssetWriter configured - \(outputURL.lastPathComponent)")
    }

    private func handleScreenSample(_ sampleBuffer: CMSampleBuffer) {
        guard let videoInput = videoInput, videoInput.isReadyForMoreMediaData else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // If camera enabled, composite
        if let cameraBuffer = latestCameraBuffer, let compositor = compositor {
            // Create output buffer
            var outputBuffer: CVPixelBuffer?
            let attrs = [
                kCVPixelBufferWidthKey: CVPixelBufferGetWidth(imageBuffer),
                kCVPixelBufferHeightKey: CVPixelBufferGetHeight(imageBuffer),
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA
            ] as CFDictionary

            CVPixelBufferCreate(nil, CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer), kCVPixelFormatType_32BGRA, attrs, &outputBuffer)

            if let output = outputBuffer {
                if compositor.composite(screen: imageBuffer, camera: cameraBuffer, outputBuffer: output) {
                    // Create new sample buffer with composited frame
                    var compositedBuffer: CMSampleBuffer?
                    var timingInfo = CMSampleTimingInfo()
                    timingInfo.presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    timingInfo.duration = CMSampleBufferGetDuration(sampleBuffer)

                    CMSampleBufferCreateForImageBuffer(
                        allocator: kCFAllocatorDefault,
                        imageBuffer: output,
                        dataReady: true,
                        makeDataReadyCallback: nil,
                        refcon: nil,
                        formatDescription: CMSampleBufferGetFormatDescription(sampleBuffer)!,
                        sampleTiming: &timingInfo,
                        sampleBufferOut: &compositedBuffer
                    )

                    if let composited = compositedBuffer {
                        videoInput.append(composited)
                        return
                    }
                }
            }
        }

        // No composition - append screen buffer directly
        videoInput.append(sampleBuffer)
    }

    private func handleAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard let audioInput = audioInput, audioInput.isReadyForMoreMediaData else { return }
        audioInput.append(sampleBuffer)
    }

    private func calculateBitrate(width: Int, height: Int) -> Int {
        // Simple bitrate calculation
        let pixels = width * height
        if pixels >= 3840 * 2160 { return 15_000_000 }  // 4K
        if pixels >= 2560 * 1440 { return 8_000_000 }   // 2K
        if pixels >= 1920 * 1080 { return 5_000_000 }   // 1080p
        return 2_500_000  // 720p
    }

    private func setupStream(resolution: Resolution, frameRate: FrameRate) async throws -> (stream: SCStream, outputSize: (width: Int, height: Int)) {
        // Similar to ScreenCaptureEngine.setupStream
        // (Copy implementation from ScreenCaptureEngine.swift lines 285-356)
        // ... [truncated for brevity - would be full implementation]
        fatalError("Implement stream setup")
    }

    private func cleanup() {
        stream = nil
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        cameraSession = nil
        cameraOutput = nil
        latestCameraBuffer = nil
        compositor = nil
        outputURL = nil
        recordingStartTime = nil
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ManualRecordingEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        latestCameraBuffer = pixelBuffer
    }
}
```

---

### 4.3 Phase 4 Deliverables
- ✅ ManualRecordingEngine produces valid MP4 with screen + camera
- ✅ Audio/video sync within ±50ms
- ✅ Composition works correctly (camera overlay visible)
- ✅ Performance acceptable (CPU < 30%)

**Test:**
```bash
# Record using manual pipeline
# Verify:
# - Output file plays correctly
# - Camera overlay visible at correct position
# - Audio in sync with video
# - No frame drops or artifacts
```

---

## Phase 5: UI Integration & Draggable Overlay
**Duration:** 5-6 days
**Goal:** Add draggable camera preview in recording window
**Risk:** Medium ⚠️⚠️

### 5.1 Create Draggable Camera View
**New File:** `MyRec/Views/DraggableCameraView.swift`

```swift
import SwiftUI
import AVFoundation

struct DraggableCameraView: View {
    @Binding var position: CGPoint
    @Binding var size: CGSize
    let previewLayer: AVCaptureVideoPreviewLayer?

    @State private var isDragging = false
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            if let layer = previewLayer {
                CameraPreviewRepresentable(previewLayer: layer)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        Text("Camera")
                            .foregroundColor(.white)
                    )
            }
        }
        .position(x: position.x + dragOffset.width, y: position.y + dragOffset.height)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    position.x += value.translation.width
                    position.y += value.translation.height
                }
        )
    }
}

struct CameraPreviewRepresentable: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer = previewLayer
        previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        previewLayer.frame = nsView.bounds
    }
}
```

---

### 5.2 Integrate into Recording View
**File:** Update your recording overlay view to include camera overlay

```swift
@State private var cameraPosition = CGPoint(x: 100, y: 100)
@State private var cameraSize = CGSize(width: 200, height: 150)

var body: some View {
    ZStack {
        // ... existing recording overlay ...

        if settings.cameraEnabled, let previewLayer = recordingEngine.cameraPreviewLayer {
            DraggableCameraView(
                position: $cameraPosition,
                size: $cameraSize,
                previewLayer: previewLayer
            )
            .onChange(of: cameraPosition) { newPosition in
                // Update compositor position
                recordingEngine.updateOverlayPosition(
                    CGRect(origin: newPosition, size: cameraSize)
                )
            }
        }
    }
}
```

---

### 5.3 Phase 5 Deliverables
- ✅ Camera preview visible during recording
- ✅ Drag gesture updates overlay position in real-time
- ✅ Position persists across recordings
- ✅ UI remains responsive during recording

**Manual Test:**
```bash
# Start recording with camera enabled
# Drag camera overlay to different positions
# Verify:
# - Drag is smooth (no lag)
# - Final video shows overlay at dragged positions
# - App doesn't freeze or stutter
```

---

## Phase 6: Optimization & Polish
**Duration:** 5-7 days
**Goal:** Performance tuning, bug fixes, production readiness
**Risk:** Low ⚠️

### 6.1 Performance Optimization

**6.1.1 Metal-accelerated Composition (Optional)**
If Core Image composition is > 25% CPU, replace with Metal:

```swift
// VideoCompositor.swift - Metal version
import Metal
import MetalKit

public class MetalVideoCompositor {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    // ... implementation using Metal shaders for faster composition ...
}
```

**6.1.2 Buffer Pooling**
Reduce allocations by reusing pixel buffers:

```swift
private var pixelBufferPool: CVPixelBufferPool?

func createPixelBufferPool(width: Int, height: Int) {
    let attrs = [
        kCVPixelBufferWidthKey: width,
        kCVPixelBufferHeightKey: height,
        kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
        kCVPixelBufferIOSurfacePropertiesKey: [:]
    ] as CFDictionary

    CVPixelBufferPoolCreate(nil, nil, attrs, &pixelBufferPool)
}

func getPixelBuffer() -> CVPixelBuffer? {
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool!, &buffer)
    return buffer
}
```

---

### 6.2 Error Handling & Edge Cases

**6.2.1 Camera Disconnect During Recording**
```swift
// Add notification observer
NotificationCenter.default.addObserver(
    self,
    selector: #selector(cameraDisconnected),
    name: .AVCaptureDeviceWasDisconnected,
    object: nil
)

@objc private func cameraDisconnected() {
    // Gracefully disable camera overlay
    // Continue screen recording without camera
    print("⚠️ Camera disconnected - continuing without overlay")
}
```

**6.2.2 Sync Drift Detection**
```swift
private var lastScreenTimestamp: CMTime = .zero
private var lastCameraTimestamp: CMTime = .zero

func checkSync() -> Bool {
    let drift = abs(lastScreenTimestamp.seconds - lastCameraTimestamp.seconds)
    if drift > 0.1 {  // 100ms threshold
        print("⚠️ A/V sync drift detected: \(drift)s")
        return false
    }
    return true
}
```

---

### 6.3 Phase 6 Deliverables
- ✅ CPU usage < 30% (1080p @ 30fps with camera)
- ✅ Memory usage < 300MB
- ✅ A/V sync drift < 50ms
- ✅ All edge cases handled gracefully
- ✅ Production-ready code quality

**Performance Test:**
```bash
# Record 5-minute video with camera at 1080p/30fps
# Monitor using Activity Monitor:
# - CPU < 30%
# - Memory < 300MB
# - No memory leaks
# - Smooth preview throughout
```

---

## Testing Strategy

### Unit Tests (Per Phase)
```bash
# Phase 1
swift test --filter CameraPermissionManagerTests

# Phase 2
swift test --filter CameraCaptureEngineTests

# Phase 3
swift test --filter ScreenCaptureEngineTests/testDualModeRecording

# Phase 4
swift test --filter ManualRecordingEngineTests
swift test --filter VideoCompositorTests

# Phase 5
# (UI tests - manual)

# Phase 6
swift test --enable-code-coverage
```

### Integration Tests
**File:** `MyRecTests/Integration/CameraIntegrationTests.swift`

```swift
@available(macOS 15.0, *)
final class CameraIntegrationTests: XCTestCase {
    func testEndToEndRecordingWithCamera() async throws {
        let engine = ManualRecordingEngine()

        let region = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlayRect = CGRect(x: 20, y: 20, width: 200, height: 150)

        try await engine.startCapture(
            region: region,
            resolution: .fullHD,
            frameRate: .fps30,
            withAudio: true,
            withMicrophone: false,
            withCamera: true,
            overlayRect: overlayRect
        )

        // Record for 5 seconds
        try await Task.sleep(nanoseconds: 5_000_000_000)

        let outputURL = try await engine.stopCapture()

        // Verify output
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let asset = AVAsset(url: outputURL)
        let duration = try await asset.load(.duration)
        XCTAssertGreaterThan(duration.seconds, 4.5)  // Allow some variance

        // Verify has video and audio tracks
        let tracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertEqual(tracks.count, 1)

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(audioTracks.count, 1)
    }
}
```

### Manual Testing Checklist
- [ ] Camera permission dialog shows on first toggle
- [ ] Denied permission shows alert with "Open Settings" button
- [ ] Camera preview appears when enabled
- [ ] Drag camera overlay updates position smoothly
- [ ] Recording with camera produces valid MP4
- [ ] Camera overlay visible at correct position in playback
- [ ] Audio in sync throughout 5-minute recording
- [ ] Disconnecting camera during recording doesn't crash
- [ ] Recording without camera still works (regression test)
- [ ] Performance acceptable on Intel and Apple Silicon

---

## Rollback Plan

Each phase is independently reversible via git:

### Phase 1 Rollback
```bash
git revert <commit-range-for-phase-1>
# Remove CameraPermissionManager.swift
# Restore Info.plist
```

### Phase 2 Rollback
```bash
git revert <commit-range-for-phase-2>
# Remove CameraCaptureEngine.swift
```

### Phase 3 Rollback
```bash
# Disable feature flag
RecordingSettings.default.useManualComposition = false

# Or revert commits
git revert <commit-range-for-phase-3>
```

### Phase 4+ Rollback
```bash
# Complete rollback - remove all camera code
git revert <all-camera-commits>

# Or feature flag
RecordingSettings.default.cameraEnabled = false  # Disable in UI
```

### Emergency Rollback (Production)
If shipped and critical bug found:

```bash
# Hotfix: Disable camera via remote config or hardcode
struct RecordingSettings {
    var cameraEnabled: Bool {
        return false  // Force disable until bug fixed
    }
}
```

---

## Summary Timeline

| Phase | Duration | Complexity | Risk | Deliverable |
|-------|----------|------------|------|-------------|
| 1. Foundation | 3-4 days | Low | ⚠️ | Permissions working |
| 2. Basic Camera | 4-5 days | Low | ⚠️ | Camera records separately |
| 3. Dual-Mode | 5-6 days | Medium | ⚠️⚠️ | Both engines run in parallel |
| 4. Composition | 7-10 days | High | ⚠️⚠️⚠️ | Manual pipeline with overlay |
| 5. UI Integration | 5-6 days | Medium | ⚠️⚠️ | Draggable overlay |
| 6. Optimization | 5-7 days | Low | ⚠️ | Production ready |
| **Total** | **29-38 days** | | | **~6-8 weeks** |

---

## Success Metrics

### Functional Requirements
- ✅ Camera overlay visible in recordings
- ✅ Draggable positioning during recording
- ✅ Audio/video sync within ±50ms
- ✅ No regression in screen-only recording

### Performance Requirements
- ✅ CPU < 30% (1080p/30fps with camera)
- ✅ Memory < 300MB
- ✅ GPU usage < 25%
- ✅ File size within 10% of native SCRecordingOutput

### Quality Requirements
- ✅ All unit tests passing
- ✅ Code coverage > 70%
- ✅ No memory leaks detected
- ✅ Handles edge cases gracefully

---

**Document Version:** 1.0
**Last Updated:** 2025-11-25
**Author:** Claude (Sonnet 4.5)
**Status:** ✅ Ready for Implementation
