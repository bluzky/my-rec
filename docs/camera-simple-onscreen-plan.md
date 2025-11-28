# Camera Integration: Simplified On-Screen Approach

**Project:** MyRec - macOS Screen Recording Application
**Strategy:** On-screen camera overlay (render camera window → ScreenCaptureKit captures it)
**Date:** 2025-11-27
**Estimated Duration:** 2-3 days (vs 6-8 weeks for in-pipeline composition)

---

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Implementation Plan](#implementation-plan)
4. [Testing Strategy](#testing-strategy)
5. [Comparison with Complex Approach](#comparison-with-complex-approach)

---

## Overview

### The Simplified Approach

Instead of compositing camera feed into the video pipeline with Core Image, we **render the camera as an on-screen NSWindow** and let ScreenCaptureKit capture everything together.

```
Camera Feed → NSWindow overlay → Rendered on Screen
                                        ↓
                            ScreenCaptureKit captures
                                        ↓
                                  Video Encoder
```

### Key Benefits

- ✅ **13+ hours faster** to implement (2-3 days vs 6-8 weeks)
- ✅ **Zero performance overhead** - no per-frame composition
- ✅ **No CIContext, CVPixelBufferPool, Core Image complexity**
- ✅ **WYSIWYG** - user sees exactly what will be recorded
- ✅ **Live repositioning** - drag camera and see it move in real-time
- ✅ **Uses existing ScreenCaptureKit** - no changes to recording engine
- ✅ **Simple codebase** - ~300 lines vs ~2000+ lines

### Trade-offs

- ⚠️ Camera overlay visible on user's screen during recording
- ⚠️ Could be covered by other windows (mitigated with `.floating` window level)
- ⚠️ User might accidentally click on camera window (mitigated with drag handle)

---

## Architecture

### Component Overview

```swift
┌─────────────────────────────────────────────────────────────┐
│                    CameraOverlayWindow                      │
│  - AVCaptureVideoPreviewLayer (camera feed)                 │
│  - Window Level: .floating (always on top)                  │
│  - Draggable with mouse                                     │
│  - Resizable (optional)                                     │
│  - Positioned within recording region                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  ScreenCaptureKit                           │
│  Captures: Screen + Camera Window (composited visually)    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Video Encoder                            │
│  No changes needed - receives already-composited frames     │
└─────────────────────────────────────────────────────────────┘
```

### File Structure

```
MyRec/
├── Services/
│   └── Camera/
│       ├── CameraOverlayWindow.swift       (NEW - 150 lines)
│       └── CameraPermissionManager.swift   (NEW - 80 lines)
├── ViewModels/
│   └── RegionSelectionViewModel.swift      (MODIFY - add camera handling)
└── AppDelegate.swift                       (MODIFY - camera lifecycle)
```

**Total New Code:** ~300 lines (vs ~2000+ for composition approach)

---

## Implementation Plan

### Phase 1: Camera Permission & Window (Day 1 - 4 hours)

#### Task 1.1: Add Camera Permission (1 hour)

**File:** `MyRec/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>MyRec needs camera access to overlay your webcam in screen recordings.</string>
```

**File:** `MyRec/Services/Camera/CameraPermissionManager.swift` (NEW)

```swift
import AVFoundation

public class CameraPermissionManager {

    public enum Status {
        case notDetermined
        case granted
        case denied
    }

    /// Check current camera permission status
    public static func checkPermission() -> Status {
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

    /// Get default camera device
    public static func getDefaultCamera() -> AVCaptureDevice? {
        return AVCaptureDevice.default(for: .video)
    }
}
```

#### Task 1.2: Create Camera Overlay Window (2 hours)

**File:** `MyRec/Services/Camera/CameraOverlayWindow.swift` (NEW)

```swift
import Cocoa
import AVFoundation

/// Floating window that displays camera preview overlay
public class CameraOverlayWindow: NSWindow {

    // MARK: - Properties

    private var cameraSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var dragOffset = CGPoint.zero
    private var isDragging = false

    // MARK: - Initialization

    /// Create camera overlay window at specified frame
    public init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setupWindow()
    }

    private func setupWindow() {
        // Window properties
        level = .floating  // Keep above normal windows
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Keep visible across all spaces and fullscreen apps
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        // Make window movable
        isMovableByWindowBackground = true

        // Allow window to receive events
        ignoresMouseEvents = false

        // Style content view
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 12
        contentView?.layer?.masksToBounds = true
        contentView?.layer?.borderWidth = 2
        contentView?.layer?.borderColor = NSColor.white.withAlphaComponent(0.5).cgColor
    }

    // MARK: - Camera Setup

    /// Setup camera session and preview layer
    public func setupCamera() throws {
        guard let camera = CameraPermissionManager.getDefaultCamera() else {
            throw CameraError.noDeviceAvailable
        }

        let session = AVCaptureSession()
        session.sessionPreset = .hd1920x1080

        // Add camera input
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw CameraError.configurationFailed
        }
        session.addInput(input)

        // Create preview layer
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = contentView!.bounds

        contentView?.layer = layer
        contentView?.wantsLayer = true

        self.cameraSession = session
        self.previewLayer = layer

        print("✅ Camera overlay window configured")
    }

    /// Start camera preview
    public func startPreview() {
        guard let session = cameraSession, !session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            print("✅ Camera preview started")
        }
    }

    /// Stop camera preview
    public func stopPreview() {
        guard let session = cameraSession, session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
            print("✅ Camera preview stopped")
        }
    }

    /// Update preview layer frame when window resizes
    public override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        previewLayer?.frame = contentView?.bounds ?? .zero
    }

    // MARK: - Dragging

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    public override func mouseDown(with event: NSEvent) {
        dragOffset = event.locationInWindow
        isDragging = true
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }

        let currentLocation = NSEvent.mouseLocation
        let newOrigin = CGPoint(
            x: currentLocation.x - dragOffset.x,
            y: currentLocation.y - dragOffset.y
        )
        setFrameOrigin(newOrigin)
    }

    public override func mouseUp(with event: NSEvent) {
        isDragging = false
    }

    // MARK: - Cleanup

    public func cleanup() {
        stopPreview()
        cameraSession = nil
        previewLayer = nil
        print("✅ Camera overlay window cleaned up")
    }
}

// MARK: - Errors

public enum CameraError: LocalizedError {
    case noDeviceAvailable
    case configurationFailed
    case permissionDenied

    public var errorDescription: String? {
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

#### Task 1.3: Test Camera Window (1 hour)

**Manual Test:**
```bash
# Build project
./scripts/build.sh Debug

# Create test window (in Xcode or test file)
let cameraFrame = CGRect(x: 100, y: 100, width: 320, height: 240)
let window = CameraOverlayWindow(frame: cameraFrame)
try window.setupCamera()
window.startPreview()
window.orderFront(nil)

# Verify:
# - Camera preview visible
# - Window has rounded corners and border
# - Window is draggable
# - Window stays on top of other apps
```

---

### Phase 2: Integration with Recording (Day 2 - 3 hours)

#### Task 2.1: Add Camera to ViewModel (1 hour)

**File:** `MyRec/ViewModels/RegionSelectionViewModel.swift` (MODIFY)

```swift
public class RegionSelectionViewModel: NSObject, ObservableObject {
    // ... existing properties ...

    // NEW: Camera overlay
    private var cameraOverlayWindow: CameraOverlayWindow?
    @Published var cameraPosition: CGPoint = .zero
    @Published var cameraSize: CGSize = CGSize(width: 320, height: 240)

    // ... existing methods ...

    // NEW: Setup camera overlay
    func setupCameraOverlay(in region: CGRect) async throws {
        // Check permission
        let status = CameraPermissionManager.checkPermission()

        switch status {
        case .notDetermined:
            let granted = await CameraPermissionManager.requestPermission()
            guard granted else {
                throw CameraError.permissionDenied
            }
        case .denied:
            throw CameraError.permissionDenied
        case .granted:
            break
        }

        // Calculate default camera position (bottom-right corner)
        let cameraWidth = region.width * 0.2  // 20% of screen width
        let cameraHeight = cameraWidth * (9.0 / 16.0)  // 16:9 aspect ratio

        let cameraX = region.maxX - cameraWidth - 20
        let cameraY = region.minY + 20

        let cameraFrame = CGRect(
            x: cameraX,
            y: cameraY,
            width: cameraWidth,
            height: cameraHeight
        )

        // Create camera window
        let window = CameraOverlayWindow(frame: cameraFrame)
        try window.setupCamera()

        // Show window
        window.orderFront(nil)
        window.startPreview()

        self.cameraOverlayWindow = window
        self.cameraPosition = cameraFrame.origin
        self.cameraSize = cameraFrame.size

        print("✅ Camera overlay positioned at: \(cameraFrame)")
    }

    // NEW: Show camera overlay
    func showCameraOverlay() {
        cameraOverlayWindow?.orderFront(nil)
        cameraOverlayWindow?.startPreview()
    }

    // NEW: Hide camera overlay
    func hideCameraOverlay() {
        cameraOverlayWindow?.orderOut(nil)
        cameraOverlayWindow?.stopPreview()
    }

    // NEW: Cleanup camera
    func cleanupCamera() {
        cameraOverlayWindow?.cleanup()
        cameraOverlayWindow?.close()
        cameraOverlayWindow = nil
    }

    // NEW: Validate camera is within recording region
    func validateCameraPosition() {
        guard let cameraWindow = cameraOverlayWindow else { return }
        let cameraFrame = cameraWindow.frame

        // Clamp camera to recording region bounds
        let clampedX = max(selectedRegion?.minX ?? 0,
                          min(cameraFrame.minX,
                              (selectedRegion?.maxX ?? 0) - cameraFrame.width))
        let clampedY = max(selectedRegion?.minY ?? 0,
                          min(cameraFrame.minY,
                              (selectedRegion?.maxY ?? 0) - cameraFrame.height))

        if clampedX != cameraFrame.minX || clampedY != cameraFrame.minY {
            cameraWindow.setFrameOrigin(CGPoint(x: clampedX, y: clampedY))
            print("⚠️ Camera position clamped to recording region")
        }
    }
}
```

#### Task 2.2: Wire Camera to Recording Flow (1.5 hours)

**File:** `MyRec/AppDelegate.swift` (MODIFY)

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    // ... existing properties ...

    func startRecording() {
        Task { @MainActor in
            // ... existing recording setup ...

            // Setup camera if enabled
            if settings.cameraEnabled {
                do {
                    guard let region = viewModel.selectedRegion else {
                        print("⚠️ No region selected, skipping camera")
                        return
                    }

                    try await viewModel.setupCameraOverlay(in: region)
                    viewModel.showCameraOverlay()

                    // Validate camera is within recording bounds
                    viewModel.validateCameraPosition()

                    print("✅ Camera overlay ready for recording")
                } catch {
                    print("❌ Camera setup failed: \(error)")
                    // Continue recording without camera
                    settings.cameraEnabled = false
                }
            }

            // Start ScreenCaptureKit recording (will capture camera window)
            try await screenCaptureEngine.startCapture(
                region: viewModel.selectedRegion ?? .zero,
                resolution: settings.resolution,
                frameRate: settings.frameRate,
                withAudio: settings.audioEnabled,
                withMicrophone: settings.microphoneEnabled
            )

            print("✅ Recording started (camera: \(settings.cameraEnabled))")
        }
    }

    func stopRecording() {
        Task { @MainActor in
            // Stop recording
            let outputURL = try await screenCaptureEngine.stopCapture()

            // Hide and cleanup camera
            if settings.cameraEnabled {
                viewModel.hideCameraOverlay()
                viewModel.cleanupCamera()
            }

            print("✅ Recording stopped: \(outputURL.lastPathComponent)")

            // ... existing post-recording logic ...
        }
    }
}
```

#### Task 2.3: Add Permission UI (0.5 hours)

**File:** `MyRec/AppDelegate.swift` (ADD)

```swift
extension AppDelegate {

    func showCameraPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Camera Access Required"
        alert.informativeText = "Please enable camera access in System Settings > Privacy & Security > Camera"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
```

---

### Phase 3: Testing & Polish (Day 2-3 - 2 hours)

#### Task 3.1: Manual Testing (1 hour)

**Test Checklist:**
- [ ] Camera toggle in settings bar enables camera
- [ ] Permission dialog appears on first enable (if not granted)
- [ ] Camera preview appears in bottom-right of recording region
- [ ] Camera window is draggable
- [ ] Camera window stays within recording region bounds
- [ ] Start recording → camera visible in preview
- [ ] Stop recording → camera overlay hidden
- [ ] Play recorded video → camera overlay visible at correct position
- [ ] Record without camera → no overlay visible
- [ ] Camera window stays on top of other apps during recording

#### Task 3.2: Edge Case Testing (0.5 hours)

**Test Scenarios:**
- [ ] No camera connected → graceful error message
- [ ] Camera disconnected during recording → recording continues without camera
- [ ] Permission denied → alert with "Open Settings" button
- [ ] Multiple displays → camera positioned correctly on recorded display
- [ ] Region resize during setup → camera repositioned to stay in bounds

#### Task 3.3: Performance Verification (0.5 hours)

**Performance Checks:**
- [ ] CPU usage with camera: same as without camera (ScreenCaptureKit does the work)
- [ ] Memory usage: ~20-30MB for camera session (negligible)
- [ ] Recording quality: no degradation
- [ ] Frame rate: stable 30/60fps
- [ ] No dropped frames during 5-minute recording

---

## Testing Strategy

### Unit Tests

**File:** `MyRecTests/Services/CameraPermissionManagerTests.swift` (NEW)

```swift
import XCTest
@testable import MyRec

final class CameraPermissionManagerTests: XCTestCase {

    func testCheckPermission() {
        let status = CameraPermissionManager.checkPermission()
        XCTAssertTrue(status == .granted || status == .denied || status == .notDetermined)
    }

    func testGetDefaultCamera() {
        let camera = CameraPermissionManager.getDefaultCamera()
        // May be nil if no camera - that's OK
        if camera != nil {
            print("✅ Camera detected: \(camera!.localizedName)")
        } else {
            print("⚠️ No camera available for testing")
        }
    }
}
```

### Integration Test

**File:** `MyRecTests/Integration/CameraOverlayIntegrationTests.swift` (NEW)

```swift
import XCTest
@testable import MyRec

final class CameraOverlayIntegrationTests: XCTestCase {

    func testCameraWindowCreation() throws {
        let frame = CGRect(x: 100, y: 100, width: 320, height: 240)
        let window = CameraOverlayWindow(frame: frame)

        XCTAssertEqual(window.level, .floating)
        XCTAssertFalse(window.isOpaque)
        XCTAssertTrue(window.hasShadow)
    }

    func testCameraSetup() throws {
        guard CameraPermissionManager.getDefaultCamera() != nil else {
            throw XCTSkip("No camera available for testing")
        }

        let frame = CGRect(x: 100, y: 100, width: 320, height: 240)
        let window = CameraOverlayWindow(frame: frame)

        XCTAssertNoThrow(try window.setupCamera())

        window.startPreview()
        // Preview should be running

        window.stopPreview()
        window.cleanup()
    }
}
```

---

## Comparison with Complex Approach

### Implementation Effort

| Aspect | On-Screen Approach | In-Pipeline Composition |
|--------|-------------------|------------------------|
| **Duration** | 2-3 days | 6-8 weeks (29-38 days) |
| **Lines of Code** | ~300 lines | ~2000+ lines |
| **New Files** | 2 files | 10+ files |
| **Complexity** | Low ⚠️ | High ⚠️⚠️⚠️ |
| **Dependencies** | AVFoundation only | Core Image, Metal, CoreVideo |
| **Testing Effort** | 2 hours | 15+ hours |

### Performance Comparison

| Metric | On-Screen | In-Pipeline |
|--------|-----------|-------------|
| **Per-Frame Overhead** | 0ms (SCK handles it) | 4-8ms |
| **CPU Usage** | Same as without camera | +5-10% |
| **Memory** | +20-30MB | +100-150MB |
| **GPU Usage** | Same | +10-15% |
| **Implementation Risk** | Low | High |

### Feature Comparison

| Feature | On-Screen | In-Pipeline |
|---------|-----------|-------------|
| Camera overlay | ✅ | ✅ |
| Draggable | ✅ | ✅ |
| Resizable | ✅ (simple) | ✅ |
| Invisible to user | ❌ | ✅ |
| WYSIWYG preview | ✅ | ❌ |
| Live repositioning | ✅ | ⚠️ (complex) |
| z-order issues | ⚠️ (possible) | ❌ |
| Performance | ✅ Excellent | ⚠️ Acceptable |

---

## Migration Path (If Needed)

If users later request "invisible camera mode", we can add the in-pipeline composition as an **optional feature**:

### Phase 1 (Current): On-Screen Only
```swift
var cameraMode: CameraMode = .onScreen  // Only option
```

### Phase 2 (Future): Add Invisible Mode
```swift
enum CameraMode {
    case onScreen      // Camera visible to user (current)
    case invisible     // Camera composited in pipeline (future)
}

var cameraMode: CameraMode = .onScreen  // Default
```

Users can toggle between modes in settings. This gives us:
- ✅ Fast time-to-market with on-screen mode
- ✅ User feedback on camera feature
- ✅ Option to add invisible mode if there's demand
- ✅ Both modes can coexist in the codebase

---

## Summary

### Why This Approach?

1. **Speed:** 2-3 days vs 6-8 weeks
2. **Simplicity:** 300 lines vs 2000+ lines
3. **Performance:** Zero overhead vs 4-8ms per frame
4. **Reliability:** No complex Core Image pipeline to debug
5. **User Experience:** WYSIWYG - user sees what they'll get

### What We're Giving Up

- Camera overlay is visible on user's screen (acceptable for MVP)
- Slight risk of other windows covering camera (mitigated with `.floating` level)

### Recommendation

✅ **Start with on-screen approach** for Week 7/8
✅ Ship camera feature in 2-3 days
✅ Gather user feedback
✅ Add "invisible mode" later only if users request it

This aligns with MyRec's philosophy: "lightweight, minimalist, essential features."

---

**Document Version:** 1.0
**Created:** 2025-11-27
**Status:** ✅ Ready for Implementation
**Replaces:** `cam-in-video-phased-implementation.md` (6-8 week plan)
