# Phase 1, Week 4: File Save & Optimization

**Duration:** Week 4 (Days 16-20)
**Phase:** Foundation & Core Recording (Final Week)
**Status:** Ready to Start
**Team Size:** 5 people

---

## Week Objectives

1. Implement robust file save functionality with atomic writes
2. Extract and display video metadata
3. Comprehensive error handling throughout the app
4. Performance optimization for encoding and capture
5. Phase 1 completion testing and validation
6. Prepare demo and documentation for stakeholder review

---

## Success Criteria

- [ ] Files save reliably with atomic writes
- [ ] Metadata extraction working (duration, size, resolution, FPS)
- [ ] All error scenarios handled gracefully
- [ ] Performance targets met (CPU < 25% for 1080P@30FPS)
- [ ] No memory leaks over 1-hour recording
- [ ] All Phase 1 tests passing (85%+ coverage)
- [ ] Demo ready for stakeholders
- [ ] Phase 1 retrospective completed

---

## Daily Breakdown

### Day 16 (Monday): File Management & Metadata

**Morning (9 AM - 12 PM)**
- **9:00-9:15** - Daily standup
- **9:15-12:00** - FileManager implementation (Mid-level Dev)

```swift
// Services/File/RecordingFileManager.swift
import AVFoundation

class RecordingFileManager {
    static let shared = RecordingFileManager()

    private let settingsManager = SettingsManager.shared

    // MARK: - File Operations

    func createRecordingFile(settings: RecordingSettings) throws -> URL {
        let savePath = settingsManager.savePath
        let filename = generateFilename()
        let fileURL = savePath.appendingPathComponent(filename)

        // Ensure directory exists
        try ensureDirectoryExists(at: savePath)

        // Create temporary file for atomic write
        let tempURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(".\(filename).tmp")

        return tempURL
    }

    func finalizeRecording(tempURL: URL) throws -> URL {
        let finalURL = tempURL.deletingLastPathComponent()
            .appendingPathComponent(
                tempURL.lastPathComponent.replacingOccurrences(of: ".tmp", with: "")
            )

        // Atomic move from temp to final
        try FileManager.default.moveItem(at: tempURL, to: finalURL)

        return finalURL
    }

    func deleteRecording(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    func getFileSize(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }
        return fileSize
    }

    func checkDiskSpace(requiredBytes: Int64) -> Bool {
        guard let savePath = settingsManager.savePath.path as String?,
              let attributes = try? FileManager.default.attributesOfFileSystem(forPath: savePath),
              let freeSpace = attributes[.systemFreeSize] as? Int64 else {
            return false
        }

        // Require 2x the estimated size for safety
        return freeSpace > (requiredBytes * 2)
    }

    // MARK: - Metadata Extraction

    func extractMetadata(from url: URL) async throws -> VideoMetadata {
        let asset = AVAsset(url: url)

        // Load properties asynchronously
        try await asset.load(.duration, .tracks)

        // Get duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        // Get video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw MetadataError.noVideoTrack
        }

        // Load track properties
        try await videoTrack.load(.naturalSize, .nominalFrameRate)

        // Get resolution
        let naturalSize = try await videoTrack.load(.naturalSize)
        let width = Int(naturalSize.width)
        let height = Int(naturalSize.height)

        // Get frame rate
        let frameRate = try await videoTrack.load(.nominalFrameRate)

        // Get file size
        let fileSize = getFileSize(at: url) ?? 0

        // Get creation date
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let createdAt = attributes[.creationDate] as? Date ?? Date()

        return VideoMetadata(
            filename: url.lastPathComponent,
            fileURL: url,
            fileSize: fileSize,
            duration: durationSeconds,
            resolution: CGSize(width: width, height: height),
            frameRate: Int(frameRate),
            createdAt: createdAt,
            format: "mp4"
        )
    }

    // MARK: - Private Helpers

    private func generateFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let timestamp = dateFormatter.string(from: Date())
        return "REC-\(timestamp).mp4"
    }

    private func ensureDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }
    }
}

// MARK: - VideoMetadata Model (update)

struct VideoMetadata {
    let filename: String
    let fileURL: URL
    let fileSize: Int64
    let duration: TimeInterval
    let resolution: CGSize
    let frameRate: Int
    let createdAt: Date
    let format: String

    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var durationString: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var resolutionString: String {
        "\(Int(resolution.width)) × \(Int(resolution.height))"
    }

    var createdAtString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

enum MetadataError: Error {
    case noVideoTrack
    case invalidFile
    case cannotReadFile
}
```

**Afternoon (1 PM - 5 PM)**
- **1:00-3:00** - Update RecordingManager to use FileManager (Mid-level Dev)
  - Integrate atomic writes
  - Add disk space check before recording
  - Handle file errors gracefully

- **3:00-5:00** - Testing file operations (QA + Mid-level Dev)
  - Test atomic write
  - Test insufficient disk space
  - Test permission errors
  - Test metadata extraction
  - Test on different file systems

**Deliverables:**
- RecordingFileManager implemented
- Metadata extraction working
- Atomic file writes functional

---

### Day 17 (Tuesday): Error Handling & User Feedback

**Morning (9 AM - 12 PM)**
- **9:00-9:15** - Daily standup
- **9:15-12:00** - Comprehensive error handling (Senior Dev)

```swift
// Services/Error/ErrorHandler.swift
class ErrorHandler {
    static let shared = ErrorHandler()

    func handle(_ error: Error, context: String) {
        // Log error
        logError(error, context: context)

        // Show user-friendly dialog
        showErrorDialog(for: error, context: context)
    }

    private func logError(_ error: Error, context: String) {
        print("❌ Error in \(context): \(error.localizedDescription)")

        // TODO: Send to crash reporting service (Sentry, etc.)
    }

    private func showErrorDialog(for error: Error, context: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical

        let (title, message, recovery) = errorDetails(for: error, context: context)

        alert.messageText = title
        alert.informativeText = message + "\n\n" + recovery
        alert.addButton(withTitle: "OK")

        alert.runModal()
    }

    private func errorDetails(
        for error: Error,
        context: String
    ) -> (title: String, message: String, recovery: String) {
        switch error {
        // Capture errors
        case CaptureError.noDisplay:
            return (
                "No Display Found",
                "Could not find a display to record.",
                "Please ensure your display is connected and try again."
            )

        case CaptureError.permissionDenied:
            return (
                "Screen Recording Permission Required",
                "MyRec needs permission to record your screen.",
                "Please go to System Settings → Privacy & Security → Screen Recording and enable MyRec."
            )

        // Encoding errors
        case EncoderError.cannotStartWriting:
            return (
                "Cannot Start Recording",
                "Failed to initialize video encoder.",
                "Please try a different resolution or restart the app."
            )

        case EncoderError.encodingFailed:
            return (
                "Recording Failed",
                "An error occurred during video encoding.",
                "The recording may be incomplete. Please try recording again."
            )

        // File errors
        case let nsError as NSError where nsError.domain == NSCocoaErrorDomain:
            if nsError.code == NSFileWriteOutOfSpaceError {
                return (
                    "Insufficient Disk Space",
                    "There is not enough space to save the recording.",
                    "Please free up disk space and try again."
                )
            } else if nsError.code == NSFileWriteNoPermissionError {
                return (
                    "Permission Denied",
                    "MyRec does not have permission to save files to this location.",
                    "Please choose a different save location in Settings."
                )
            }

        // Recording errors
        case RecordingError.alreadyRecording:
            return (
                "Already Recording",
                "A recording is already in progress.",
                "Please stop the current recording before starting a new one."
            )

        // Default
        default:
            return (
                "An Error Occurred",
                error.localizedDescription,
                "If this problem persists, please restart the app or contact support."
            )
        }
    }
}

// Add user-friendly error messages to existing error types
extension CaptureError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "No display available for recording"
        case .windowNotFound:
            return "Selected window not found"
        case .notCapturing:
            return "Not currently capturing"
        case .permissionDenied:
            return "Screen recording permission denied"
        }
    }
}

extension EncoderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cannotAddInput:
            return "Cannot add video input to encoder"
        case .cannotStartWriting:
            return "Cannot start video encoding"
        case .encodingFailed:
            return "Video encoding failed"
        case .notEncoding:
            return "Not currently encoding"
        }
    }
}

extension RecordingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording already in progress"
        case .notRecording:
            return "Not currently recording"
        case .encodingFailed:
            return "Video encoding failed"
        case .captureFailed:
            return "Screen capture failed"
        }
    }
}
```

**Afternoon (1 PM - 5 PM)**
- **1:00-2:00** - Permission request UI (UI/UX Dev)
  - Create permission request dialog
  - Add helpful instructions
  - Link to System Settings

- **2:00-4:00** - Integrate error handling (All Developers)
  - Add error handling to all managers
  - Test all error scenarios
  - Verify user-friendly messages

- **4:00-5:00** - Error scenario testing (QA)
  - Test all error paths
  - Verify error messages
  - Test recovery workflows

**Deliverables:**
- Comprehensive error handling
- User-friendly error dialogs
- All error scenarios tested

---

### Day 18 (Wednesday): Performance Optimization

**Morning (9 AM - 12 PM)**
- **9:00-9:15** - Daily standup
- **9:15-12:00** - Encoding optimization (Senior Dev)

```swift
// Optimize VideoEncoder for performance

// Add hardware acceleration support
private func createVideoSettings() -> [String: Any] {
    let compressionProperties: [String: Any] = [
        AVVideoAverageBitRateKey: configuration.bitrate,
        AVVideoMaxKeyFrameIntervalKey: configuration.frameRate * 2,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoAllowFrameReorderingKey: false, // Reduce latency
        AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
        AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
    ]

    return [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: configuration.width,
        AVVideoHeightKey: configuration.height,
        AVVideoCompressionPropertiesKey: compressionProperties,
        AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
    ]
}

// Add frame queue for better buffering
class VideoEncoder {
    private var frameQueue: DispatchQueue
    private var processingQueue: DispatchQueue

    init(outputURL: URL, configuration: VideoConfiguration) {
        self.outputURL = outputURL
        self.configuration = configuration

        // Create dedicated queues
        self.frameQueue = DispatchQueue(
            label: "com.myrec.framequeue",
            qos: .userInitiated
        )
        self.processingQueue = DispatchQueue(
            label: "com.myrec.processing",
            qos: .userInitiated
        )
    }

    func encode(frame: CVPixelBuffer, presentationTime: CMTime) {
        frameQueue.async { [weak self] in
            self?.processFrame(frame, presentationTime: presentationTime)
        }
    }

    private func processFrame(_ frame: CVPixelBuffer, presentationTime: CMTime) {
        guard isEncoding,
              let videoInput = videoInput,
              let adaptor = pixelBufferAdaptor else {
            return
        }

        // Set start time on first frame
        if startTime == nil {
            startTime = presentationTime
            assetWriter?.startSession(atSourceTime: presentationTime)
        }

        // Wait for input to be ready (with timeout)
        let startWait = Date()
        while !videoInput.isReadyForMoreMediaData {
            if Date().timeIntervalSince(startWait) > 0.1 {
                print("⚠️ Frame dropped - input not ready")
                return
            }
            Thread.sleep(forTimeInterval: 0.001)
        }

        // Append pixel buffer
        if !adaptor.append(frame, withPresentationTime: presentationTime) {
            print("⚠️ Failed to append frame")
        }
    }
}
```

**Afternoon (1 PM - 5 PM)**
- **1:00-3:00** - Memory optimization (Senior Dev + QA)
  - Profile memory usage with Instruments
  - Fix memory leaks
  - Optimize buffer management
  - Reduce memory footprint

- **3:00-5:00** - CPU/GPU optimization (Senior Dev)
  - Profile with Instruments
  - Identify hot paths
  - Optimize critical sections
  - Test on Intel and Apple Silicon

**Deliverables:**
- Encoding performance optimized
- Memory leaks fixed
- CPU/GPU usage within targets

---

### Day 19 (Thursday): Phase 1 Completion Testing

**Morning (9 AM - 12 PM)**
- **9:00-9:15** - Daily standup
- **9:15-12:00** - Comprehensive testing (All Team)

**Test Suite:**

1. **Functional Testing**
   - [ ] System tray menu
   - [ ] Region selection
   - [ ] Countdown timer
   - [ ] Start recording
   - [ ] Stop recording
   - [ ] File save
   - [ ] Keyboard shortcuts
   - [ ] Settings persistence

2. **Performance Testing**
   - [ ] 1080P @ 30FPS (CPU < 25%)
   - [ ] 4K @ 60FPS (CPU < 40%)
   - [ ] 1-hour continuous recording
   - [ ] Memory stable over time
   - [ ] No frame drops

3. **Error Handling**
   - [ ] Permission denied
   - [ ] Insufficient disk space
   - [ ] Invalid save path
   - [ ] Recording failure
   - [ ] File corruption handling

4. **Compatibility**
   - [ ] macOS 12 (Monterey)
   - [ ] macOS 13 (Ventura)
   - [ ] macOS 14 (Sonoma)
   - [ ] Intel Mac
   - [ ] Apple Silicon Mac

**Afternoon (1 PM - 5 PM)**
- **1:00-3:00** - Bug fixing (All Developers)
  - Address critical issues
  - Fix failing tests
  - Polish edge cases

- **3:00-5:00** - Code review (All Developers)
  - Review all Phase 1 code
  - Ensure coding standards
  - Update documentation
  - Verify test coverage (target: 85%)

**Deliverables:**
- All Phase 1 tests passing
- Critical bugs fixed
- Code review complete

---

### Day 20 (Friday): Demo Prep & Phase 1 Review

**Morning (9 AM - 12 PM)**
- **9:00-9:15** - Daily standup
- **9:15-10:30** - Demo preparation (All Team)
  - Create demo script
  - Prepare test scenarios
  - Set up demo environment
  - Practice demo

- **10:30-12:00** - Documentation finalization (PM + Senior Dev)
  - Update README
  - Update architecture docs
  - Create user guide (Phase 1 features)
  - Document known limitations

**Afternoon (1 PM - 5 PM)**
- **1:00-2:00** - Stakeholder demo
  - Demonstrate all Phase 1 features
  - Show performance metrics
  - Discuss Phase 2 preview
  - Collect feedback

- **2:00-3:00** - Documentation (PM)
  - Phase 1 completion report
  - Metrics and KPIs
  - Budget vs actual
  - Phase 2 planning notes

- **3:00-4:30** - Phase 1 retrospective (All Team)
  - What went well
  - What could be improved
  - Lessons learned
  - Team feedback
  - Phase 2 preparation

- **4:30-5:00** - Week 4 wrap-up
  - Final checklist review
  - Celebrate Phase 1 completion
  - Preview Week 5 objectives

**Deliverables:**
- Stakeholder demo completed
- Phase 1 completion report
- Phase 1 retrospective document
- Team ready for Phase 2

---

## Phase 1 Completion Checklist

### Core Features
- [x] System tray integration with menu
- [x] Region selection with resize handles
- [x] Keyboard shortcuts (⌘⌥1, ⌘⌥2)
- [x] Settings bar UI (skeleton)
- [x] Countdown timer (3-2-1)
- [x] Screen capture (ScreenCaptureKit)
- [x] Video encoding (H.264, MP4)
- [x] Recording state machine
- [x] File save with atomic writes
- [x] Metadata extraction

### Quality
- [x] Unit tests: 85%+ coverage
- [x] Integration tests passing
- [x] Performance tests passing
- [x] No memory leaks
- [x] Error handling comprehensive
- [x] Code review complete

### Performance Targets Met
- [x] 1080P @ 30FPS: CPU < 25%
- [x] Memory < 250 MB during recording
- [x] No dropped frames
- [x] Audio/video sync ready (no audio yet)
- [x] App launch < 1 second

### Documentation
- [x] Architecture docs updated
- [x] API documentation
- [x] User guide (Phase 1)
- [x] Known issues documented
- [x] Phase 1 retrospective

---

## Metrics & Results

### Development Velocity
- Planned: 40 story points
- Actual: ___ story points
- Velocity: ___ points/week

### Code Quality
- Test coverage: ___%
- SwiftLint violations: ___
- Code review findings: ___

### Performance
- 1080P @ 30FPS CPU: ___%
- Memory usage: ___ MB
- Frame drop rate: ___%
- File size (1 min 1080P): ___ MB

### Timeline
- Planned: 4 weeks
- Actual: ___ weeks
- Variance: ___ days

---

## Known Issues & Limitations

### Phase 1 Limitations
1. **No Audio:** Audio capture not implemented (Phase 2)
2. **No Pause/Resume:** Not implemented (Phase 2)
3. **No Camera:** Camera preview not implemented (Phase 2)
4. **No Preview Window:** Post-recording preview not implemented (Phase 3)
5. **No Trim:** Video trimming not implemented (Phase 4)
6. **Basic Settings:** Settings bar is UI skeleton only

### Known Issues
- Document any bugs or issues found during testing

---

## Risks & Issues

### Resolved
- ScreenCaptureKit permission handling ✅
- Performance on Intel Macs ✅
- Atomic file writes ✅

### Ongoing
- Audio sync preparation for Phase 2
- Settings bar functionality (Phase 2)
- Preview window design (Phase 3)

---

## Team Performance

### Highlights
- List team achievements
- Successful implementations
- Challenges overcome

### Improvements for Phase 2
- Areas for improvement
- Process changes
- Tool additions

---

## Phase 2 Preview

**Week 5-8 Objectives:**
- Settings bar full functionality
- Pause/resume recording
- Audio capture (system audio + microphone)
- Camera preview overlay
- Recording controls in system tray
- Enhanced keyboard shortcuts

**Preparation Items:**
- [ ] Review Phase 2 requirements
- [ ] Team assignments for Week 5
- [ ] Architecture planning for audio
- [ ] UI designs for settings bar

---

## Budget Status

### Phase 1 Budget
- Planned: $53,500 (25% of total)
- Actual: $_____
- Variance: $_____

### Resource Utilization
- Senior Dev: ___ hours
- Mid-level Dev: ___ hours
- UI/UX Dev: ___ hours
- QA Engineer: ___ hours
- DevOps: ___ hours
- PM: ___ hours

---

## Stakeholder Communication

### Demo Agenda
1. Welcome & Phase 1 Overview (5 min)
2. Live Demo (15 min)
   - Region selection
   - Countdown timer
   - Recording workflow
   - File save and playback
3. Performance Metrics (5 min)
4. Known Limitations (5 min)
5. Phase 2 Preview (5 min)
6. Q&A (10 min)

### Success Criteria for Demo
- [ ] All features work smoothly
- [ ] No crashes or errors
- [ ] Performance metrics shown
- [ ] Stakeholders satisfied
- [ ] Approval for Phase 2

---

## Action Items for Week 5

### Immediate
- [ ] Begin Phase 2 planning
- [ ] Set up Week 5 tasks
- [ ] Review audio capture APIs
- [ ] Design settings bar functionality

### Long-term
- [ ] Continue Phase 1 bug fixes
- [ ] Monitor performance in production
- [ ] Collect user feedback (if early access)

---

**Prepared By:** Project Management Team
**Last Updated:** November 14, 2025
**Status:** ✅ Ready for Week 4 Start

---

## Celebration

**Phase 1 Milestone Achieved!** 🎉

The team has successfully delivered:
- Complete screen recording capability
- Professional-grade video encoding
- Solid foundation for advanced features
- High code quality and test coverage

**Thank you to the entire team for your hard work and dedication!**

Ready to move forward with Phase 2!
