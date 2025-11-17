# Week 5: Backend Integration - Detailed Plan

**Phase:** Backend Integration (Start)
**Duration:** Days 19-23 (5 days)
**Status:** 📋 Planned
**Goal:** Replace mock data with real screen recording functionality

---

## Week 5 Overview

### Primary Objectives

1. **ScreenCaptureKit Integration** - Get real screen capture working
2. **Video Encoding Pipeline** - Implement H.264 encoding to MP4
3. **File System Integration** - Save recordings to disk
4. **Recording State Machine** - Connect UI to real recording engine
5. **Basic Playback** - Wire AVPlayer to preview real recordings

### Success Criteria

By end of Week 5, the app should:
- ✅ Capture screen content using ScreenCaptureKit
- ✅ Encode video to H.264/MP4 format
- ✅ Save recordings to ~/Movies/ with correct naming
- ✅ Play back recorded videos in Preview Dialog
- ✅ Show real recording duration and file size
- ✅ Handle recording start/stop from UI

### Out of Scope (Future Weeks)

- ❌ Audio capture (Week 6-7)
- ❌ Pause/Resume functionality (Week 7)
- ❌ Camera overlay (Week 8)
- ❌ Trim functionality (keep mock for now)
- ❌ Advanced encoding options

---

## Day 19: Testing & Documentation Cleanup

**Status:** 📋 Planned
**Focus:** Prepare for backend integration

### Tasks

#### 1. Update Documentation ✅ Target
- [ ] Update `docs/progress.md` with Days 14-18 completion
- [ ] Update master plan Week 4 status to complete
- [ ] Create this Week 5 plan document
- [ ] Document current UI component API surface
- [ ] List all NotificationCenter events and their payloads

**Files to Update:**
- `docs/progress.md`
- `plan/master implementation plan.md`
- `docs/week5-backend-integration-plan.md` (this file)

#### 2. UI Flow Testing ✅ Target
- [ ] Test complete user journey (Home → Record → Stop → Preview)
- [ ] Test all recording states (Idle → Recording → Paused → Idle)
- [ ] Test keyboard shortcuts (⌘⌥1, ⌘⌥2, ⌘⌥,)
- [ ] Test region selection modes (full-screen, window, custom)
- [ ] Test Settings Dialog persistence
- [ ] Document any UI bugs or edge cases

**Test Scenarios:**
```
1. Full-screen recording flow
2. Window recording flow
3. Custom region recording flow
4. Pause/Resume state transitions
5. Settings changes during recording
6. Keyboard shortcut interruptions
7. Multiple recordings in sequence
```

#### 3. Code Review & Cleanup ✅ Target
- [ ] Review all UI code for backend integration points
- [ ] Identify hardcoded mock data to replace
- [ ] Document ViewModels that need backend connections
- [ ] Clean up debug/demo code in AppDelegate
- [ ] Run SwiftLint and fix any violations
- [ ] Ensure all tests still pass (89/89)

**Integration Points to Document:**
- StatusBarController timer updates
- RegionSelectionViewModel capture region
- PreviewDialogView video player
- HomePageView recordings list
- SettingsManager recording settings

#### 4. Architecture Planning ✅ Target
- [ ] Design RecordingManager interface
- [ ] Design ScreenCaptureEngine interface
- [ ] Design VideoEncoder interface
- [ ] Plan notification flow for recording events
- [ ] Design error handling strategy

**Deliverables:**
- Architecture diagram for recording engine
- Service interface definitions
- Data flow diagram (UI → Services → File System)

**Time Estimate:** 6-8 hours

---

## Day 20: ScreenCaptureKit Foundation

**Status:** 📋 Planned
**Focus:** Get screen capture working with ScreenCaptureKit

### Tasks

#### 1. ScreenCaptureKit Research & Setup ✅ Target

**Research:**
- [ ] Review Apple's ScreenCaptureKit documentation
- [ ] Study sample code (AVCaptureScreenInput alternative)
- [ ] Understand SCStreamConfiguration options
- [ ] Research macOS 12 fallback (CGDisplayStream)

**Permission Handling:**
- [ ] Test screen recording permission on macOS 13+
- [ ] Handle permission denial gracefully
- [ ] Add permission request UI if needed

#### 2. ScreenCaptureEngine Implementation ✅ Target

**Create:** `MyRec/Services/Recording/ScreenCaptureEngine.swift`

```swift
/// Handles screen capture using ScreenCaptureKit (macOS 13+)
class ScreenCaptureEngine {
    // MARK: - Properties
    private var stream: SCStream?
    private var streamConfiguration: SCStreamConfiguration
    private var captureRegion: CGRect

    // MARK: - Public Interface
    func configure(region: CGRect, resolution: Resolution, frameRate: FrameRate)
    func startCapture() async throws
    func stopCapture() async throws
    func pauseCapture() async throws
    func resumeCapture() async throws

    // MARK: - Delegate
    var videoFrameHandler: ((CVPixelBuffer, CMTime) -> Void)?
}
```

**Key Features:**
- Configure capture region from RegionSelectionViewModel
- Support resolution scaling (capture at native, encode at target)
- Frame rate control (15, 24, 30, 60 FPS)
- Cursor visibility toggle
- Efficient CVPixelBuffer delivery

**Files to Create:**
- `MyRec/Services/Recording/ScreenCaptureEngine.swift`
- `MyRecTests/Services/ScreenCaptureEngineTests.swift`

#### 3. Basic Capture Test ✅ Target

**Test Application:**
- [ ] Create simple test: capture 5 seconds of screen
- [ ] Log frame delivery rate
- [ ] Verify CVPixelBuffer format
- [ ] Test different resolutions (720p, 1080p)
- [ ] Test different frame rates (30, 60 FPS)

**Manual Testing:**
- Capture screen while moving windows
- Verify smooth playback
- Check CPU/memory usage
- Test on both Intel and Apple Silicon (if available)

**Success Criteria:**
- Captures frames at requested frame rate (±5%)
- CVPixelBuffer format: kCVPixelFormatType_32BGRA or compatible
- CPU usage < 30% during capture
- No dropped frames for 30 second capture

**Time Estimate:** 8-10 hours

---

## Day 21: Video Encoding Pipeline

**Status:** 📋 Planned
**Focus:** Encode captured frames to H.264/MP4

### Tasks

#### 1. VideoEncoder Implementation ✅ Target

**Create:** `MyRec/Services/Recording/VideoEncoder.swift`

```swift
/// Encodes video frames to H.264/MP4 using AVAssetWriter
class VideoEncoder {
    // MARK: - Properties
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private let outputURL: URL
    private let resolution: Resolution
    private let frameRate: FrameRate

    // MARK: - Public Interface
    func startEncoding(outputURL: URL, resolution: Resolution, frameRate: FrameRate) throws
    func appendFrame(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime)
    func finishEncoding() async throws
    func cancelEncoding()

    // MARK: - Configuration
    private func createVideoSettings() -> [String: Any]
    private func calculateBitrate() -> Int
}
```

**Video Settings:**
```swift
// H.264 Configuration
codec: kCMVideoCodecType_H264
profile: AVVideoProfileLevelH264HighAutoLevel
bitrate: Adaptive based on resolution
  - 720P @ 30FPS: ~2.5 Mbps
  - 1080P @ 30FPS: ~5 Mbps
  - 2K @ 30FPS: ~8 Mbps
  - 4K @ 30FPS: ~15 Mbps
colorPrimaries: ITU_R_709_2
transferFunction: ITU_R_709_2
YCbCr matrix: ITU_R_709_2
```

**Files to Create:**
- `MyRec/Services/Recording/VideoEncoder.swift`
- `MyRecTests/Services/VideoEncoderTests.swift`

#### 2. AVAssetWriter Integration ✅ Target

**Implementation Steps:**
1. Create AVAssetWriter with MP4 file type
2. Configure AVAssetWriterInput for video
3. Create AVAssetWriterInputPixelBufferAdaptor
4. Set up compression settings
5. Implement frame appending with timing
6. Handle finishing and cleanup

**Critical Details:**
- Use real-time priority for video input
- Set expectsMediaDataInRealTime = true
- Handle buffer full scenarios
- Proper CMTime management for sync
- Atomic file writes (use temp file)

#### 3. End-to-End Encoding Test ✅ Target

**Test:**
```swift
func testEncodingFlow() async throws {
    // 1. Generate 300 test frames (10 seconds @ 30fps)
    // 2. Encode to MP4
    // 3. Verify file exists and is playable
    // 4. Check duration is ~10 seconds
    // 5. Verify resolution matches
    // 6. Check file size is reasonable
}
```

**Manual Testing:**
- Encode 30 second screen capture
- Play in QuickTime Player
- Verify no artifacts or corruption
- Check file metadata (resolution, FPS, codec)
- Test different resolutions
- Verify bitrate is within range

**Success Criteria:**
- MP4 file plays in QuickTime/VLC
- Duration matches recording time (±0.5s)
- Resolution matches settings
- File size is reasonable (~0.5-2 MB per minute for 1080p)
- No frame drops or artifacts

**Time Estimate:** 8-10 hours

---

## Day 22: RecordingManager & File System

**Status:** 📋 Planned
**Focus:** Coordinate capture + encoding + file management

### Tasks

#### 1. RecordingManager Implementation ✅ Target

**Create:** `MyRec/Services/Recording/RecordingManager.swift`

```swift
/// Central coordinator for screen recording
class RecordingManager: ObservableObject {
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

    // MARK: - Public Interface
    func startRecording(region: CGRect) async throws
    func stopRecording() async throws -> VideoMetadata
    func pauseRecording() throws  // Week 7
    func resumeRecording() throws // Week 7

    // MARK: - Private Methods
    private func setupCaptureSession(region: CGRect) throws
    private func setupEncoder() throws
    private func handleFrame(_ pixelBuffer: CVPixelBuffer, _ time: CMTime)
    private func updateDuration()
    private func generateOutputURL() -> URL
    private func createVideoMetadata() -> VideoMetadata
}
```

**Key Responsibilities:**
1. Coordinate ScreenCaptureEngine + VideoEncoder
2. Manage recording state machine
3. Update duration timer (every second)
4. Generate output filenames
5. Create VideoMetadata on completion
6. Post notifications for UI updates
7. Error handling and recovery

**Files to Create:**
- `MyRec/Services/Recording/RecordingManager.swift`
- `MyRecTests/Services/RecordingManagerTests.swift`

#### 2. File Management Service ✅ Target

**Create:** `MyRec/Services/FileManagement/FileManagerService.swift`

```swift
/// Handles file system operations for recordings
class FileManagerService {
    // MARK: - Properties
    private let settingsManager: SettingsManager

    // MARK: - Public Interface
    func generateRecordingURL(timestamp: Date) -> URL
    func saveRecording(from tempURL: URL, to finalURL: URL) throws -> URL
    func deleteRecording(at url: URL) throws
    func getVideoMetadata(for url: URL) throws -> VideoMetadata
    func ensureRecordingDirectoryExists() throws

    // MARK: - Validation
    func validateSaveLocation(_ path: String) -> Bool
    func isPathWritable(_ path: String) -> Bool
    func calculateFileSize(at url: URL) -> Int64
}
```

**Filename Convention:**
```
Format: REC-{YYYYMMDDHHMMSS}.mp4
Example: REC-20251117143022.mp4

Trimmed: REC-{YYYYMMDDHHMMSS}-trimmed.mp4
```

**Features:**
- Atomic writes using temp files
- Directory creation if missing
- Path validation and sanitization
- File size calculation
- Metadata extraction using AVAsset

**Files to Create:**
- `MyRec/Services/FileManagement/FileManagerService.swift`
- `MyRecTests/Services/FileManagerServiceTests.swift`

#### 3. Integration Test ✅ Target

**Test Full Recording Flow:**
```swift
func testCompleteRecordingFlow() async throws {
    let manager = RecordingManager()

    // 1. Start recording 720p @ 30fps
    try await manager.startRecording(region: CGRect(x: 0, y: 0, width: 1280, height: 720))

    // 2. Wait 5 seconds
    try await Task.sleep(nanoseconds: 5_000_000_000)

    // 3. Stop recording
    let metadata = try await manager.stopRecording()

    // 4. Verify file exists
    XCTAssertTrue(FileManager.default.fileExists(atPath: metadata.fileURL.path))

    // 5. Verify metadata
    XCTAssertEqual(metadata.resolution, .hd720p)
    XCTAssertEqual(metadata.frameRate, .fps30)
    XCTAssertGreaterThan(metadata.duration, 4.5)
    XCTAssertLessThan(metadata.duration, 5.5)

    // 6. Verify playable
    let asset = AVAsset(url: metadata.fileURL)
    let playable = try await asset.load(.isPlayable)
    XCTAssertTrue(playable)
}
```

**Success Criteria:**
- Recording creates MP4 file in ~/Movies/
- Filename follows REC-{timestamp}.mp4 format
- File is playable in QuickTime
- Metadata is accurate (duration, resolution, FPS)
- File size is reasonable

**Time Estimate:** 8-10 hours

---

## Day 23: UI Integration & Testing

**Status:** 📋 Planned
**Focus:** Connect real recording to existing UI

### Tasks

#### 1. Replace Mock Recording Logic ✅ Target

**Files to Modify:**

**A. AppDelegate.swift**
```swift
// REMOVE: Mock timer and demo methods
// REMOVE: handleStartRecording() mock implementation
// REMOVE: handleStopRecording() mock implementation

// ADD: Real RecordingManager instance
private let recordingManager = RecordingManager()

// UPDATE: handleStartRecording()
@objc private func handleStartRecording() {
    Task {
        do {
            // Get region from RegionSelectionViewModel
            let region = regionSelectionViewModel.selectedRegion
            try await recordingManager.startRecording(region: region)
        } catch {
            // Show error alert
            showRecordingError(error)
        }
    }
}

// UPDATE: handleStopRecording()
@objc private func handleStopRecording() {
    Task {
        do {
            let metadata = try await recordingManager.stopRecording()

            // Open preview with real recording
            await MainActor.run {
                openPreviewDialog(with: metadata)
            }
        } catch {
            showRecordingError(error)
        }
    }
}
```

**B. StatusBarController.swift**
```swift
// UPDATE: Subscribe to RecordingManager.duration
private func observeRecordingDuration() {
    recordingManager.$duration
        .sink { [weak self] duration in
            self?.updateTimerDisplay(duration)
        }
        .store(in: &cancellables)
}

// UPDATE: Subscribe to RecordingManager.state
private func observeRecordingState() {
    recordingManager.$state
        .sink { [weak self] state in
            self?.updateMenuForState(state)
        }
        .store(in: &cancellables)
}
```

**C. PreviewDialogView.swift**
```swift
// ADD: AVPlayer for real video playback
@State private var player: AVPlayer?

// UPDATE: Video player view
VideoPlayer(player: player)
    .frame(height: 400)
    .onAppear {
        player = AVPlayer(url: recording.fileURL)
    }
    .onDisappear {
        player?.pause()
        player = nil
    }

// UPDATE: Metadata display (use real values)
Text("Duration: \(formatDuration(recording.duration))")
Text("File Size: \(formatFileSize(recording.fileSize))")
Text("Resolution: \(recording.resolution.displayName)")
Text("Frame Rate: \(recording.frameRate.displayName)")
```

**D. HomePageView.swift**
```swift
// UPDATE: Load real recordings from ~/Movies/
private func loadRecordings() {
    let recordingsURL = settingsManager.saveLocationURL

    do {
        let files = try FileManager.default
            .contentsOfDirectory(at: recordingsURL, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.pathExtension == "mp4" }
            .filter { $0.lastPathComponent.starts(with: "REC-") }
            .sorted { /* by creation date */ }

        // Load metadata for each file
        recordings = files.compactMap { url in
            try? fileManagerService.getVideoMetadata(for: url)
        }
    } catch {
        print("Failed to load recordings: \(error)")
    }
}
```

#### 2. Remove Mock Data Infrastructure ✅ Target

**Files to Remove/Clean:**
- Remove `MockRecordingGenerator.generateMockRecordings()` calls
- Keep `MockRecording` model (useful for future tests)
- Remove demo/test menu items from AppDelegate
- Clean up any hardcoded test data

**Files to Update:**
- `MyRec/AppDelegate.swift`
- `MyRec/Views/HomePageView.swift`
- `MyRec/Services/StatusBar/StatusBarController.swift`

#### 3. Error Handling & UI Feedback ✅ Target

**Add Error Alerts:**
```swift
// Screen recording permission denied
// File save failed (disk full, permissions)
// Encoding failed
// Invalid region selected
// ScreenCaptureKit not available (macOS < 13)
```

**Create:** `MyRec/Views/Alerts/ErrorAlertView.swift`

```swift
struct ErrorAlertView {
    let error: RecordingError
    let onDismiss: () -> Void

    var body: some View {
        // User-friendly error messages
        // Action buttons (Try Again, Cancel, Open Settings)
    }
}

enum RecordingError: LocalizedError {
    case permissionDenied
    case encodingFailed(Error)
    case saveFailed(Error)
    case captureUnavailable

    var errorDescription: String? { /* ... */ }
    var recoverySuggestion: String? { /* ... */ }
}
```

#### 4. End-to-End Integration Testing ✅ Target

**Manual Test Checklist:**

```
Recording Flow:
☐ 1. Launch app → Home page appears
☐ 2. Click "Record Screen" → Region selection appears
☐ 3. Select full-screen → Resize handles appear
☐ 4. Adjust resolution to 1080p, FPS to 30
☐ 5. Click Record → Countdown plays (3-2-1)
☐ 6. Recording starts → Status bar shows timer
☐ 7. Wait 10 seconds → Timer counts up correctly
☐ 8. Click Stop → Recording stops
☐ 9. Preview opens → Real video plays
☐ 10. Verify metadata is correct
☐ 11. Click "Open Folder" → Finder opens ~/Movies/
☐ 12. Verify file exists and is playable

Keyboard Shortcuts:
☐ 13. Press ⌘⌥1 → Recording starts
☐ 14. Press ⌘⌥1 → Pause (if implemented)
☐ 15. Press ⌘⌥2 → Recording stops
☐ 16. Press ⌘⌥, → Settings opens

Different Resolutions:
☐ 17. Record at 720p → Verify output resolution
☐ 18. Record at 1080p → Verify output resolution
☐ 19. Record at 2K → Verify output resolution
☐ 20. Record at 4K → Verify output resolution (if supported)

Different Frame Rates:
☐ 21. Record at 15 FPS → Verify playback
☐ 22. Record at 24 FPS → Verify playback
☐ 23. Record at 30 FPS → Verify playback
☐ 24. Record at 60 FPS → Verify playback

Error Scenarios:
☐ 25. Deny screen recording permission → Error shown
☐ 26. Set invalid save location → Error shown
☐ 27. Fill disk space → Graceful failure
☐ 28. Force quit during recording → No corruption

Performance:
☐ 29. CPU usage < 30% during 1080p @ 30fps recording
☐ 30. Memory usage < 300 MB during recording
☐ 31. No frame drops during 5 minute recording
☐ 32. Audio/video sync within ±50ms (when audio added)
```

#### 5. Documentation & Cleanup ✅ Target

**Update Documentation:**
- [ ] Update `docs/progress.md` with Week 5 completion
- [ ] Document RecordingManager API
- [ ] Add troubleshooting guide for common issues
- [ ] Update architecture.md with recording pipeline
- [ ] Create backend integration summary document

**Code Cleanup:**
- [ ] Remove all debug print statements
- [ ] Run SwiftLint and fix violations
- [ ] Update comments and documentation
- [ ] Ensure all tests pass
- [ ] Clean build with no warnings

**Time Estimate:** 8-10 hours

---

## Week 5 Deliverables Summary

### New Services (5 files)

```
MyRec/Services/Recording/
├── ScreenCaptureEngine.swift          (~300 lines)
├── VideoEncoder.swift                 (~250 lines)
└── RecordingManager.swift             (~350 lines)

MyRec/Services/FileManagement/
└── FileManagerService.swift           (~200 lines)

MyRec/Views/Alerts/
└── ErrorAlertView.swift               (~100 lines)
```

### Modified Files (6 files)

```
MyRec/AppDelegate.swift                (replace mock with real)
MyRec/Services/StatusBar/StatusBarController.swift (connect to RecordingManager)
MyRec/Views/HomePageView.swift         (load real recordings)
MyRec/Views/PreviewDialogView.swift    (AVPlayer integration)
MyRec/ViewModels/RegionSelectionViewModel.swift (expose selected region)
Package.swift                          (add new files)
```

### Test Files (5 files)

```
MyRecTests/Services/
├── ScreenCaptureEngineTests.swift     (~150 lines)
├── VideoEncoderTests.swift            (~200 lines)
├── RecordingManagerTests.swift        (~250 lines)
└── FileManagerServiceTests.swift      (~150 lines)

MyRecTests/Integration/
└── RecordingFlowTests.swift           (~200 lines, NEW)
```

### Documentation (4 files)

```
docs/
├── week5-backend-integration-plan.md  (this file)
├── week5-completion-summary.md        (end of week)
├── progress.md                        (updated)
└── architecture.md                    (updated)
```

---

## Technical Specifications

### ScreenCaptureKit Configuration

```swift
// macOS 13+ using SCStream
let config = SCStreamConfiguration()
config.width = resolution.width
config.height = resolution.height
config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate.value))
config.pixelFormat = kCVPixelFormatType_32BGRA
config.showsCursor = settingsManager.showCursor
config.queueDepth = 5

// Capture entire display or specific region
let filter = SCContentFilter(display: display, excludingWindows: [])
let stream = SCStream(filter: filter, configuration: config, delegate: self)
```

### AVAssetWriter Configuration

```swift
// Video compression settings
let videoSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: resolution.width,
    AVVideoHeightKey: resolution.height,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: calculateBitrate(),
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: frameRate.value * 2, // Keyframe every 2 seconds
        AVVideoAllowFrameReorderingKey: true,
        AVVideoExpectedSourceFrameRateKey: frameRate.value
    ]
]

// File output
let assetWriter = try AVAssetWriter(
    outputURL: outputURL,
    fileType: .mp4
)
```

### Bitrate Calculation

```swift
func calculateBitrate(resolution: Resolution, frameRate: FrameRate) -> Int {
    let baseRate: Int

    switch resolution {
    case .hd720p:   baseRate = 2_500_000  // 2.5 Mbps
    case .fullHD:   baseRate = 5_000_000  // 5 Mbps
    case .twoK:     baseRate = 8_000_000  // 8 Mbps
    case .fourK:    baseRate = 15_000_000 // 15 Mbps
    case .custom:   baseRate = 5_000_000  // Default to 1080p equivalent
    }

    // Adjust for frame rate (60fps needs ~1.5x bitrate)
    let fpsMultiplier = Double(frameRate.value) / 30.0
    return Int(Double(baseRate) * fpsMultiplier)
}
```

---

## Testing Strategy

### Unit Tests

**ScreenCaptureEngineTests:**
- Test configuration with different resolutions
- Test frame delivery callback
- Test start/stop lifecycle
- Test error handling

**VideoEncoderTests:**
- Test encoding with synthetic frames
- Test bitrate calculation
- Test file creation
- Test cancellation during encoding

**RecordingManagerTests:**
- Test state transitions
- Test duration tracking
- Test file naming
- Test error propagation

**FileManagerServiceTests:**
- Test filename generation
- Test path validation
- Test metadata extraction
- Test file operations

### Integration Tests

**RecordingFlowTests:**
- Test 5-second recording end-to-end
- Test multiple consecutive recordings
- Test different resolution/FPS combinations
- Test error recovery

### Manual Testing

- Visual quality verification
- Performance profiling (Instruments)
- Different display configurations
- Multi-monitor setups
- Retina vs non-Retina displays

---

## Performance Targets

### CPU Usage
```
Idle:               < 0.5%
Recording (720p):   < 20%
Recording (1080p):  < 25%
Recording (2K):     < 35%
Recording (4K):     < 50%
```

### Memory Usage
```
Idle:               < 50 MB
Recording (720p):   < 150 MB
Recording (1080p):  < 200 MB
Recording (2K):     < 300 MB
Recording (4K):     < 500 MB
```

### File Sizes (per minute)
```
720p @ 30fps:   ~1.2 MB/min
1080p @ 30fps:  ~2.5 MB/min
2K @ 30fps:     ~4.0 MB/min
4K @ 30fps:     ~7.5 MB/min
```

---

## Risk Mitigation

### Risk: ScreenCaptureKit Not Available (macOS < 13)

**Mitigation:**
- Detect OS version at runtime
- Show clear error: "Requires macOS 13 or later"
- Future: Implement fallback using CGDisplayStream

### Risk: Permission Denied

**Mitigation:**
- Check permission before starting
- Show clear instructions to enable in System Settings
- Provide "Open System Settings" button

### Risk: Encoding Performance Issues

**Mitigation:**
- Use hardware acceleration (VideoToolbox)
- Adaptive bitrate based on CPU usage
- Drop frames if necessary (log warning)
- Lower resolution/FPS automatically if struggling

### Risk: Disk Space Full

**Mitigation:**
- Check available space before recording
- Estimate file size based on settings
- Warn if < 1GB free space
- Graceful failure with partial recording saved

---

## Success Metrics

### By End of Week 5

```
✅ Core Functionality:
   - Real screen recording working
   - MP4 files saved to disk
   - Preview plays real recordings
   - Accurate metadata displayed

✅ Quality:
   - Video quality acceptable (no artifacts)
   - File sizes reasonable
   - No frame drops for 5+ minute recordings
   - Audio sync N/A (audio in Week 6-7)

✅ Performance:
   - CPU usage within targets
   - Memory usage within targets
   - Recording starts within 1 second
   - No UI lag during recording

✅ Testing:
   - 100% unit test coverage for new services
   - Integration tests passing
   - Manual test checklist 100% complete
   - Zero critical bugs

✅ Code Quality:
   - Clean build (no warnings)
   - SwiftLint passing
   - All tests passing
   - Documentation complete
```

---

## Week 6 Preview

**Focus:** Audio Integration

- System audio capture (CoreAudio)
- Microphone input (AVAudioEngine)
- Audio/video synchronization
- Audio mixing pipeline
- AAC encoding
- Testing lip sync accuracy

---

## Daily Standup Template

```markdown
### Day X Status

**Completed:**
- [ ] Task 1
- [ ] Task 2

**In Progress:**
- [ ] Task 3

**Blockers:**
- None / [Describe blocker]

**Next:**
- [ ] Task 4
- [ ] Task 5

**Notes:**
- [Any important observations]
```

---

## Resources

### Apple Documentation
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [AVAssetWriter](https://developer.apple.com/documentation/avfoundation/avassetwriter)
- [Video Compression](https://developer.apple.com/documentation/avfoundation/avassetwriterinput/1387827-compressionproperties)
- [H.264 Encoding](https://developer.apple.com/documentation/videotoolbox)

### Sample Code
- [CaptureSample](https://developer.apple.com/documentation/screencapturekit/capturing_screen_content_in_macos) - Apple's official sample

### Tools
- **Instruments**: Profile performance
- **QuickTime Player**: Verify encoding quality
- **MediaInfo**: Inspect video metadata
- **VLC**: Test playback compatibility

---

**Status:** 📋 Ready for Implementation
**Estimated Total Time:** 40-45 hours
**Target Completion:** End of Week 5 (Day 23)
