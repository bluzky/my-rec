# Day 20: ScreenCaptureKit + UI Integration (Logging Phase)

**Status:** 📋 Planned
**Focus:** Get screen capture working + Connect to UI + Log everything
**Goal:** See "Recording... Frame 1, Frame 2, Frame 3..." in status bar
**Time Estimate:** 6-8 hours

---

## Implementation Strategy

**Build → Integrate → Verify**

1. Build minimal ScreenCaptureEngine
2. Wire it to AppDelegate (replace mock)
3. Log frame captures to console + show in status bar
4. **NO encoding yet** - just verify capture works

---

## Tasks

### 1. ScreenCaptureEngine Implementation ✅ Target

**Create:** `MyRec/Services/Recording/ScreenCaptureEngine.swift`

```swift
import ScreenCaptureKit
import AVFoundation

/// Handles screen capture using ScreenCaptureKit (macOS 13+)
class ScreenCaptureEngine: NSObject, SCStreamDelegate, SCStreamOutput {
    // MARK: - Properties
    private var stream: SCStream?
    private var captureRegion: CGRect = .zero
    private var frameCount: Int = 0
    private var isCapturing = false
    private var startTime: CMTime?

    // MARK: - Callbacks
    var onFrameCaptured: ((Int, CMTime) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Public Interface
    func startCapture(region: CGRect, resolution: Resolution, frameRate: FrameRate) async throws {
        guard !isCapturing else { return }

        self.captureRegion = region
        self.frameCount = 0
        self.startTime = nil

        // Request permission and get shareable content
        try await requestPermissionIfNeeded()

        // Setup stream
        try await setupStream(resolution: resolution, frameRate: frameRate)

        isCapturing = true
        print("✅ ScreenCaptureEngine: Capture started")
    }

    func stopCapture() async throws {
        guard isCapturing else { return }

        try await stream?.stopCapture()
        stream = nil
        isCapturing = false

        print("✅ ScreenCaptureEngine: Capture stopped - \(frameCount) frames")
    }

    // MARK: - SCStreamOutput
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        frameCount += 1

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

    // MARK: - SCStreamDelegate
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("❌ ScreenCaptureEngine: Stream stopped with error: \(error)")
        onError?(error)
    }

    // MARK: - Private Methods
    private func setupStream(resolution: Resolution, frameRate: FrameRate) async throws {
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
        config.width = resolution.width
        config.height = resolution.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate.value))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.queueDepth = 5

        // Create stream
        stream = SCStream(filter: filter, configuration: config, delegate: self)

        // Add stream output
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())

        // Start capture
        try await stream?.startCapture()
    }

    private func requestPermissionIfNeeded() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard !content.displays.isEmpty else {
            throw CaptureError.permissionDenied
        }
    }
}

// MARK: - Errors
enum CaptureError: LocalizedError {
    case permissionDenied
    case captureUnavailable
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission denied. Please enable in System Settings > Privacy & Security > Screen Recording"
        case .captureUnavailable:
            return "Screen capture is unavailable. Please ensure macOS 13 or later."
        case .configurationFailed:
            return "Failed to configure screen capture."
        }
    }
}
```

**Key Features:**
- Minimal working capture
- Frame counting
- Logging via callback
- Permission handling
- Error reporting

**Files to Create:**
- `MyRec/Services/Recording/ScreenCaptureEngine.swift` (~150 lines)

---

### 2. UI Integration (AppDelegate) ✅ Target

**Modify:** `MyRec/AppDelegate.swift`

Add the following:

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    // ADD: Real capture engine
    private var captureEngine: ScreenCaptureEngine?
    private var frameCount: Int = 0

    @objc private func handleStartRecording() {
        Task { @MainActor in
            do {
                // Get region from UI
                let region = regionSelectionViewModel.selectedRegion
                let resolution = settingsManager.resolution
                let frameRate = settingsManager.frameRate

                print("📹 Starting capture...")
                print("  Region: \(region)")
                print("  Resolution: \(resolution.displayName)")
                print("  Frame Rate: \(frameRate.displayName)")

                // Create and start capture engine
                captureEngine = ScreenCaptureEngine()
                captureEngine?.onFrameCaptured = { [weak self] frame, time in
                    self?.handleFrameCaptured(frame: frame, time: time)
                }
                captureEngine?.onError = { [weak self] error in
                    self?.handleCaptureError(error)
                }

                try await captureEngine?.startCapture(
                    region: region,
                    resolution: resolution,
                    frameRate: frameRate
                )

                print("✅ Recording started - Region: \(region)")

            } catch {
                print("❌ Failed to start recording: \(error)")
                showError("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }

    @objc private func handleStopRecording() {
        Task { @MainActor in
            do {
                try await captureEngine?.stopCapture()
                print("✅ Recording stopped - Total frames: \(frameCount)")

                // Show mock preview for now (real video in Day 23)
                showMockPreview()

                // Reset
                frameCount = 0
                captureEngine = nil

            } catch {
                print("❌ Failed to stop recording: \(error)")
                showError("Failed to stop recording: \(error.localizedDescription)")
            }
        }
    }

    private func handleFrameCaptured(frame: Int, time: CMTime) {
        frameCount = frame

        // Log every 30 frames (once per second at 30fps)
        if frameCount % 30 == 0 {
            print("📹 Frame \(frameCount) captured at \(time.seconds)s")
        }

        // Update status bar with frame count
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .recordingFrameCaptured,
                object: nil,
                userInfo: ["frameCount": frameCount, "time": time.seconds]
            )
        }
    }

    private func handleCaptureError(_ error: Error) {
        print("❌ Capture error: \(error)")
        Task { @MainActor in
            showError("Recording error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let recordingFrameCaptured = Notification.Name("recordingFrameCaptured")
}
```

---

### 3. UI Feedback (StatusBarController) ✅ Target

**Modify:** `MyRec/Services/StatusBar/StatusBarController.swift`

Add frame count display to status bar:

```swift
private func setupNotificationObservers() {
    // ADD: Listen for frame captures
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleFrameCaptured),
        name: .recordingFrameCaptured,
        object: nil
    )

    // ... existing observers ...
}

@objc private func handleFrameCaptured(_ notification: Notification) {
    guard let frameCount = notification.userInfo?["frameCount"] as? Int,
          let time = notification.userInfo?["time"] as? Double else { return }

    // Show frame count in status bar
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    let formattedTime = String(format: "%02d:%02d", minutes, seconds)

    updateTitle("🔴 \(formattedTime) | Frames: \(frameCount)")
}
```

---

### 4. Manual Testing Checklist ✅ Target

**Test in this order:**

```
Permission Testing:
☐ 1. First launch → Permission dialog appears
☐ 2. Grant permission → Capture starts
☐ 3. Deny permission → Error shown with helpful message
☐ 4. Revoke permission in System Settings → Error on next capture

Capture Testing:
☐ 5. Start recording → Console shows "✅ Recording started"
☐ 6. Wait 5 seconds → Console shows "📹 Frame 30, 60, 90..." logs
☐ 7. Status bar updates → Shows "🔴 00:05 | Frames: 150"
☐ 8. Stop recording → Console shows "✅ Recording stopped - Total frames: X"

Region Selection:
☐ 9. Full screen → Logs show full screen dimensions
☐ 10. Custom region → Logs show custom dimensions
☐ 11. Different resolutions → Logs show scaling applied

Frame Rate Testing:
☐ 12. Set 30 FPS → ~30 frames logged per second
☐ 13. Set 60 FPS → ~60 frames logged per second
☐ 14. Set 15 FPS → ~15 frames logged per second

Performance:
☐ 15. CPU usage < 30% during capture
☐ 16. Memory usage < 200 MB
☐ 17. No frame drops (frame count increases steadily)
☐ 18. UI remains responsive during capture
```

---

## Success Criteria

**By end of Day 20, verify:**

- ✅ Permission request works correctly
- ✅ Screen capture starts/stops from UI
- ✅ Frame count increments correctly (visible in logs + status bar)
- ✅ Console shows frame logs every second
- ✅ Status bar shows elapsed time + frame count
- ✅ Different resolutions/frame rates work
- ✅ CPU/memory usage acceptable
- ✅ No crashes or errors during 1 minute capture

**Console Output Example:**
```
📹 Starting capture...
  Region: (0.0, 0.0, 1920.0, 1080.0)
  Resolution: 1080P
  Frame Rate: 30 FPS
✅ ScreenCaptureEngine: Capture started
✅ Recording started - Region: (0.0, 0.0, 1920.0, 1080.0)
📹 Frame 30 captured at 1.0s
📹 Frame 60 captured at 2.0s
📹 Frame 90 captured at 3.0s
📹 Frame 120 captured at 4.0s
📹 Frame 150 captured at 5.0s
...
✅ ScreenCaptureEngine: Capture stopped - 1800 frames
✅ Recording stopped - Total frames: 1800
```

---

## Common Issues & Troubleshooting

### Issue: Permission dialog doesn't appear
**Solution:** Check if app already has permission in System Settings > Privacy & Security > Screen Recording

### Issue: Capture starts but frame count doesn't increment
**Solution:** Check SCStreamOutput delegate is properly set up and `stream(_:didOutputSampleBuffer:)` is being called

### Issue: Frame rate is wrong
**Solution:** Verify `minimumFrameInterval` is calculated correctly: `CMTime(value: 1, timescale: CMTimeScale(frameRate.value))`

### Issue: High CPU usage
**Solution:** Ensure hardware acceleration is enabled and pixel format is set to `kCVPixelFormatType_32BGRA`

---

## Next Steps

After Day 20 is complete, proceed to **[Day 21: Video Encoding](day21-video-encoding.md)**

---

**Time Estimate:** 6-8 hours
**Status:** 📋 Planned
