# Phase 1, Week 2: System Tray & Region Selection

**Duration:** Week 2 (Days 6-10)
**Phase:** Foundation & Core Recording
**Status:** Ready to Start
**Team Size:** 5 people

---

## Week Objectives

1. Implement system tray (NSStatusBar) with context menu
2. Create region selection overlay with resize handles
3. Build keyboard shortcuts manager for global hotkeys
4. Develop settings bar UI skeleton
5. Create ScreenCaptureKit proof-of-concept
6. Achieve 75%+ test coverage on new components

---

## Success Criteria

- [ ] System tray icon visible with working context menu
- [ ] Region selection overlay displays and responds to drag
- [ ] Resize handles functional on all 4 corners and 4 edges
- [ ] Real-time dimension feedback (width × height)
- [ ] Keyboard shortcuts (⌘⌥1, ⌘⌥2) registered and responding
- [ ] ScreenCaptureKit POC captures screen to preview
- [ ] Settings bar UI skeleton displays (no functionality yet)
- [ ] All unit tests passing with 75%+ coverage

---

## Daily Breakdown

### Day 6 (Monday): System Tray Implementation

**Morning (9 AM - 12 PM)**
- **9:00-9:15** - Daily standup
- **9:15-12:00** - StatusBarController implementation (Mid-level Dev)

```swift
// Services/StatusBar/StatusBarController.swift
class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    @Published var isRecording = false
    @Published var elapsedTime: TimeInterval = 0

    init() {
        setupStatusItem()
        buildMenu()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "record.circle",
                accessibilityDescription: "MyRec"
            )
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }
    }

    private func buildMenu() {
        menu = NSMenu()

        menu?.addItem(NSMenuItem(
            title: "Record Screen",
            action: #selector(recordScreen),
            keyEquivalent: ""
        ))

        menu?.addItem(NSMenuItem(
            title: "Record Audio",
            action: #selector(recordAudio),
            keyEquivalent: ""
        ))

        menu?.addItem(NSMenuItem(
            title: "Record Webcam",
            action: #selector(recordWebcam),
            keyEquivalent: ""
        ))

        menu?.addItem(NSMenuItem.separator())

        menu?.addItem(NSMenuItem(
            title: "Open Home Page",
            action: #selector(openHomePage),
            keyEquivalent: ""
        ))

        menu?.addItem(NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))

        menu?.addItem(NSMenuItem.separator())

        menu?.addItem(NSMenuItem(
            title: "Quit MyRec",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
    }

    @objc func statusBarButtonClicked() {
        // Toggle menu
    }

    @objc func recordScreen() {
        // Will trigger region selection
        NotificationCenter.default.post(
            name: .startRecording,
            object: nil
        )
    }

    @objc func recordAudio() { }
    @objc func recordWebcam() { }
    @objc func openHomePage() { }
    @objc func openSettings() { }
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func updateRecordingState(elapsed: TimeInterval) {
        isRecording = true
        elapsedTime = elapsed

        // Update status bar button
        if let button = statusItem?.button {
            let hours = Int(elapsed) / 3600
            let minutes = (Int(elapsed) % 3600) / 60
            let seconds = Int(elapsed) % 60
            button.title = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }

    func resetToIdle() {
        isRecording = false
        elapsedTime = 0

        if let button = statusItem?.button {
            button.title = ""
            button.image = NSImage(
                systemSymbolName: "record.circle",
                accessibilityDescription: "MyRec"
            )
        }
    }
}

// Notification names extension
extension Notification.Name {
    static let startRecording = Notification.Name("startRecording")
    static let stopRecording = Notification.Name("stopRecording")
    static let pauseRecording = Notification.Name("pauseRecording")
}
```

**Afternoon (1 PM - 5 PM)**
- **1:00-3:00** - StatusBarController testing (QA + Mid-level Dev)
  - Test menu display
  - Test menu item actions
  - Test icon changes
  - Test elapsed time display

- **3:00-5:00** - Integration with AppDelegate (Mid-level Dev)
  - Wire up StatusBarController to AppDelegate
  - Test on Intel and Apple Silicon
  - Handle edge cases (no menu bar space)

**Deliverables:**
- StatusBarController fully implemented
- System tray visible and functional
- Unit tests for StatusBarController

---

### Day 7 (Tuesday): Region Selection Overlay - Part 1

**Morning (9 AM - 12 PM)**
- **9:00-9:15** - Daily standup
- **9:15-12:00** - RegionSelectionView foundation (UI/UX Dev)

```swift
// Views/RegionSelection/RegionSelectionWindow.swift
class RegionSelectionWindow: NSWindow {
    init() {
        // Full screen transparent window
        let screen = NSScreen.main?.frame ?? .zero
        super.init(
            contentRect: screen,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        self.isOpaque = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false

        setupContentView()
    }

    private func setupContentView() {
        let hostingView = NSHostingView(
            rootView: RegionSelectionView()
        )
        self.contentView = hostingView
    }
}

// Views/RegionSelection/RegionSelectionView.swift
struct RegionSelectionView: View {
    @StateObject private var viewModel = RegionSelectionViewModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark overlay
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                // Selection rectangle
                if let region = viewModel.selectedRegion {
                    SelectionRectangle(
                        region: region,
                        onDrag: viewModel.updateRegion,
                        onResize: viewModel.resizeRegion
                    )
                }

                // Dimension label
                if let region = viewModel.selectedRegion {
                    DimensionLabel(
                        width: region.width,
                        height: region.height
                    )
                    .position(
                        x: region.minX + region.width / 2,
                        y: region.minY - 30
                    )
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewModel.handleDragChanged(value)
                    }
                    .onEnded { value in
                        viewModel.handleDragEnded(value)
                    }
            )
        }
    }
}

// ViewModels/RegionSelectionViewModel.swift
class RegionSelectionViewModel: ObservableObject {
    @Published var selectedRegion: CGRect?
    @Published var isDragging = false

    private var dragStartPoint: CGPoint?

    func handleDragChanged(_ value: DragGesture.Value) {
        if dragStartPoint == nil {
            dragStartPoint = value.startLocation
        }

        let start = dragStartPoint ?? value.startLocation
        let end = value.location

        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)

        selectedRegion = CGRect(x: minX, y: minY, width: width, height: height)
        isDragging = true
    }

    func handleDragEnded(_ value: DragGesture.Value) {
        isDragging = false
        dragStartPoint = nil
    }

    func updateRegion(_ newRegion: CGRect) {
        selectedRegion = newRegion
    }

    func resizeRegion(handle: ResizeHandle, delta: CGPoint) {
        guard var region = selectedRegion else { return }

        switch handle {
        case .topLeft:
            region.origin.x += delta.x
            region.origin.y += delta.y
            region.size.width -= delta.x
            region.size.height -= delta.y
        case .topRight:
            region.origin.y += delta.y
            region.size.width += delta.x
            region.size.height -= delta.y
        case .bottomLeft:
            region.origin.x += delta.x
            region.size.width -= delta.x
            region.size.height += delta.y
        case .bottomRight:
            region.size.width += delta.x
            region.size.height += delta.y
        case .top:
            region.origin.y += delta.y
            region.size.height -= delta.y
        case .bottom:
            region.size.height += delta.y
        case .left:
            region.origin.x += delta.x
            region.size.width -= delta.x
        case .right:
            region.size.width += delta.x
        }

        // Minimum size constraint
        if region.width >= 100 && region.height >= 100 {
            selectedRegion = region
        }
    }
}

enum ResizeHandle {
    case topLeft, topRight, bottomLeft, bottomRight
    case top, bottom, left, right
}
```

**Afternoon (1 PM - 5 PM)**
- **1:00-5:00** - Continue RegionSelectionView (UI/UX Dev)
  - Implement SelectionRectangle component
  - Add visual styling
  - Test dragging behavior
  - Handle edge cases (off-screen)

**Deliverables:**
- RegionSelectionWindow implemented
- Basic drag-to-select working
- Dimension display functional

---

### Day 8 (Wednesday): Region Selection Overlay - Part 2

**Morning (9 AM - 12 PM)**
- **9:00-9:15** - Daily standup
- **9:15-12:00** - Resize handles implementation (UI/UX Dev)

```swift
// Views/RegionSelection/SelectionRectangle.swift
struct SelectionRectangle: View {
    let region: CGRect
    let onDrag: (CGRect) -> Void
    let onResize: (ResizeHandle, CGPoint) -> Void

    @State private var isDragging = false

    var body: some View {
        ZStack {
            // Clear center (shows content)
            Rectangle()
                .stroke(Color.red, lineWidth: 2)
                .frame(width: region.width, height: region.height)
                .position(x: region.midX, y: region.midY)

            // Resize handles - Corners
            ResizeHandleView(handle: .topLeft)
                .position(x: region.minX, y: region.minY)
                .onDrag(handle: .topLeft)

            ResizeHandleView(handle: .topRight)
                .position(x: region.maxX, y: region.minY)
                .onDrag(handle: .topRight)

            ResizeHandleView(handle: .bottomLeft)
                .position(x: region.minX, y: region.maxY)
                .onDrag(handle: .bottomLeft)

            ResizeHandleView(handle: .bottomRight)
                .position(x: region.maxX, y: region.maxY)
                .onDrag(handle: .bottomRight)

            // Resize handles - Edges
            ResizeHandleView(handle: .top)
                .position(x: region.midX, y: region.minY)
                .onDrag(handle: .top)

            ResizeHandleView(handle: .bottom)
                .position(x: region.midX, y: region.maxY)
                .onDrag(handle: .bottom)

            ResizeHandleView(handle: .left)
                .position(x: region.minX, y: region.midY)
                .onDrag(handle: .left)

            ResizeHandleView(handle: .right)
                .position(x: region.maxX, y: region.midY)
                .onDrag(handle: .right)
        }
    }
}

struct ResizeHandleView: View {
    let handle: ResizeHandle

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Color.red, lineWidth: 2)
            )
            .cursor(cursorForHandle(handle))
    }

    func cursorForHandle(_ handle: ResizeHandle) -> NSCursor {
        switch handle {
        case .topLeft, .bottomRight:
            return NSCursor.resizeNorthwestSoutheast
        case .topRight, .bottomLeft:
            return NSCursor.resizeNortheastSouthwest
        case .top, .bottom:
            return NSCursor.resizeUpDown
        case .left, .right:
            return NSCursor.resizeLeftRight
        }
    }
}

// Custom view modifier for handle dragging
extension View {
    func onDrag(handle: ResizeHandle) -> some View {
        self.gesture(
            DragGesture()
                .onChanged { value in
                    // Notify parent of resize
                }
        )
    }
}

// Views/RegionSelection/DimensionLabel.swift
struct DimensionLabel: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Text("\(Int(width)) × \(Int(height))")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.7))
            )
    }
}
```

**Afternoon (1 PM - 5 PM)**
- **1:00-3:00** - Testing resize handles (QA + UI/UX Dev)
  - Test all 8 handles (4 corners + 4 edges)
  - Test minimum size constraints
  - Test edge of screen behavior
  - Performance testing with large regions

- **3:00-5:00** - Polish and refinements (UI/UX Dev)
  - Smooth cursor changes
  - Visual feedback improvements
  - Snap to grid (optional)
  - Keyboard adjustments (arrow keys)

**Deliverables:**
- All 8 resize handles working
- Visual polish complete
- Performance acceptable

---

### Day 9 (Thursday): Keyboard Shortcuts & Settings Bar UI

**Morning (9 AM - 12 PM)**
- **9:00-9:15** - Daily standup
- **9:15-12:00** - KeyboardShortcutManager (Mid-level Dev)

```swift
// Services/Keyboard/KeyboardShortcutManager.swift
class KeyboardShortcutManager {
    static let shared = KeyboardShortcutManager()

    private var eventMonitor: Any?
    private var shortcuts: [KeyboardShortcut: () -> Void] = [:]

    func register(
        shortcut: KeyboardShortcut,
        action: @escaping () -> Void
    ) {
        shortcuts[shortcut] = action
        setupGlobalMonitor()
    }

    private func setupGlobalMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode

        for (shortcut, action) in shortcuts {
            if shortcut.matches(modifiers: modifiers, keyCode: keyCode) {
                action()
            }
        }
    }

    func unregisterAll() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        shortcuts.removeAll()
    }
}

struct KeyboardShortcut: Hashable {
    let modifiers: NSEvent.ModifierFlags
    let keyCode: UInt16

    func matches(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> Bool {
        return self.modifiers == modifiers && self.keyCode == keyCode
    }

    // Predefined shortcuts
    static let startRecording = KeyboardShortcut(
        modifiers: [.command, .option],
        keyCode: 18 // 1
    )

    static let stopRecording = KeyboardShortcut(
        modifiers: [.command, .option],
        keyCode: 19 // 2
    )

    static let openSettings = KeyboardShortcut(
        modifiers: [.command, .option],
        keyCode: 43 // ,
    )
}
```

**Afternoon (1 PM - 5 PM)**
- **1:00-3:00** - Settings bar UI skeleton (UI/UX Dev)

```swift
// Views/SettingsBar/SettingsBarView.swift
struct SettingsBarView: View {
    @StateObject private var viewModel = SettingsBarViewModel()

    var body: some View {
        HStack(spacing: 8) {
            // Close button
            Button(action: { viewModel.close() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())

            Divider()

            // Size selector
            Menu {
                Button("Full Screen") { }
                Button("1920 × 1080") { }
                Button("1280 × 720") { }
                Button("Custom") { }
            } label: {
                Text("Size")
            }

            // Dimensions display
            TextField("Width", value: $viewModel.width, format: .number)
                .frame(width: 60)
            Text("×")
            TextField("Height", value: $viewModel.height, format: .number)
                .frame(width: 60)

            Divider()

            // Resolution dropdown
            Picker("", selection: $viewModel.resolution) {
                Text("4K").tag(Resolution.fourK)
                Text("2K").tag(Resolution.twoK)
                Text("1080P").tag(Resolution.fullHD)
                Text("720P").tag(Resolution.hd)
            }
            .frame(width: 80)

            // FPS dropdown
            Picker("", selection: $viewModel.frameRate) {
                Text("60 FPS").tag(60)
                Text("30 FPS").tag(30)
                Text("24 FPS").tag(24)
                Text("15 FPS").tag(15)
            }
            .frame(width: 80)

            Divider()

            // Toggle buttons
            ToggleButton(
                icon: "video.fill",
                isOn: $viewModel.cameraEnabled,
                tooltip: "Camera"
            )

            ToggleButton(
                icon: "speaker.wave.2.fill",
                isOn: $viewModel.audioEnabled,
                tooltip: "System Audio"
            )

            ToggleButton(
                icon: "mic.fill",
                isOn: $viewModel.microphoneEnabled,
                tooltip: "Microphone"
            )

            ToggleButton(
                icon: "cursorarrow",
                isOn: $viewModel.cursorEnabled,
                tooltip: "Show Cursor"
            )

            Divider()

            // Record button
            Button(action: { viewModel.startRecording() }) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(radius: 8)
        )
    }
}

struct ToggleButton: View {
    let icon: String
    @Binding var isOn: Bool
    let tooltip: String

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Image(systemName: icon)
                .foregroundColor(isOn ? .green : .gray)
        }
        .buttonStyle(PlainButtonStyle())
        .help(tooltip)
    }
}
```

- **3:00-5:00** - Settings bar positioning (UI/UX Dev)
  - Position near selected region
  - Auto-adjust if off-screen
  - Animation for show/hide

**Deliverables:**
- KeyboardShortcutManager functional
- Global shortcuts registered (⌘⌥1, ⌘⌥2)
- Settings bar UI displays (no functionality)

---

### Day 10 (Friday): ScreenCaptureKit POC & Testing

**Morning (9 AM - 12 PM)**
- **9:00-9:15** - Daily standup
- **9:15-12:00** - ScreenCaptureKit proof-of-concept (Senior Dev)

```swift
// Services/Capture/ScreenCapturePOC.swift
import ScreenCaptureKit

class ScreenCapturePOC {
    private var stream: SCStream?
    private var streamOutput: StreamOutput?

    func startCapture(region: CGRect) async throws {
        // Get available content
        let content = try await SCShareableContent.current

        // Get main display
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        // Configure filter
        let filter = SCContentFilter(
            display: display,
            excludingWindows: []
        )

        // Configure stream
        let configuration = SCStreamConfiguration()
        configuration.width = Int(region.width)
        configuration.height = Int(region.height)
        configuration.minimumFrameInterval = CMTime(
            value: 1,
            timescale: 30
        ) // 30 FPS
        configuration.queueDepth = 5

        // Create stream
        stream = SCStream(
            filter: filter,
            configuration: configuration,
            delegate: nil
        )

        // Create output handler
        streamOutput = StreamOutput()

        // Add stream output
        try stream?.addStreamOutput(
            streamOutput!,
            type: .screen,
            sampleHandlerQueue: .global()
        )

        // Start capture
        try await stream?.startCapture()

        print("✅ ScreenCaptureKit POC: Capture started")
    }

    func stopCapture() async throws {
        try await stream?.stopCapture()
        stream = nil
        print("✅ ScreenCaptureKit POC: Capture stopped")
    }
}

class StreamOutput: NSObject, SCStreamOutput {
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        // Process frame
        print("📹 Frame received")
    }
}

enum CaptureError: Error {
    case noDisplay
    case noPermission
    case captureFailed
}
```

**Afternoon (1 PM - 5 PM)**
- **1:00-2:00** - Test ScreenCaptureKit POC (Senior Dev + QA)
  - Test permission request
  - Test capture start/stop
  - Verify frames received
  - Test on different displays

- **2:00-3:30** - Week 2 comprehensive testing (All Devs + QA)
  - System tray full workflow
  - Region selection all interactions
  - Keyboard shortcuts
  - Settings bar display
  - Integration between components

- **3:30-4:30** - Code review (All Devs)
  - Review all Week 2 code
  - Address issues
  - Update documentation

- **4:30-5:00** - Week 2 retrospective
  - Achievements review
  - Challenges faced
  - Improvements for Week 3
  - Team feedback

**Deliverables:**
- ScreenCaptureKit POC working
- All Week 2 components tested
- Week 2 retrospective document

---

## Team Responsibilities

### Senior macOS Developer
- ScreenCaptureKit POC
- Architecture guidance for region selection
- Code review leadership
- Permission handling verification

### Mid-level Swift Developer
- StatusBarController complete implementation
- KeyboardShortcutManager
- Integration testing
- Bug fixes

### UI/UX Developer
- Region selection overlay (full implementation)
- Settings bar UI skeleton
- Visual polish and animations
- Cursor handling

### QA Engineer
- Test all Week 2 features
- Performance testing
- Edge case discovery
- Test automation expansion

### DevOps/Build Engineer
- CI/CD monitoring
- Build optimization
- Code signing preparation
- Documentation updates

### Project Manager
- Daily coordination
- Risk management
- Stakeholder updates
- Week 3 planning

---

## Testing Checklist

### System Tray
- [ ] Icon appears in menu bar
- [ ] Context menu displays on click
- [ ] All menu items present
- [ ] Menu items trigger correct actions
- [ ] Elapsed time displays correctly
- [ ] Icon changes during recording state
- [ ] Quit works properly

### Region Selection
- [ ] Overlay window displays full screen
- [ ] Drag-to-select creates region
- [ ] Region displays with red border
- [ ] Dimensions label shows correct size
- [ ] All 8 resize handles visible
- [ ] Resize handles work correctly
- [ ] Minimum size enforced (100×100)
- [ ] Cursor changes appropriately
- [ ] Performance smooth with large regions

### Keyboard Shortcuts
- [ ] ⌘⌥1 triggers startRecording notification
- [ ] ⌘⌥2 triggers stopRecording notification
- [ ] ⌘⌥, opens settings (placeholder)
- [ ] Global shortcuts work in any app
- [ ] No conflicts with system shortcuts

### Settings Bar
- [ ] Bar displays near region
- [ ] All controls visible
- [ ] Dropdowns show options
- [ ] Toggle buttons respond to clicks
- [ ] Record button visible
- [ ] Close button works

### ScreenCaptureKit POC
- [ ] Permission requested
- [ ] Capture starts without errors
- [ ] Frames received in callback
- [ ] Capture stops cleanly
- [ ] Works on multiple displays
- [ ] Works on Intel and Apple Silicon

---

## Deliverables Summary

### Code Components
- [x] StatusBarController with menu
- [x] RegionSelectionWindow & View
- [x] RegionSelectionViewModel with drag & resize
- [x] KeyboardShortcutManager
- [x] SettingsBarView skeleton
- [x] ScreenCaptureKit POC

### Tests
- [x] StatusBarController tests
- [x] RegionSelectionViewModel tests
- [x] KeyboardShortcut tests
- [x] Integration tests for Week 2 workflow

### Documentation
- [x] Week 2 retrospective
- [x] Updated architecture docs
- [x] API documentation for new components

---

## Risks & Mitigation

### Risk: ScreenCaptureKit permission issues
**Status:** Medium probability, High impact
**Mitigation:**
- Clear permission request UI
- Fallback to CGDisplayStream for macOS 12
- Test permission flow early
- Document troubleshooting steps

### Risk: Performance issues with large regions
**Status:** Low probability, Medium impact
**Mitigation:**
- Profile with Instruments
- Optimize rendering
- Test on older Intel Macs
- Set reasonable maximum region size

### Risk: Keyboard shortcut conflicts
**Status:** Low probability, Low impact
**Mitigation:**
- Make shortcuts customizable
- Check for common conflicts
- Provide alternative shortcuts
- Document in settings

---

## Metrics

### Code Coverage
- Target: 75%+ on new components
- StatusBarController: 80%
- RegionSelectionViewModel: 75%
- KeyboardShortcutManager: 70%

### Performance
- Region selection drag: 60 FPS
- Resize handle response: < 16ms
- Settings bar display: < 100ms
- Memory usage: < 80 MB

---

## Week 3 Preview

Next week focuses on:
- ScreenCaptureKit full integration
- Video encoding (H.264) implementation
- Countdown timer (3-2-1)
- Basic recording workflow
- File save functionality

---

**Prepared By:** Project Management Team
**Last Updated:** November 14, 2025
**Status:** ✅ Ready for Week 2 Start
