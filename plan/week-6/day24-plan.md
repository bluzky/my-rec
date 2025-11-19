# Day 24 - Window Selection Integration

**Date:** November 20, 2025
**Goal:** Implement window-specific recording using ScreenCaptureKit window filtering
**Status:** ⏳ Pending

---

## Overview

Today we'll implement window selection, allowing users to record specific application windows instead of the entire screen or a custom region. This is a key feature that differentiates screen recorders.

**Current State:**
- ✅ Full screen recording works
- ✅ Region recording works (Day 23)
- ❌ No window selection capability

**Target State:**
- ✅ Users can see list of recordable windows
- ✅ Users can select specific window to record
- ✅ Recording captures only selected window
- ✅ Window is tracked even if moved

---

## Technical Approach

### 1. ScreenCaptureKit Window API

```swift
// Get shareable windows
let content = try await SCShareableContent.current

// Filter for windows (exclude desktop, menubar, etc.)
let windows = content.windows.filter { window in
    window.owningApplication != nil &&
    window.frame.width > 100 &&
    window.frame.height > 100 &&
    window.isOnScreen
}

// Create filter for specific window
let filter = SCContentFilter(
    desktopIndependentWindow: selectedWindow
)
```

### 2. Architecture

```
WindowPickerView (new)
    ↓ (selected SCWindow)
RecordingManager
    ↓ (window parameter)
ScreenCaptureEngine
    ↓ (SCContentFilter)
SCStream (captures window)
```

---

## Implementation Tasks

### Task 1: Create Window Model (30 min)

**File:** `Sources/MyRec/Models/RecordableWindow.swift` (new)

**Purpose:** Wrapper around SCWindow with display-friendly properties

```swift
import ScreenCaptureKit

struct RecordableWindow: Identifiable {
    let id: UUID
    let scWindow: SCWindow
    let title: String
    let owningApplication: String
    let frame: CGRect
    let thumbnail: NSImage?

    init(scWindow: SCWindow) {
        self.id = UUID()
        self.scWindow = scWindow
        self.title = scWindow.title ?? "Untitled"
        self.owningApplication = scWindow.owningApplication?.applicationName ?? "Unknown"
        self.frame = scWindow.frame
        self.thumbnail = nil  // Can add thumbnail generation later
    }

    var displayName: String {
        "\(owningApplication) - \(title)"
    }
}
```

---

### Task 2: Window Enumeration Service (60 min)

**File:** `Sources/MyRec/Services/WindowEnumerationService.swift` (new)

**Purpose:** Fetch and filter recordable windows

```swift
import ScreenCaptureKit

@MainActor
class WindowEnumerationService: ObservableObject {
    @Published var availableWindows: [RecordableWindow] = []
    @Published var isLoading = false
    @Published var error: Error?

    func refreshWindows() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let content = try await SCShareableContent.current

            let windows = content.windows
                .filter { isRecordableWindow($0) }
                .map { RecordableWindow(scWindow: $0) }
                .sorted { $0.displayName < $1.displayName }

            availableWindows = windows

        } catch {
            self.error = error
            print("Failed to enumerate windows: \(error)")
        }
    }

    private func isRecordableWindow(_ window: SCWindow) -> Bool {
        guard let app = window.owningApplication else { return false }

        // Filter criteria
        return window.isOnScreen &&
               window.frame.width >= 100 &&
               window.frame.height >= 100 &&
               window.title != nil &&
               !window.title!.isEmpty &&
               app.applicationName != "Window Server" &&
               app.applicationName != "Dock"
    }
}
```

**Features:**
- Async window enumeration
- Smart filtering (exclude system windows)
- Alphabetical sorting
- Error handling

---

### Task 3: Window Picker UI (90 min)

**File:** `Sources/MyRec/UI/WindowPickerView.swift` (new)

**Purpose:** Allow users to select a window from the list

```swift
import SwiftUI
import ScreenCaptureKit

struct WindowPickerView: View {
    @StateObject private var windowService = WindowEnumerationService()
    @Binding var selectedWindow: RecordableWindow?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Window to Record")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    Task { await windowService.refreshWindows() }
                }
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            // Window list
            if windowService.isLoading {
                ProgressView("Loading windows...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if windowService.availableWindows.isEmpty {
                Text("No recordable windows found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(windowService.availableWindows) { window in
                    WindowRowView(window: window)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedWindow = window
                            dismiss()
                        }
                }
            }
        }
        .frame(width: 500, height: 400)
        .task {
            await windowService.refreshWindows()
        }
    }
}

struct WindowRowView: View {
    let window: RecordableWindow

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 45)
                .overlay(
                    Image(systemName: "app.fill")
                        .foregroundColor(.white)
                )

            // Window info
            VStack(alignment: .leading, spacing: 4) {
                Text(window.owningApplication)
                    .font(.headline)
                Text(window.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("\(Int(window.frame.width)) × \(Int(window.frame.height))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}
```

**UI Features:**
- Window list with app name and title
- Dimensions display
- Refresh button
- Search/filter (optional for today)
- Thumbnail placeholders

---

### Task 4: Update ScreenCaptureEngine for Windows (60 min)

**File:** `Sources/MyRec/Services/ScreenCaptureEngine.swift`

**Changes:**
1. Add window capture mode
2. Support SCContentFilter with window
3. Handle window tracking

```swift
enum CaptureMode {
    case fullScreen
    case region(CGRect)
    case window(SCWindow)
}

class ScreenCaptureEngine: NSObject, ObservableObject {
    func startCapture(
        resolution: Resolution,
        frameRate: FrameRate,
        mode: CaptureMode  // Changed from optional region
    ) async throws {

        // Create appropriate content filter
        let contentFilter: SCContentFilter

        switch mode {
        case .fullScreen:
            contentFilter = createFullScreenFilter()

        case .region(let rect):
            contentFilter = createRegionFilter(rect: rect)

        case .window(let scWindow):
            contentFilter = SCContentFilter(
                desktopIndependentWindow: scWindow
            )
        }

        // Configure stream
        let streamConfig = SCStreamConfiguration()

        // For window mode, use window dimensions
        if case .window(let scWindow) = mode {
            streamConfig.width = Int(scWindow.frame.width)
            streamConfig.height = Int(scWindow.frame.height)
        } else {
            // Use resolution-based dimensions
            streamConfig.width = resolution.dimensions.width
            streamConfig.height = resolution.dimensions.height
        }

        // ... rest of stream setup
    }

    private func createFullScreenFilter() -> SCContentFilter {
        // Existing logic
    }

    private func createRegionFilter(rect: CGRect) -> SCContentFilter {
        // Day 23 logic
    }
}
```

---

### Task 5: Integrate Window Picker into Recording Flow (45 min)

**File:** `Sources/MyRec/UI/RegionSelectionWindow.swift`

**Changes:**
1. Add "Select Window" button to settings bar
2. Show window picker on click
3. Highlight selected window
4. Update recording flow

```swift
class RegionSelectionWindow: NSWindow {
    @State private var selectedWindow: RecordableWindow?
    @State private var showWindowPicker = false

    var settingsBar: some View {
        HStack {
            // Existing controls...

            Button("Select Window") {
                showWindowPicker = true
            }
            .sheet(isPresented: $showWindowPicker) {
                WindowPickerView(selectedWindow: $selectedWindow)
            }

            if let window = selectedWindow {
                Text("Recording: \(window.displayName)")
                    .font(.caption)
            }
        }
    }

    func startRecording() {
        let mode: CaptureMode

        if let window = selectedWindow {
            mode = .window(window.scWindow)
        } else if let region = customRegion {
            mode = .region(region)
        } else {
            mode = .fullScreen
        }

        Task {
            try await recordingManager.startRecording(
                settings: settingsManager.currentSettings,
                captureMode: mode
            )
        }
    }
}
```

---

### Task 6: Window Highlighting (Optional, 30 min)

**File:** `Sources/MyRec/UI/WindowHighlightOverlay.swift` (new)

**Purpose:** Visual feedback showing which window will be recorded

```swift
import SwiftUI

struct WindowHighlightOverlay: NSWindow {
    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.ignoresMouseEvents = true

        let overlayView = NSHostingView(
            rootView: Rectangle()
                .stroke(Color.red, lineWidth: 4)
        )
        self.contentView = overlayView
    }

    func updateFrame(_ newFrame: CGRect) {
        self.setFrame(newFrame, display: true)
    }
}
```

---

## Testing Plan

### Unit Tests (30 min)

**File:** `Tests/MyRecTests/WindowEnumerationTests.swift` (new)

```swift
import XCTest
@testable import MyRec

final class WindowEnumerationTests: XCTestCase {
    func testWindowFiltering() async throws {
        let service = WindowEnumerationService()
        await service.refreshWindows()

        // Should have at least one window (test runner or Xcode)
        XCTAssertFalse(service.availableWindows.isEmpty)

        // All windows should have valid properties
        for window in service.availableWindows {
            XCTAssertFalse(window.title.isEmpty)
            XCTAssertFalse(window.owningApplication.isEmpty)
            XCTAssertGreaterThan(window.frame.width, 100)
            XCTAssertGreaterThan(window.frame.height, 100)
        }
    }

    func testRecordableWindowModel() {
        // Create mock SCWindow
        // Test RecordableWindow initialization
        // Verify displayName formatting
    }
}
```

---

### Manual Testing (60 min)

**Test Scenarios:**

1. **Window enumeration:**
   - [ ] Open 5+ different apps
   - [ ] Refresh window list
   - [ ] Verify all apps appear
   - [ ] Check sorting is alphabetical

2. **Window selection:**
   - [ ] Select Safari window
   - [ ] Start recording
   - [ ] Verify only Safari is captured
   - [ ] Move Safari during recording
   - [ ] Verify window is tracked

3. **Window recording:**
   - [ ] Record small window (500x400)
   - [ ] Record large window (1920x1080)
   - [ ] Record window with transparency
   - [ ] Check output video dimensions match window

4. **Edge cases:**
   - [ ] Record minimized window (should fail gracefully)
   - [ ] Close window during recording
   - [ ] Switch to fullscreen app
   - [ ] Multi-display window

**Verification Checklist:**
- [ ] Window list populates correctly
- [ ] Selection persists across refreshes
- [ ] Recording captures correct window
- [ ] Window tracking works during movement
- [ ] Video output dimensions correct
- [ ] Error handling for edge cases

---

## Expected Outcomes

### Functional Outcomes
✅ Window picker UI functional
✅ Window enumeration working
✅ Window-specific recording works
✅ Window tracking during recording

### Technical Outcomes
✅ RecordableWindow model created
✅ WindowEnumerationService working
✅ ScreenCaptureEngine supports window mode
✅ UI integration complete

### Quality Metrics
- Zero errors/warnings
- All tests pass
- Manual scenarios pass
- No performance issues with window enumeration

---

## Blockers & Risks

### Potential Blockers
1. **ScreenCaptureKit window permissions:**
   - May require additional privacy permissions
   - Test on fresh system

2. **Window tracking complexity:**
   - Windows can move/resize during recording
   - May need to lock window dimensions

3. **Minimized/hidden windows:**
   - ScreenCaptureKit behavior unclear
   - Need fallback or validation

---

## Time Breakdown

| Task | Estimated | Actual |
|------|-----------|--------|
| Window model | 30 min | - |
| Enumeration service | 60 min | - |
| Window picker UI | 90 min | - |
| ScreenCaptureEngine update | 60 min | - |
| Integration | 45 min | - |
| Window highlighting | 30 min | - |
| Testing | 90 min | - |
| **Total** | **~6.5 hours** | - |

---

## Dependencies

### Required
- ✅ Day 23 region capture complete
- ✅ ScreenCaptureEngine
- ✅ RecordingManager

---

## Results (End of Day)

**Status:** Not started

**Completed:**
- [ ] Window model created
- [ ] Enumeration service working
- [ ] Window picker UI functional
- [ ] ScreenCaptureEngine updated
- [ ] Integration complete
- [ ] Tests passing

**Blockers:** None

**Next Day:** System audio capture

---

**Last Updated:** November 19, 2025
