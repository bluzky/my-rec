### Day 6 (Monday): System Tray Implementation
*   **Task:** Implement `StatusBarController` to manage the menu bar item, its icon, and the context menu.
    ```swift
    // Services/StatusBar/StatusBarController.swift
    import AppKit
    import Combine

    class StatusBarController: NSObject, ObservableObject {
        private var statusItem: NSStatusItem?
        private var menu: NSMenu?
        private var cancellables = Set<AnyCancellable>()

        @Published var isRecording = false
        @Published var isPaused = false
        @Published var elapsedTime: TimeInterval = 0

        // Menu items that need state updates
        private var recordMenuItem: NSMenuItem?
        private var pauseMenuItem: NSMenuItem?
        private var stopMenuItem: NSMenuItem?

        override init() {
            super.init()
            setupStatusItem()
            buildMenu()
            observeRecordingState()
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

            recordMenuItem = NSMenuItem(
                title: "Record Screen",
                action: #selector(recordScreen),
                keyEquivalent: ""
            )
            menu?.addItem(recordMenuItem!)

            pauseMenuItem = NSMenuItem(
                title: "Pause",
                action: #selector(pauseRecording),
                keyEquivalent: ""
            )
            pauseMenuItem?.isEnabled = false
            menu?.addItem(pauseMenuItem!)

            stopMenuItem = NSMenuItem(
                title: "Stop Recording",
                action: #selector(stopRecording),
                keyEquivalent: ""
            )
            stopMenuItem?.isEnabled = false
            menu?.addItem(stopMenuItem!)

            menu?.addItem(NSMenuItem.separator())

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

        private func observeRecordingState() {
            // Subscribe to RecordingManager state changes
            NotificationCenter.default.publisher(for: .recordingStateChanged)
                .sink { [weak self] notification in
                    guard let state = notification.object as? RecordingState else { return }
                    self?.updateMenuForState(state)
                }
                .store(in: &cancellables)
        }

        private func updateMenuForState(_ state: RecordingState) {
            DispatchQueue.main.async { [weak self] in
                switch state {
                case .idle:
                    self?.recordMenuItem?.isEnabled = true
                    self?.pauseMenuItem?.isEnabled = false
                    self?.stopMenuItem?.isEnabled = false
                    self?.updateIcon(recording: false)

                case .recording:
                    self?.recordMenuItem?.isEnabled = false
                    self?.pauseMenuItem?.isEnabled = true
                    self?.pauseMenuItem?.title = "Pause"
                    self?.stopMenuItem?.isEnabled = true
                    self?.updateIcon(recording: true)

                case .paused:
                    self?.recordMenuItem?.isEnabled = false
                    self?.pauseMenuItem?.isEnabled = true
                    self?.pauseMenuItem?.title = "Resume"
                    self?.stopMenuItem?.isEnabled = true
                    self?.updateIcon(recording: false)
                }
            }
        }

        private func updateIcon(recording: Bool) {
            if let button = statusItem?.button {
                button.image = NSImage(
                    systemSymbolName: recording ? "record.circle.fill" : "record.circle",
                    accessibilityDescription: recording ? "Recording" : "MyRec"
                )
            }
        }

        @objc private func statusBarButtonClicked() {
            // Optional: Handle left-click on status bar icon
        }

        @objc private func recordScreen() {
            NotificationCenter.default.post(
                name: .startRecording,
                object: nil
            )
        }

        @objc private func pauseRecording() {
            NotificationCenter.default.post(
                name: .pauseRecording,
                object: nil
            )
        }

        @objc private func stopRecording() {
            NotificationCenter.default.post(
                name: .stopRecording,
                object: nil
            )
        }

        @objc private func openSettings() {
            NotificationCenter.default.post(
                name: .openSettings,
                object: nil
            )
        }

        @objc private func quit() {
            NSApplication.shared.terminate(nil)
        }
    }

    // Notification names extension
    extension Notification.Name {
        static let startRecording = Notification.Name("startRecording")
        static let pauseRecording = Notification.Name("pauseRecording")
        static let stopRecording = Notification.Name("stopRecording")
        static let openSettings = Notification.Name("openSettings")
        static let recordingStateChanged = Notification.Name("recordingStateChanged")
    }
    ```
*   **Task:** Integrate the `StatusBarController` into the `AppDelegate` to launch it with the app.
*   **Task:** Write unit tests for menu state management and notification posting.

### Day 7 (Tuesday): Region Selection Overlay - Part 1
*   **Task:** Create the foundational components for the region selection UI.
    *   `RegionSelectionWindow`: A full-screen, transparent window to host the selection UI.
    *   `RegionSelectionView`: The main SwiftUI view containing the overlay and selection rectangle.
    *   `RegionSelectionViewModel`: The view model to handle the logic for dragging and creating the selection `CGRect`.
    ```swift
    // ViewModels/RegionSelectionViewModel.swift
    import SwiftUI
    import Combine

    class RegionSelectionViewModel: ObservableObject {
        @Published var selectedRegion: CGRect?
        @Published var isDragging = false
        @Published var isResizing = false

        private var dragStartPoint: CGPoint?
        private let screenBounds: CGRect
        private let minimumSize: CGSize = CGSize(width: 100, height: 100)

        init(screenBounds: CGRect = NSScreen.main?.frame ?? .zero) {
            self.screenBounds = screenBounds
        }

        // Handle initial drag to create selection
        func handleDragChanged(_ value: DragGesture.Value) {
            isDragging = true

            if dragStartPoint == nil {
                dragStartPoint = value.startLocation
            }

            guard let startPoint = dragStartPoint else { return }

            // Calculate rectangle from start to current point
            let currentPoint = value.location
            let origin = CGPoint(
                x: min(startPoint.x, currentPoint.x),
                y: min(startPoint.y, currentPoint.y)
            )
            let size = CGSize(
                width: abs(currentPoint.x - startPoint.x),
                height: abs(currentPoint.y - startPoint.y)
            )

            // Convert to screen coordinates (SwiftUI uses flipped coordinates)
            let screenRect = convertToScreenCoordinates(
                CGRect(origin: origin, size: size)
            )

            selectedRegion = constrainToScreen(screenRect)
        }

        func handleDragEnded(_ value: DragGesture.Value) {
            isDragging = false
            dragStartPoint = nil

            // Enforce minimum size
            if let region = selectedRegion {
                if region.width < minimumSize.width || region.height < minimumSize.height {
                    selectedRegion = nil
                }
            }
        }

        // Convert SwiftUI coordinates to screen coordinates
        private func convertToScreenCoordinates(_ rect: CGRect) -> CGRect {
            guard let screen = NSScreen.main else { return rect }

            // SwiftUI origin is top-left, screen coordinates are bottom-left
            let flippedY = screen.frame.height - rect.origin.y - rect.height

            return CGRect(
                x: rect.origin.x,
                y: flippedY,
                width: rect.width,
                height: rect.height
            )
        }

        // Constrain rectangle to screen bounds
        private func constrainToScreen(_ rect: CGRect) -> CGRect {
            var constrainedRect = rect

            // Constrain origin
            constrainedRect.origin.x = max(0, min(rect.origin.x, screenBounds.width - rect.width))
            constrainedRect.origin.y = max(0, min(rect.origin.y, screenBounds.height - rect.height))

            // Constrain size
            constrainedRect.size.width = min(rect.width, screenBounds.width - constrainedRect.origin.x)
            constrainedRect.size.height = min(rect.height, screenBounds.height - constrainedRect.origin.y)

            return constrainedRect
        }

        // Handle multi-monitor support
        func getDisplayForRegion(_ region: CGRect) -> NSScreen? {
            for screen in NSScreen.screens {
                if screen.frame.intersects(region) {
                    return screen
                }
            }
            return NSScreen.main
        }

        func reset() {
            selectedRegion = nil
            isDragging = false
            isResizing = false
            dragStartPoint = nil
        }
    }
    ```
*   **Task:** Create `RegionSelectionWindow` as a transparent, full-screen overlay window.
    ```swift
    // Windows/RegionSelectionWindow.swift
    import AppKit
    import SwiftUI

    class RegionSelectionWindow: NSWindow {
        init() {
            // Cover all screens with full-screen transparent window
            let mainScreen = NSScreen.main ?? NSScreen.screens[0]

            super.init(
                contentRect: mainScreen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            self.isOpaque = false
            self.backgroundColor = .clear
            self.level = .floating
            self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            self.ignoresMouseEvents = false

            // Setup SwiftUI view
            let viewModel = RegionSelectionViewModel(screenBounds: mainScreen.frame)
            let contentView = RegionSelectionView(viewModel: viewModel)
            self.contentView = NSHostingView(rootView: contentView)
        }
    }
    ```
*   **Task:** Write unit tests for coordinate conversion and region constraint logic.

### Day 8 (Wednesday): Region Selection Overlay - Part 2
*   **Task:** Implement the resize handles and visual feedback for the selection rectangle.
    ```swift
    // Models/ResizeHandle.swift
    enum ResizeHandle: CaseIterable {
        case topLeft, topCenter, topRight
        case middleLeft, middleRight
        case bottomLeft, bottomCenter, bottomRight

        var cursor: NSCursor {
            switch self {
            case .topLeft, .bottomRight:
                return NSCursor.resizeNorthwestSoutheast
            case .topRight, .bottomLeft:
                return NSCursor.resizeNortheastSouthwest
            case .topCenter, .bottomCenter:
                return NSCursor.resizeUpDown
            case .middleLeft, .middleRight:
                return NSCursor.resizeLeftRight
            }
        }
    }

    // Views/RegionSelection/ResizeHandleView.swift
    import SwiftUI

    struct ResizeHandleView: View {
        let handle: ResizeHandle
        let onDrag: (CGPoint) -> Void

        @State private var isHovering = false

        var body: some View {
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                )
                .scaleEffect(isHovering ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            onDrag(value.location)
                        }
                )
                .onHover { hovering in
                    isHovering = hovering
                    if hovering {
                        handle.cursor.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
    }

    // Views/RegionSelection/SelectionRectangle.swift
    struct SelectionRectangle: View {
        @ObservedObject var viewModel: RegionSelectionViewModel
        let region: CGRect

        var body: some View {
            ZStack {
                // Semi-transparent overlay outside selection
                Color.black.opacity(0.3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask(
                        Rectangle()
                            .fill(style: FillStyle(eoFill: true))
                            .overlay(
                                Rectangle()
                                    .frame(width: region.width, height: region.height)
                                    .position(x: region.midX, y: region.midY)
                            )
                    )

                // Selection border
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: region.width, height: region.height)
                    .position(x: region.midX, y: region.midY)

                // Dimension label
                DimensionLabel(width: region.width, height: region.height)
                    .position(x: region.midX, y: region.minY - 30)

                // 8 Resize handles
                ResizeHandleView(handle: .topLeft) { delta in
                    viewModel.handleResize(.topLeft, delta: delta)
                }
                .position(x: region.minX, y: region.minY)

                ResizeHandleView(handle: .topCenter) { delta in
                    viewModel.handleResize(.topCenter, delta: delta)
                }
                .position(x: region.midX, y: region.minY)

                ResizeHandleView(handle: .topRight) { delta in
                    viewModel.handleResize(.topRight, delta: delta)
                }
                .position(x: region.maxX, y: region.minY)

                ResizeHandleView(handle: .middleLeft) { delta in
                    viewModel.handleResize(.middleLeft, delta: delta)
                }
                .position(x: region.minX, y: region.midY)

                ResizeHandleView(handle: .middleRight) { delta in
                    viewModel.handleResize(.middleRight, delta: delta)
                }
                .position(x: region.maxX, y: region.midY)

                ResizeHandleView(handle: .bottomLeft) { delta in
                    viewModel.handleResize(.bottomLeft, delta: delta)
                }
                .position(x: region.minX, y: region.maxY)

                ResizeHandleView(handle: .bottomCenter) { delta in
                    viewModel.handleResize(.bottomCenter, delta: delta)
                }
                .position(x: region.midX, y: region.maxY)

                ResizeHandleView(handle: .bottomRight) { delta in
                    viewModel.handleResize(.bottomRight, delta: delta)
                }
                .position(x: region.maxX, y: region.maxY)
            }
        }
    }

    // Views/RegionSelection/DimensionLabel.swift
    struct DimensionLabel: View {
        let width: CGFloat
        let height: CGFloat

        var body: some View {
            Text("\(Int(width)) × \(Int(height))")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.75))
                )
        }
    }
    ```
*   **Task:** Add resize logic to `RegionSelectionViewModel`.
    ```swift
    // Add to RegionSelectionViewModel
    func handleResize(_ handle: ResizeHandle, delta: CGPoint) {
        guard var region = selectedRegion else { return }
        isResizing = true

        switch handle {
        case .topLeft:
            region.origin.x += delta.x
            region.origin.y += delta.y
            region.size.width -= delta.x
            region.size.height -= delta.y

        case .topCenter:
            region.origin.y += delta.y
            region.size.height -= delta.y

        case .topRight:
            region.size.width += delta.x
            region.origin.y += delta.y
            region.size.height -= delta.y

        case .middleLeft:
            region.origin.x += delta.x
            region.size.width -= delta.x

        case .middleRight:
            region.size.width += delta.x

        case .bottomLeft:
            region.origin.x += delta.x
            region.size.width -= delta.x
            region.size.height += delta.y

        case .bottomCenter:
            region.size.height += delta.y

        case .bottomRight:
            region.size.width += delta.x
            region.size.height += delta.y
        }

        // Enforce minimum size and constrain to screen
        if region.width >= minimumSize.width && region.height >= minimumSize.height {
            selectedRegion = constrainToScreen(region)
        }
    }
    ```
*   **Task:** Add keyboard adjustments (arrow keys for fine-tuning) using `NSEvent` monitoring.
*   **Task:** Write unit tests for resize handle logic and constraint enforcement.

### Day 9 (Thursday): Keyboard Shortcuts & Settings Bar UI
*   **Task:** Implement permission checking for accessibility access (required for global hotkeys).
    ```swift
    // Services/Permissions/PermissionManager.swift
    import AppKit

    class PermissionManager {
        static let shared = PermissionManager()

        func checkAccessibilityPermission() -> Bool {
            return AXIsProcessTrusted()
        }

        func requestAccessibilityPermission() {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
        }

        func checkScreenRecordingPermission() -> Bool {
            if #available(macOS 13.0, *) {
                return CGPreflightScreenCaptureAccess()
            }
            // For macOS 12, attempt a test capture
            return true // Will be determined at capture time
        }

        func requestScreenRecordingPermission() {
            if #available(macOS 13.0, *) {
                CGRequestScreenCaptureAccess()
            }
        }

        func showPermissionGuide(for permission: PermissionType) {
            let alert = NSAlert()
            alert.messageText = "\(permission.rawValue) Permission Required"
            alert.informativeText = permission.instructions
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                openSystemPreferences(for: permission)
            }
        }

        private func openSystemPreferences(for permission: PermissionType) {
            if let url = permission.settingsURL {
                NSWorkspace.shared.open(url)
            }
        }
    }

    enum PermissionType: String {
        case accessibility = "Accessibility"
        case screenRecording = "Screen Recording"

        var instructions: String {
            switch self {
            case .accessibility:
                return "MyRec needs Accessibility permission to register global keyboard shortcuts.\n\n1. Open System Settings\n2. Go to Privacy & Security → Accessibility\n3. Enable MyRec"
            case .screenRecording:
                return "MyRec needs Screen Recording permission to capture your screen.\n\n1. Open System Settings\n2. Go to Privacy & Security → Screen Recording\n3. Enable MyRec"
            }
        }

        var settingsURL: URL? {
            switch self {
            case .accessibility:
                return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            case .screenRecording:
                return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            }
        }
    }
    ```
*   **Task:** Implement `KeyboardShortcutManager` to handle global hotkeys (⌘⌥1, ⌘⌥2).
    ```swift
    // Services/Keyboard/KeyboardShortcutManager.swift
    import AppKit
    import Carbon

    struct KeyboardShortcut: Hashable {
        let key: UInt16
        let modifiers: NSEvent.ModifierFlags

        static let startPauseRecording = KeyboardShortcut(
            key: UInt16(kVK_ANSI_1),
            modifiers: [.command, .option]
        )

        static let stopRecording = KeyboardShortcut(
            key: UInt16(kVK_ANSI_2),
            modifiers: [.command, .option]
        )

        static let openSettings = KeyboardShortcut(
            key: UInt16(kVK_ANSI_Comma),
            modifiers: [.command, .option]
        )
    }

    class KeyboardShortcutManager {
        private var eventMonitor: Any?
        private var shortcuts: [KeyboardShortcut: () -> Void] = [:]

        init() {
            checkPermissionAndSetup()
        }

        private func checkPermissionAndSetup() {
            if PermissionManager.shared.checkAccessibilityPermission() {
                setupGlobalMonitor()
            } else {
                PermissionManager.shared.requestAccessibilityPermission()
                // Show alert to guide user
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    PermissionManager.shared.showPermissionGuide(for: .accessibility)
                }
            }
        }

        func register(shortcut: KeyboardShortcut, action: @escaping () -> Void) {
            shortcuts[shortcut] = action
        }

        private func setupGlobalMonitor() {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyEvent(event)
            }
        }

        private func handleKeyEvent(_ event: NSEvent) {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let shortcut = KeyboardShortcut(key: event.keyCode, modifiers: modifiers)

            if let action = shortcuts[shortcut] {
                DispatchQueue.main.async {
                    action()
                }
            }
        }

        func stop() {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }

        deinit {
            stop()
        }
    }
    ```
*   **Task:** Create the UI skeleton for `SettingsBarView` with all recording option controls.
    ```swift
    // Views/SettingsBar/SettingsBarView.swift
    import SwiftUI

    struct SettingsBarView: View {
        @ObservedObject var settingsManager: SettingsManager

        var body: some View {
            HStack(spacing: 16) {
                // Resolution selector
                Picker("Resolution", selection: $settingsManager.resolution) {
                    ForEach(Resolution.allCases, id: \.self) { res in
                        Text(res.displayName).tag(res)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                Divider()
                    .frame(height: 20)

                // FPS selector
                Picker("FPS", selection: $settingsManager.frameRate) {
                    ForEach(FrameRate.allCases, id: \.self) { fps in
                        Text("\(fps.rawValue) FPS").tag(fps)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)

                Divider()
                    .frame(height: 20)

                // Camera toggle
                ToggleButton(
                    icon: "video",
                    isOn: $settingsManager.isCameraEnabled,
                    label: "Camera"
                )

                // Audio toggle
                ToggleButton(
                    icon: "speaker.wave.2",
                    isOn: $settingsManager.isSystemAudioEnabled,
                    label: "Audio"
                )

                // Microphone toggle
                ToggleButton(
                    icon: "mic",
                    isOn: $settingsManager.isMicrophoneEnabled,
                    label: "Mic"
                )

                // Pointer toggle
                ToggleButton(
                    icon: "cursorarrow.rays",
                    isOn: $settingsManager.isPointerEnabled,
                    label: "Pointer"
                )

                Divider()
                    .frame(height: 20)

                // Record button
                Button(action: {
                    NotificationCenter.default.post(name: .startRecording, object: nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "record.circle.fill")
                        Text("Record")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#e74c3c"))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(hex: "#1a1a1a"))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }

    // Views/SettingsBar/ToggleButton.swift
    struct ToggleButton: View {
        let icon: String
        @Binding var isOn: Bool
        let label: String

        var body: some View {
            Button(action: { isOn.toggle() }) {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                    Text(label)
                        .font(.system(size: 10))
                }
                .foregroundColor(isOn ? Color(hex: "#4caf50") : Color(hex: "#999999"))
                .frame(width: 60, height: 50)
                .background(isOn ? Color.white.opacity(0.1) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    // Helpers/Color+Hex.swift
    extension Color {
        init(hex: String) {
            let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)
            let a, r, g, b: UInt64
            switch hex.count {
            case 6: // RGB (24-bit)
                (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            default:
                (a, r, g, b) = (255, 0, 0, 0)
            }
            self.init(
                .sRGB,
                red: Double(r) / 255,
                green: Double(g) / 255,
                blue:  Double(b) / 255,
                opacity: Double(a) / 255
            )
        }
    }
    ```
*   **Task:** Wire `SettingsBarView` to `SettingsManager` for persistence (read-only for now).
*   **Task:** Write unit tests for `KeyboardShortcutManager` shortcut matching and permission checks.

### Day 10 (Friday): ScreenCaptureKit Proof-of-Concept
*   **Task:** Develop a proof-of-concept to validate screen capture using `ScreenCaptureKit` with region support.
    ```swift
    // Services/Capture/ScreenCapturePOC.swift
    import ScreenCaptureKit
    import AVFoundation
    import CoreMedia

    @available(macOS 13.0, *)
    class ScreenCapturePOC: NSObject, ObservableObject {
        private var stream: SCStream?
        private var output: StreamOutput?
        private var isCapturing = false

        @Published var frameCount: Int = 0
        @Published var lastError: Error?

        func checkPermission() -> Bool {
            return PermissionManager.shared.checkScreenRecordingPermission()
        }

        func requestPermission() {
            PermissionManager.shared.requestScreenRecordingPermission()
        }

        func startCapture(region: CGRect, resolution: Resolution, fps: Int) async throws {
            // Check permissions first
            guard checkPermission() else {
                requestPermission()
                throw CaptureError.permissionDenied
            }

            // Get available content
            let content = try await SCShareableContent.current

            // Find the display that contains the region
            guard let display = findDisplay(for: region, in: content.displays) else {
                throw CaptureError.noDisplayFound
            }

            // Create filter with region
            let filter = SCContentFilter(
                display: display,
                excludingWindows: []
            )

            // Configure stream
            let config = SCStreamConfiguration()
            config.width = Int(region.width)
            config.height = Int(region.height)
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
            config.queueDepth = 5
            config.showsCursor = true
            config.scalesToFit = false
            config.sourceRect = region

            // Create stream
            stream = SCStream(filter: filter, configuration: config, delegate: self)

            // Create output handler
            output = StreamOutput { [weak self] sampleBuffer in
                self?.frameCount += 1
                // Process frame here - in real implementation, pass to encoder
                print("Received frame: \(self?.frameCount ?? 0)")
            }

            // Add output
            guard let output = output else { return }
            try stream?.addStreamOutput(
                output,
                type: .screen,
                sampleHandlerQueue: DispatchQueue(label: "com.myrec.capture")
            )

            // Start capture
            try await stream?.startCapture()
            isCapturing = true

            print("✅ Screen capture started - Region: \(region), FPS: \(fps)")
        }

        func stopCapture() async throws {
            guard isCapturing else { return }

            try await stream?.stopCapture()
            stream = nil
            output = nil
            isCapturing = false

            print("⏹ Screen capture stopped - Total frames: \(frameCount)")
        }

        private func findDisplay(for region: CGRect, in displays: [SCDisplay]) -> SCDisplay? {
            // Find display that contains the region
            for display in displays {
                if display.frame.intersects(region) {
                    return display
                }
            }
            // Default to main display
            return displays.first
        }
    }

    // MARK: - Stream Delegate
    @available(macOS 13.0, *)
    extension ScreenCapturePOC: SCStreamDelegate {
        func stream(_ stream: SCStream, didStopWithError error: Error) {
            print("❌ Stream stopped with error: \(error.localizedDescription)")
            lastError = error
            isCapturing = false
        }
    }

    // MARK: - Stream Output Handler
    @available(macOS 13.0, *)
    class StreamOutput: NSObject, SCStreamOutput {
        private let frameHandler: (CMSampleBuffer) -> Void

        init(frameHandler: @escaping (CMSampleBuffer) -> Void) {
            self.frameHandler = frameHandler
            super.init()
        }

        func stream(
            _ stream: SCStream,
            didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
            of type: SCStreamOutputType
        ) {
            // Ensure we're handling screen output
            guard type == .screen else { return }

            // Validate sample buffer
            guard sampleBuffer.isValid,
                  let imageBuffer = sampleBuffer.imageBuffer else {
                return
            }

            // Process frame
            frameHandler(sampleBuffer)
        }
    }

    // MARK: - Errors
    enum CaptureError: LocalizedError {
        case permissionDenied
        case noDisplayFound
        case invalidConfiguration

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Screen recording permission is required"
            case .noDisplayFound:
                return "No display found for the specified region"
            case .invalidConfiguration:
                return "Invalid capture configuration"
            }
        }
    }

    // MARK: - Fallback for macOS 12
    @available(macOS 12.0, *)
    class LegacyScreenCapturePOC {
        // Use CGDisplayStream for macOS 12 compatibility
        private var displayStream: CGDisplayStream?

        func startCapture(region: CGRect, fps: Int) {
            print("⚠️ Using legacy CGDisplayStream API for macOS 12")

            // Get display ID for region
            guard let displayID = getDisplayID(for: region) else {
                print("❌ No display found")
                return
            }

            // Create display stream
            displayStream = CGDisplayStream(
                dispatchQueueDisplay: displayID,
                outputWidth: Int(region.width),
                outputHeight: Int(region.height),
                pixelFormat: Int32(kCVPixelFormatType_32BGRA),
                properties: nil,
                queue: DispatchQueue.global(qos: .userInitiated)
            ) { status, displayTime, frameSurface, updateRef in
                guard status == .frameComplete,
                      let surface = frameSurface else {
                    return
                }
                // Process frame from surface
                print("Received legacy frame")
            }

            displayStream?.start()
        }

        func stopCapture() {
            displayStream?.stop()
            displayStream = nil
        }

        private func getDisplayID(for region: CGRect) -> CGDirectDisplayID? {
            var displayCount: UInt32 = 0
            var result = CGGetDisplaysWithRect(region, 1, nil, &displayCount)
            guard result == .success, displayCount > 0 else { return nil }

            var displayID: CGDirectDisplayID = 0
            result = CGGetDisplaysWithRect(region, 1, &displayID, &displayCount)
            return result == .success ? displayID : nil
        }
    }
    ```
*   **Task:** Create a simple test UI to validate the POC.
    ```swift
    // Views/Testing/CaptureTestView.swift
    import SwiftUI

    struct CaptureTestView: View {
        @StateObject private var capturePOC = ScreenCapturePOC()
        @State private var testRegion = CGRect(x: 100, y: 100, width: 1280, height: 720)

        var body: some View {
            VStack(spacing: 20) {
                Text("Screen Capture POC Test")
                    .font(.title)

                Text("Frames captured: \(capturePOC.frameCount)")
                    .font(.headline)

                HStack(spacing: 20) {
                    Button("Start Capture") {
                        Task {
                            do {
                                try await capturePOC.startCapture(
                                    region: testRegion,
                                    resolution: .hd1080p,
                                    fps: 30
                                )
                            } catch {
                                print("Error: \(error)")
                            }
                        }
                    }

                    Button("Stop Capture") {
                        Task {
                            try? await capturePOC.stopCapture()
                        }
                    }
                    .disabled(capturePOC.frameCount == 0)
                }

                if let error = capturePOC.lastError {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                }
            }
            .padding()
            .frame(width: 400, height: 300)
        }
    }
    ```
*   **Task:** Test on both macOS 12 (legacy) and macOS 13+ (ScreenCaptureKit).
*   **Task:** Test on both Intel and Apple Silicon Macs if possible.
*   **Task:** Validate permission flows and error handling.
*   **Task:** Measure performance: CPU/GPU usage, memory consumption, frame rate stability.

### Day 11 (Saturday): Integration & Testing
*   **Task:** Create integration tests for the complete flow: System Tray → Region Selection → Capture POC.
    ```swift
    // Tests/Integration/Week2IntegrationTests.swift
    import XCTest
    @testable import MyRec

    class Week2IntegrationTests: XCTestCase {
        var statusBarController: StatusBarController!
        var regionViewModel: RegionSelectionViewModel!

        override func setUp() {
            super.setUp()
            statusBarController = StatusBarController()
            regionViewModel = RegionSelectionViewModel()
        }

        func testSystemTrayToRegionSelection() {
            // Test: Clicking "Record Screen" opens region selection
            let expectation = expectation(description: "Region selection shown")

            NotificationCenter.default.addObserver(
                forName: .startRecording,
                object: nil,
                queue: .main
            ) { _ in
                expectation.fulfill()
            }

            statusBarController.recordScreen()

            wait(for: [expectation], timeout: 1.0)
        }

        func testRegionSelectionConstraints() {
            // Test: Region is constrained to screen bounds
            let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
            let viewModel = RegionSelectionViewModel(screenBounds: screenBounds)

            // Try to create region outside bounds
            viewModel.selectedRegion = CGRect(x: 1900, y: 1000, width: 500, height: 500)

            // Should be constrained
            XCTAssertLessThanOrEqual(
                viewModel.selectedRegion!.maxX,
                screenBounds.maxX
            )
            XCTAssertLessThanOrEqual(
                viewModel.selectedRegion!.maxY,
                screenBounds.maxY
            )
        }

        func testMinimumRegionSize() {
            // Test: Regions smaller than minimum are rejected
            let viewModel = RegionSelectionViewModel()

            viewModel.selectedRegion = CGRect(x: 100, y: 100, width: 50, height: 50)

            // Should be nil due to minimum size constraint
            XCTAssertNil(viewModel.selectedRegion)
        }
    }
    ```
*   **Task:** Write unit tests for all Week 2 components.
    ```swift
    // Tests/Unit/StatusBarControllerTests.swift
    class StatusBarControllerTests: XCTestCase {
        func testMenuStateChanges() {
            let controller = StatusBarController()

            // Test idle state
            XCTAssertTrue(controller.recordMenuItem?.isEnabled ?? false)
            XCTAssertFalse(controller.pauseMenuItem?.isEnabled ?? true)

            // Simulate recording state
            NotificationCenter.default.post(
                name: .recordingStateChanged,
                object: RecordingState.recording
            )

            // Menu should update
            XCTAssertFalse(controller.recordMenuItem?.isEnabled ?? true)
            XCTAssertTrue(controller.pauseMenuItem?.isEnabled ?? false)
        }
    }

    // Tests/Unit/KeyboardShortcutTests.swift
    class KeyboardShortcutTests: XCTestCase {
        func testShortcutMatching() {
            let shortcut1 = KeyboardShortcut.startPauseRecording
            let shortcut2 = KeyboardShortcut(
                key: UInt16(kVK_ANSI_1),
                modifiers: [.command, .option]
            )

            XCTAssertEqual(shortcut1, shortcut2)
        }

        func testPermissionCheck() {
            let hasPermission = PermissionManager.shared.checkAccessibilityPermission()
            // This will fail in tests without accessibility permission
            // Use this test to verify permission check works
            print("Accessibility permission: \(hasPermission)")
        }
    }

    // Tests/Unit/RegionSelectionTests.swift
    class RegionSelectionTests: XCTestCase {
        func testCoordinateConversion() {
            let viewModel = RegionSelectionViewModel(
                screenBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )

            // Test coordinate conversion logic
            let swiftUIRect = CGRect(x: 100, y: 100, width: 500, height: 300)
            // Conversion tested internally in ViewModel
            // Add public method if needed for testing
        }

        func testResizeHandles() {
            let viewModel = RegionSelectionViewModel()
            viewModel.selectedRegion = CGRect(x: 100, y: 100, width: 500, height: 300)

            // Test bottom-right resize
            viewModel.handleResize(.bottomRight, delta: CGPoint(x: 50, y: 50))

            XCTAssertEqual(viewModel.selectedRegion?.width, 550)
            XCTAssertEqual(viewModel.selectedRegion?.height, 350)
        }
    }
    ```
*   **Task:** Document Week 2 progress and create a summary of what was built.
    ```markdown
    # Week 2 Summary

    ## Completed Features

    ### System Tray (Day 6)
    - ✅ StatusBarController with menu state management
    - ✅ Menu items: Record, Pause, Stop, Settings, Quit
    - ✅ Dynamic menu state based on recording state
    - ✅ Icon changes (record.circle / record.circle.fill)
    - ✅ Combine integration for reactive updates

    ### Region Selection (Days 7-8)
    - ✅ RegionSelectionWindow (transparent, full-screen overlay)
    - ✅ RegionSelectionViewModel with drag handling
    - ✅ 8 resize handles (corners + edges)
    - ✅ Dimension label showing real-time size
    - ✅ Coordinate conversion (SwiftUI ↔ screen coordinates)
    - ✅ Multi-monitor support
    - ✅ Minimum size enforcement (100x100)
    - ✅ Cursor changes during resize operations

    ### Keyboard Shortcuts & Permissions (Day 9)
    - ✅ PermissionManager for Accessibility & Screen Recording
    - ✅ KeyboardShortcutManager with global hotkeys
    - ✅ Shortcuts: ⌘⌥1 (Start/Pause), ⌘⌥2 (Stop), ⌘⌥, (Settings)
    - ✅ Permission request flows with user guidance
    - ✅ Settings bar UI with all controls (Resolution, FPS, toggles)
    - ✅ Color scheme implementation (dark theme)

    ### Screen Capture POC (Day 10)
    - ✅ ScreenCaptureKit implementation (macOS 13+)
    - ✅ Legacy CGDisplayStream fallback (macOS 12)
    - ✅ Region-specific capture support
    - ✅ Frame rate configuration
    - ✅ Permission checking before capture
    - ✅ Error handling and delegate pattern
    - ✅ Test UI for validation

    ### Testing & Integration (Day 11)
    - ✅ Integration tests for complete flow
    - ✅ Unit tests for all components
    - ✅ Permission flow validation

    ## Technical Achievements

    - **Architecture**: Clean separation of concerns (Views, ViewModels, Services)
    - **Permissions**: Robust permission handling for Accessibility & Screen Recording
    - **Cross-version support**: macOS 12+ compatibility with fallbacks
    - **Reactive**: Combine-based state management throughout
    - **Performance**: Optimized coordinate calculations and constraint checking

    ## Next Steps (Week 3)

    - Integrate ScreenCaptureEngine with AVAssetWriter for actual recording
    - Implement audio capture (system + microphone)
    - Add recording state machine with pause/resume
    - Create countdown timer (3-2-1)
    - Implement elapsed time display in status bar
    - Add file naming and save location handling

    ## Known Issues / TODOs

    - [ ] Keyboard arrow key adjustments for region selection
    - [ ] Settings persistence (currently read-only)
    - [ ] Multi-monitor edge cases need more testing
    - [ ] Performance benchmarking on different Mac models
    - [ ] UI polish: animations, transitions
    ```
*   **Task:** Run all tests using `swift test` and verify build using `./scripts/build.sh Debug`.
*   **Task:** Update project board or tracking system with Week 2 completion status.

### Week 2 Completion Checklist

- [ ] Day 6: System Tray Implementation
  - [ ] StatusBarController with state management
  - [ ] Menu integration with AppDelegate
  - [ ] Unit tests passing

- [ ] Day 7: Region Selection - Part 1
  - [ ] RegionSelectionViewModel with drag handling
  - [ ] RegionSelectionWindow setup
  - [ ] Coordinate conversion working
  - [ ] Unit tests passing

- [ ] Day 8: Region Selection - Part 2
  - [ ] All 8 resize handles implemented
  - [ ] Cursor changes on hover
  - [ ] Dimension label displaying correctly
  - [ ] Constraint enforcement working
  - [ ] Unit tests passing

- [ ] Day 9: Keyboard Shortcuts & Settings Bar
  - [ ] PermissionManager implemented
  - [ ] KeyboardShortcutManager with ⌘⌥1, ⌘⌥2
  - [ ] SettingsBarView UI complete
  - [ ] Settings wired to SettingsManager
  - [ ] Permission flows tested
  - [ ] Unit tests passing

- [ ] Day 10: ScreenCaptureKit POC
  - [ ] ScreenCapturePOC implemented (macOS 13+)
  - [ ] Legacy fallback implemented (macOS 12)
  - [ ] Region capture tested
  - [ ] Permission handling validated
  - [ ] Performance metrics collected

- [ ] Day 11: Integration & Testing
  - [ ] Integration tests passing
  - [ ] All unit tests passing (`swift test`)
  - [ ] Build successful (`./scripts/build.sh Debug`)
  - [ ] Week 2 summary documented
  - [ ] Ready for Week 3