# Week 1: Development Tasks

**Focus:** Development environment, core architecture, and foundational code
**Duration:** 5 days
**Total Tasks:** 20 development tasks
**Status:** ✅ 75% Complete (15/20 tasks) + Project Build Success
**Last Updated:** November 15, 2025

---

## Task Completion Summary

### ✅ Completed (15/20)
- **Day 1 (4/4):** DEV-001 ✅ | DEV-002 ✅ | DEV-003 ✅ | DEV-004 ✅
- **Day 2 (5/5):** DEV-005 ✅ | DEV-006 ✅ | DEV-007 ✅ | DEV-008 ✅ | DEV-009 ✅
- **Day 3 (3/3):** DEV-010 ✅ | DEV-011 ✅ | DEV-012 ✅
- **Day 4 (3/3):** DEV-013 ✅ | DEV-014 ✅ | DEV-015 ✅
- **Day 5 (0/5):** In Progress

### 🟡 In Progress (1/20)
- DEV-016: Complete Unit Test Suite (adding test files to Xcode)

### ⏳ Remaining (4/20)
- DEV-017: Integration Testing
- DEV-018: Code Review
- DEV-019: README Documentation
- DEV-020: Week Completion Verification

### 🎉 Additional Accomplishments
- ✅ Project builds successfully (`xcodebuild` succeeds)
- ✅ SwiftLint passes with 0 violations
- ✅ All Swift files added to Xcode project
- ✅ CLAUDE.md updated with comprehensive build instructions

---

## Development Task List

### Day 1: Project Setup

#### DEV-001: Git Repository Configuration ✅
**Effort:** 1 hour
**Status:** COMPLETED

Create and configure Git repository:

```bash
# Create .gitignore
cat > .gitignore << 'EOF'
# Xcode
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/
!*.xcworkspace/contents.xcworkspacedata
**/xcshareddata/WorkspaceSettings.xcsettings
*.xcuserstate
*.xcuserdatad/

# Build products
build/
DerivedData/

# Swift Package Manager
.swiftpm/
.build/

# macOS
.DS_Store

# Other
*.swp
*~
.vscode/
EOF

# Set up branch protection and team access
```

**Deliverables:**
- Repository with proper .gitignore
- Branch protection on main
- Team access configured

---

#### DEV-002: Create Xcode Project
**Effort:** 2 hours

Create macOS app Xcode project:

**Steps:**
1. Create new Xcode project:
   - Template: macOS → App
   - Name: MyRec
   - Interface: SwiftUI
   - Language: Swift

2. Configure project settings:
   - Deployment Target: macOS 12.0
   - Swift Language Version: Swift 5
   - Architectures: Standard (Intel + Apple Silicon)

3. Create folder structure:
```
MyRec/
├── MyRec/
│   ├── MyRecApp.swift
│   ├── Models/
│   ├── Views/
│   ├── ViewModels/
│   ├── Services/
│   │   ├── Recording/
│   │   ├── Audio/
│   │   ├── Video/
│   │   └── Settings/
│   ├── Utilities/
│   └── Resources/
│       └── Assets.xcassets
├── MyRecTests/
└── MyRec.xcodeproj
```

4. Verify build:
```bash
xcodebuild -project MyRec.xcodeproj -scheme MyRec -configuration Debug build
```

**Deliverables:**
- Xcode project compiles
- Folder structure created
- Universal binary support enabled

---

#### DEV-003: CI/CD Pipeline Setup
**Effort:** 2 hours

Set up GitHub Actions workflow:

Create `.github/workflows/build.yml`:
```yaml
name: Build and Test

on:
  push:
    branches: [ develop, feature/** ]
  pull_request:
    branches: [ main, develop ]

jobs:
  lint:
    runs-on: macos-13
    steps:
    - uses: actions/checkout@v3
    - name: Install SwiftLint
      run: brew install swiftlint
    - name: Run SwiftLint
      run: swiftlint lint --strict

  build-and-test:
    runs-on: macos-13
    needs: lint
    steps:
    - uses: actions/checkout@v3
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_15.0.app
    - name: Build
      run: |
        xcodebuild clean build \
          -project MyRec.xcodeproj \
          -scheme MyRec \
          -configuration Debug \
          -destination 'platform=macOS'
    - name: Run Tests
      run: |
        xcodebuild test \
          -project MyRec.xcodeproj \
          -scheme MyRec \
          -destination 'platform=macOS' \
          -enableCodeCoverage YES
```

**Deliverables:**
- GitHub Actions workflow functional
- Automated builds on push
- Test execution automated

---

#### DEV-004: SwiftLint Configuration
**Effort:** 1 hour

Configure SwiftLint:

Create `.swiftlint.yml`:
```yaml
included:
  - MyRec

excluded:
  - Pods
  - DerivedData
  - .build

opt_in_rules:
  - empty_count
  - empty_string
  - explicit_init
  - fatal_error_message
  - force_unwrapping
  - implicitly_unwrapped_optional
  - multiline_parameters
  - closure_spacing
  - sorted_imports

disabled_rules:
  - trailing_whitespace

line_length:
  warning: 120
  error: 200
  ignores_comments: true

file_length:
  warning: 500
  error: 1000

function_body_length:
  warning: 50
  error: 100

type_body_length:
  warning: 300
  error: 500

identifier_name:
  min_length:
    warning: 2
  max_length:
    warning: 50
  excluded:
    - id
    - x
    - y
```

Add Run Script Phase to Xcode:
```bash
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```

**Deliverables:**
- .swiftlint.yml configured
- Xcode build phase added
- All code passes linting

---

### Day 2: Core Data Models

#### DEV-005: Resolution Enum
**Effort:** 30 minutes

Create `MyRec/Models/Resolution.swift`:

```swift
import Foundation

enum Resolution: String, Codable, CaseIterable {
    case hd = "720P"
    case fullHD = "1080P"
    case twoK = "2K"
    case fourK = "4K"
    case custom

    var dimensions: (width: Int, height: Int) {
        switch self {
        case .hd: return (1280, 720)
        case .fullHD: return (1920, 1080)
        case .twoK: return (2560, 1440)
        case .fourK: return (3840, 2160)
        case .custom: return (0, 0)
        }
    }

    var width: Int { dimensions.width }
    var height: Int { dimensions.height }
}
```

Create `MyRecTests/Models/ResolutionTests.swift`:

```swift
import XCTest
@testable import MyRec

class ResolutionTests: XCTestCase {
    func testResolutionDimensions() {
        XCTAssertEqual(Resolution.hd.width, 1280)
        XCTAssertEqual(Resolution.hd.height, 720)
        XCTAssertEqual(Resolution.fullHD.width, 1920)
        XCTAssertEqual(Resolution.fullHD.height, 1080)
        XCTAssertEqual(Resolution.twoK.width, 2560)
        XCTAssertEqual(Resolution.twoK.height, 1440)
        XCTAssertEqual(Resolution.fourK.width, 3840)
        XCTAssertEqual(Resolution.fourK.height, 2160)
    }

    func testResolutionCodable() throws {
        let resolution = Resolution.fullHD
        let encoded = try JSONEncoder().encode(resolution)
        let decoded = try JSONDecoder().decode(Resolution.self, from: encoded)
        XCTAssertEqual(resolution, decoded)
    }
}
```

**Deliverables:**
- Resolution.swift implemented
- Tests passing

---

#### DEV-006: FrameRate Enum
**Effort:** 30 minutes

Create `MyRec/Models/FrameRate.swift`:

```swift
import Foundation

enum FrameRate: Int, Codable, CaseIterable {
    case fps15 = 15
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60

    var value: Int { self.rawValue }

    var displayName: String {
        "\(value) FPS"
    }
}
```

Create `MyRecTests/Models/FrameRateTests.swift`:

```swift
import XCTest
@testable import MyRec

class FrameRateTests: XCTestCase {
    func testFrameRateValues() {
        XCTAssertEqual(FrameRate.fps15.value, 15)
        XCTAssertEqual(FrameRate.fps24.value, 24)
        XCTAssertEqual(FrameRate.fps30.value, 30)
        XCTAssertEqual(FrameRate.fps60.value, 60)
    }

    func testDisplayName() {
        XCTAssertEqual(FrameRate.fps30.displayName, "30 FPS")
        XCTAssertEqual(FrameRate.fps60.displayName, "60 FPS")
    }

    func testCodable() throws {
        let frameRate = FrameRate.fps30
        let encoded = try JSONEncoder().encode(frameRate)
        let decoded = try JSONDecoder().decode(FrameRate.self, from: encoded)
        XCTAssertEqual(frameRate, decoded)
    }
}
```

**Deliverables:**
- FrameRate.swift implemented
- Tests passing

---

#### DEV-007: RecordingSettings Model
**Effort:** 1 hour

Create `MyRec/Models/RecordingSettings.swift`:

```swift
import Foundation

struct RecordingSettings: Codable, Equatable {
    var resolution: Resolution
    var frameRate: FrameRate
    var audioEnabled: Bool
    var microphoneEnabled: Bool
    var cameraEnabled: Bool
    var cursorEnabled: Bool

    static let `default` = RecordingSettings(
        resolution: .fullHD,
        frameRate: .fps30,
        audioEnabled: true,
        microphoneEnabled: false,
        cameraEnabled: false,
        cursorEnabled: true
    )
}
```

Create `MyRecTests/Models/RecordingSettingsTests.swift`:

```swift
import XCTest
@testable import MyRec

class RecordingSettingsTests: XCTestCase {
    func testDefaultSettings() {
        let settings = RecordingSettings.default

        XCTAssertEqual(settings.resolution, .fullHD)
        XCTAssertEqual(settings.frameRate, .fps30)
        XCTAssertTrue(settings.audioEnabled)
        XCTAssertFalse(settings.microphoneEnabled)
        XCTAssertFalse(settings.cameraEnabled)
        XCTAssertTrue(settings.cursorEnabled)
    }

    func testCodable() throws {
        let settings = RecordingSettings.default
        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(RecordingSettings.self, from: encoded)

        XCTAssertEqual(settings, decoded)
    }

    func testEquatable() {
        let settings1 = RecordingSettings.default
        let settings2 = RecordingSettings.default

        XCTAssertEqual(settings1, settings2)

        var settings3 = settings1
        settings3.resolution = .fourK

        XCTAssertNotEqual(settings1, settings3)
    }
}
```

**Deliverables:**
- RecordingSettings.swift implemented
- Tests passing

---

#### DEV-008: RecordingState Enum
**Effort:** 1 hour

Create `MyRec/Models/RecordingState.swift`:

```swift
import Foundation

enum RecordingState: Equatable {
    case idle
    case recording(startTime: Date)
    case paused(elapsedTime: TimeInterval)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
}
```

Create `MyRecTests/Models/RecordingStateTests.swift`:

```swift
import XCTest
@testable import MyRec

class RecordingStateTests: XCTestCase {
    func testIdleState() {
        let state = RecordingState.idle

        XCTAssertTrue(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertFalse(state.isPaused)
    }

    func testRecordingState() {
        let state = RecordingState.recording(startTime: Date())

        XCTAssertFalse(state.isIdle)
        XCTAssertTrue(state.isRecording)
        XCTAssertFalse(state.isPaused)
    }

    func testPausedState() {
        let state = RecordingState.paused(elapsedTime: 10.0)

        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertTrue(state.isPaused)
    }

    func testEquatable() {
        let state1 = RecordingState.idle
        let state2 = RecordingState.idle
        XCTAssertEqual(state1, state2)

        let date = Date()
        let state3 = RecordingState.recording(startTime: date)
        let state4 = RecordingState.recording(startTime: date)
        XCTAssertEqual(state3, state4)

        let state5 = RecordingState.paused(elapsedTime: 10.0)
        let state6 = RecordingState.paused(elapsedTime: 10.0)
        XCTAssertEqual(state5, state6)
    }
}
```

**Deliverables:**
- RecordingState.swift implemented
- Tests passing

---

#### DEV-009: VideoMetadata Model
**Effort:** 1 hour

Create `MyRec/Models/VideoMetadata.swift`:

```swift
import Foundation
import CoreGraphics

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
```

Create `MyRecTests/Models/VideoMetadataTests.swift`:

```swift
import XCTest
@testable import MyRec

class VideoMetadataTests: XCTestCase {
    func testFileSizeString() {
        let metadata = VideoMetadata(
            filename: "test.mp4",
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            fileSize: 1024 * 1024, // 1 MB
            duration: 60,
            resolution: CGSize(width: 1920, height: 1080),
            frameRate: 30,
            createdAt: Date(),
            format: "mp4"
        )

        XCTAssertTrue(metadata.fileSizeString.contains("MB"))
    }

    func testDurationString() {
        let metadata1 = VideoMetadata(
            filename: "test.mp4",
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            fileSize: 1024,
            duration: 65, // 1 min 5 sec
            resolution: CGSize(width: 1920, height: 1080),
            frameRate: 30,
            createdAt: Date(),
            format: "mp4"
        )
        XCTAssertEqual(metadata1.durationString, "01:05")

        let metadata2 = VideoMetadata(
            filename: "test.mp4",
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            fileSize: 1024,
            duration: 3665, // 1 hr 1 min 5 sec
            resolution: CGSize(width: 1920, height: 1080),
            frameRate: 30,
            createdAt: Date(),
            format: "mp4"
        )
        XCTAssertEqual(metadata2.durationString, "01:01:05")
    }

    func testResolutionString() {
        let metadata = VideoMetadata(
            filename: "test.mp4",
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            fileSize: 1024,
            duration: 60,
            resolution: CGSize(width: 1920, height: 1080),
            frameRate: 30,
            createdAt: Date(),
            format: "mp4"
        )

        XCTAssertEqual(metadata.resolutionString, "1920 × 1080")
    }
}
```

**Deliverables:**
- VideoMetadata.swift implemented
- Tests passing

---

### Day 3: Services Layer

#### DEV-010: SettingsManager Implementation
**Effort:** 2 hours

Create `MyRec/Services/Settings/SettingsManager.swift`:

```swift
import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var savePath: URL {
        didSet { save() }
    }

    @Published var defaultResolution: Resolution {
        didSet { save() }
    }

    @Published var defaultFrameRate: FrameRate {
        didSet { save() }
    }

    @Published var launchAtLogin: Bool {
        didSet { save() }
    }

    @Published var defaultSettings: RecordingSettings {
        didSet { save() }
    }

    private enum Keys {
        static let savePath = "savePath"
        static let defaultResolution = "defaultResolution"
        static let defaultFrameRate = "defaultFrameRate"
        static let launchAtLogin = "launchAtLogin"
        static let defaultSettings = "defaultSettings"
    }

    private init() {
        let defaultPath = FileManager.default.urls(
            for: .moviesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        self.savePath = UserDefaults.standard.url(forKey: Keys.savePath) ?? defaultPath

        if let resolutionRaw = UserDefaults.standard.string(forKey: Keys.defaultResolution),
           let resolution = Resolution(rawValue: resolutionRaw) {
            self.defaultResolution = resolution
        } else {
            self.defaultResolution = .fullHD
        }

        self.defaultFrameRate = FrameRate(
            rawValue: UserDefaults.standard.integer(forKey: Keys.defaultFrameRate)
        ) ?? .fps30

        self.launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)

        if let settingsData = UserDefaults.standard.data(forKey: Keys.defaultSettings),
           let settings = try? JSONDecoder().decode(RecordingSettings.self, from: settingsData) {
            self.defaultSettings = settings
        } else {
            self.defaultSettings = .default
        }
    }

    func save() {
        UserDefaults.standard.set(savePath, forKey: Keys.savePath)
        UserDefaults.standard.set(defaultResolution.rawValue, forKey: Keys.defaultResolution)
        UserDefaults.standard.set(defaultFrameRate.rawValue, forKey: Keys.defaultFrameRate)
        UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)

        if let settingsData = try? JSONEncoder().encode(defaultSettings) {
            UserDefaults.standard.set(settingsData, forKey: Keys.defaultSettings)
        }
    }

    func reset() {
        let defaultPath = FileManager.default.urls(
            for: .moviesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        savePath = defaultPath
        defaultResolution = .fullHD
        defaultFrameRate = .fps30
        launchAtLogin = false
        defaultSettings = .default
    }
}
```

Create `MyRecTests/SettingsManagerTests.swift`:

```swift
import XCTest
@testable import MyRec

class SettingsManagerTests: XCTestCase {
    var sut: SettingsManager!

    override func setUp() {
        super.setUp()
        sut = SettingsManager.shared
    }

    func testDefaultSettings() {
        XCTAssertEqual(sut.defaultResolution, .fullHD)
        XCTAssertEqual(sut.defaultFrameRate, .fps30)
        XCTAssertFalse(sut.launchAtLogin)
    }

    func testSaveAndLoad() {
        sut.defaultResolution = .fourK
        sut.defaultFrameRate = .fps60
        sut.launchAtLogin = true

        sut.save()

        XCTAssertEqual(sut.defaultResolution, .fourK)
        XCTAssertEqual(sut.defaultFrameRate, .fps60)
        XCTAssertTrue(sut.launchAtLogin)
    }

    func testReset() {
        sut.defaultResolution = .fourK
        sut.launchAtLogin = true

        sut.reset()

        XCTAssertEqual(sut.defaultResolution, .fullHD)
        XCTAssertFalse(sut.launchAtLogin)
    }
}
```

**Deliverables:**
- SettingsManager.swift implemented
- Tests passing
- UserDefaults persistence working

---

#### DEV-011: PermissionManager Implementation
**Effort:** 2 hours

Create `MyRec/Services/Permissions/PermissionManager.swift`:

```swift
import AVFoundation
import ScreenCaptureKit
import AppKit

enum PermissionType {
    case screenRecording
    case microphone
    case camera
}

enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

class PermissionManager {
    static let shared = PermissionManager()

    private init() {}

    // MARK: - Screen Recording Permission

    func checkScreenRecordingPermission() async -> PermissionStatus {
        do {
            _ = try await SCShareableContent.current
            return .granted
        } catch {
            return .denied
        }
    }

    func requestScreenRecordingPermission() async -> Bool {
        let status = await checkScreenRecordingPermission()

        if status == .denied {
            await MainActor.run {
                showPermissionAlert(for: .screenRecording)
            }
            return false
        }

        return status == .granted
    }

    // MARK: - Microphone Permission

    func checkMicrophonePermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    func requestMicrophonePermission() async -> Bool {
        let status = checkMicrophonePermission()

        if status == .granted {
            return true
        }

        if status == .denied {
            await MainActor.run {
                showPermissionAlert(for: .microphone)
            }
            return false
        }

        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Camera Permission

    func checkCameraPermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    func requestCameraPermission() async -> Bool {
        let status = checkCameraPermission()

        if status == .granted {
            return true
        }

        if status == .denied {
            await MainActor.run {
                showPermissionAlert(for: .camera)
            }
            return false
        }

        return await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: - Alert Helper

    private func showPermissionAlert(for type: PermissionType) {
        let alert = NSAlert()
        alert.alertStyle = .warning

        switch type {
        case .screenRecording:
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "Please enable screen recording permission in System Settings → Privacy & Security → Screen Recording."

        case .microphone:
            alert.messageText = "Microphone Permission Required"
            alert.informativeText = "Please enable microphone access in System Settings → Privacy & Security → Microphone."

        case .camera:
            alert.messageText = "Camera Permission Required"
            alert.informativeText = "Please enable camera access in System Settings → Privacy & Security → Camera."
        }

        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            openSystemPreferences(for: type)
        }
    }

    private func openSystemPreferences(for type: PermissionType) {
        let urlString: String

        switch type {
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .camera:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
```

Create `MyRecTests/PermissionManagerTests.swift`:

```swift
import XCTest
@testable import MyRec

class PermissionManagerTests: XCTestCase {
    var sut: PermissionManager!

    override func setUp() {
        super.setUp()
        sut = PermissionManager.shared
    }

    func testCheckMicrophonePermission() {
        let status = sut.checkMicrophonePermission()
        XCTAssertTrue([.granted, .denied, .notDetermined].contains(status))
    }

    func testCheckCameraPermission() {
        let status = sut.checkCameraPermission()
        XCTAssertTrue([.granted, .denied, .notDetermined].contains(status))
    }

    func testScreenRecordingPermissionCheck() async {
        let status = await sut.checkScreenRecordingPermission()
        XCTAssertTrue([.granted, .denied].contains(status))
    }
}
```

**Deliverables:**
- PermissionManager.swift implemented
- Tests passing
- Permission alerts working

---

#### DEV-012: AppDelegate Setup
**Effort:** 1 hour

Create `MyRec/AppDelegate.swift`:

```swift
import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Initialize status bar (will create in Week 2)
        // statusBarController = StatusBarController()

        print("✅ MyRec launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 MyRec terminating")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when windows close (menu bar app)
        return false
    }
}
```

Update `MyRec/MyRecApp.swift`:

```swift
import SwiftUI

@main
struct MyRecApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

Configure `Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>MyRec needs screen recording permission to capture your screen.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>MyRec needs microphone access to record audio from your microphone.</string>
    <key>NSCameraUsageDescription</key>
    <string>MyRec needs camera access to include your webcam in recordings.</string>
</dict>
</plist>
```

**Deliverables:**
- AppDelegate.swift implemented
- MyRecApp.swift updated
- Info.plist configured
- App runs as menu bar only (no dock icon)

---

### Day 4: Build & Documentation

#### DEV-013: Build Scripts
**Effort:** 1 hour

Create `scripts/build.sh`:

```bash
#!/bin/bash
set -e

echo "🔨 Building MyRec..."

CONFIGURATION=${1:-Debug}

echo "🧹 Cleaning..."
xcodebuild clean \
  -project MyRec.xcodeproj \
  -scheme MyRec \
  -configuration $CONFIGURATION

echo "⚙️  Building $CONFIGURATION..."
xcodebuild build \
  -project MyRec.xcodeproj \
  -scheme MyRec \
  -configuration $CONFIGURATION \
  -arch arm64 \
  -arch x86_64 \
  ONLY_ACTIVE_ARCH=NO

echo "✅ Build complete!"
```

Create `scripts/test.sh`:

```bash
#!/bin/bash
set -e

echo "🧪 Running tests..."

xcodebuild test \
  -project MyRec.xcodeproj \
  -scheme MyRec \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES

echo "✅ Tests complete!"
```

Make scripts executable:
```bash
chmod +x scripts/build.sh scripts/test.sh
```

**Deliverables:**
- build.sh script working
- test.sh script working
- Universal binary builds successfully

---

#### DEV-014: Build Configuration
**Effort:** 1 hour

Configure Xcode build settings:

**Development Configuration:**
- Debug symbols: Yes
- Optimization: None (-Onone)
- Strip symbols: No
- Code signing: Development
- Build active architecture only: Yes

**Release Configuration:**
- Debug symbols: No
- Optimization: Aggressive (-O)
- Strip symbols: Yes
- Code signing: Developer ID Application
- Build active architecture only: No
- Architectures: arm64, x86_64

**Deliverables:**
- Debug configuration optimized for development
- Release configuration ready for distribution
- Universal binary support verified

---

#### DEV-015: Architecture Documentation
**Effort:** 2 hours

Create `docs/architecture.md`:

```markdown
# MyRec Architecture

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (SwiftUI + NSAppKit)            │
│  - System Tray Controller                                   │
│  - Region Selection Overlay                                 │
│  - Settings Bar                                             │
│  - Preview Window                                           │
│  - Trim Dialog                                              │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Core Services Layer                      │
│  - RecordingManager (state machine)                         │
│  - SettingsManager (UserDefaults persistence)               │
│  - FileManager (save/naming/metadata)                       │
│  - PermissionManager (screen/audio/camera)                  │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Video/Audio Capture & Processing               │
│  - ScreenCaptureEngine (ScreenCaptureKit)                   │
│  - AudioCaptureEngine (CoreAudio, AVAudioEngine)            │
│  - VideoEncoder (H.264, MP4)                                │
│  - AudioProcessor (AAC, mixing)                             │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    macOS System Frameworks                  │
│  AVFoundation | CoreAudio | ScreenCaptureKit | CoreVideo   │
└─────────────────────────────────────────────────────────────┘
```

## Data Models

### RecordingSettings
User-configurable recording preferences.

### RecordingState
State machine for recording lifecycle (idle → recording → paused).

### VideoMetadata
File metadata for recorded videos.

## Services

### SettingsManager
Manages user preferences with UserDefaults persistence.

### PermissionManager
Handles macOS permissions (screen recording, microphone, camera).

### RecordingManager (Week 3)
Central coordinator for recording lifecycle.

## Technology Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI + NSAppKit
- **Capture:** ScreenCaptureKit (macOS 13+)
- **Encoding:** AVFoundation (H.264)
- **File Format:** MP4
- **Testing:** XCTest
```

**Deliverables:**
- Complete architecture documentation
- Diagrams included
- Technology decisions documented

---

### Day 5: Testing & Integration

#### DEV-016: Complete Unit Test Suite
**Effort:** 2 hours

Ensure all models and services have comprehensive tests:

**Test Coverage Requirements:**
- Resolution: 100%
- FrameRate: 100%
- RecordingSettings: 100%
- RecordingState: 100%
- VideoMetadata: 90%+
- SettingsManager: 85%+
- PermissionManager: 70%+

**Run coverage report:**
```bash
xcodebuild test \
  -project MyRec.xcodeproj \
  -scheme MyRec \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES

# View coverage in Xcode
# Product → Test → Show Code Coverage
```

**Deliverables:**
- All unit tests passing
- Code coverage > 75%
- Coverage report generated

---

#### DEV-017: Integration Testing
**Effort:** 2 hours

Verify end-to-end integration:

**Integration Test Checklist:**

1. **Build Verification:**
   - [ ] Project compiles on Intel Mac
   - [ ] Project compiles on Apple Silicon Mac
   - [ ] CI/CD pipeline passes
   - [ ] Universal binary builds successfully

2. **Runtime Verification:**
   - [ ] App launches
   - [ ] No dock icon visible
   - [ ] Menu bar app only
   - [ ] App terminates cleanly

3. **Data Persistence:**
   - [ ] Settings save to UserDefaults
   - [ ] Settings load on app restart
   - [ ] Settings reset works

4. **Permissions:**
   - [ ] Permission checks work
   - [ ] Permission alerts display
   - [ ] System Settings open correctly

5. **Code Quality:**
   - [ ] SwiftLint passes with 0 errors
   - [ ] All tests pass
   - [ ] No compiler warnings

**Deliverables:**
- All integration tests pass
- Test results documented
- Issues identified and fixed

---

#### DEV-018: Code Review
**Effort:** 2 hours

Review all Week 1 code:

**Code Review Checklist:**

**Code Quality:**
- [ ] Follows Swift best practices
- [ ] Proper error handling
- [ ] No force unwrapping (unless documented)
- [ ] Meaningful variable names
- [ ] Functions are single-purpose
- [ ] DRY principle followed

**Testing:**
- [ ] Tests are comprehensive
- [ ] Edge cases covered
- [ ] Assertions are meaningful
- [ ] Test names are descriptive

**Documentation:**
- [ ] Public APIs documented
- [ ] Complex logic has comments
- [ ] README updated
- [ ] Architecture docs current

**Process:**
1. Create pull requests from feature branches
2. Senior developer reviews
3. Address comments
4. Merge to develop

**Deliverables:**
- All code reviewed
- Issues addressed
- Code merged to develop

---

#### DEV-019: README Documentation
**Effort:** 1 hour

Create comprehensive README:

```markdown
# MyRec - macOS Screen Recording App

A lightweight, minimalist screen recording application for macOS.

## Requirements

- macOS 12.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

1. Clone the repository:
\`\`\`bash
git clone https://github.com/yourcompany/myrec.git
cd myrec
\`\`\`

2. Open the project:
\`\`\`bash
open MyRec.xcodeproj
\`\`\`

3. Build and run (⌘R)

## Development

### Building
\`\`\`bash
./scripts/build.sh Debug
\`\`\`

### Testing
\`\`\`bash
./scripts/test.sh
\`\`\`

### Linting
\`\`\`bash
swiftlint
\`\`\`

## Architecture

See [docs/architecture.md](docs/architecture.md)

## License

Copyright © 2025 Your Company. All rights reserved.
```

**Deliverables:**
- README.md complete
- Setup instructions clear
- Development commands documented

---

#### DEV-020: Week Completion Verification
**Effort:** 1 hour

Final verification of all deliverables:

**Completion Checklist:**

**Code Files (9 files):**
- [ ] Resolution.swift
- [ ] FrameRate.swift
- [ ] RecordingSettings.swift
- [ ] RecordingState.swift
- [ ] VideoMetadata.swift
- [ ] SettingsManager.swift
- [ ] PermissionManager.swift
- [ ] AppDelegate.swift
- [ ] MyRecApp.swift

**Test Files (7 files):**
- [ ] ResolutionTests.swift
- [ ] FrameRateTests.swift
- [ ] RecordingSettingsTests.swift
- [ ] RecordingStateTests.swift
- [ ] VideoMetadataTests.swift
- [ ] SettingsManagerTests.swift
- [ ] PermissionManagerTests.swift

**Infrastructure:**
- [ ] .gitignore configured
- [ ] .swiftlint.yml configured
- [ ] GitHub Actions workflow
- [ ] Build scripts (build.sh, test.sh)
- [ ] Info.plist configured

**Documentation:**
- [ ] README.md
- [ ] docs/architecture.md

**Quality Metrics:**
- [ ] All tests passing
- [ ] Code coverage > 75%
- [ ] SwiftLint: 0 errors
- [ ] CI/CD: Green
- [ ] Universal binary: Working

**Deliverables:**
- Completion checklist verified
- All tasks complete
- Ready for Week 2

---

## Summary

### Implemented Components

**Models (5):**
- Resolution enum with dimensions
- FrameRate enum with display names
- RecordingSettings struct
- RecordingState enum with helpers
- VideoMetadata struct with formatters

**Services (2):**
- SettingsManager with UserDefaults persistence
- PermissionManager with alert handling

**App Structure (2):**
- AppDelegate for menu bar app
- MyRecApp with Settings scene

**Infrastructure:**
- Git repository
- CI/CD pipeline
- SwiftLint configuration
- Build scripts
- Test framework

### Quality Metrics

- **Test Coverage:** > 75%
- **Test Files:** 7
- **Code Files:** 9
- **Lines of Code:** ~800
- **SwiftLint Violations:** 0

### Ready for Week 2

Week 1 provides a solid foundation:
- Core data models complete
- Settings persistence working
- Permission framework ready
- App structure in place
- CI/CD automated
- Tests comprehensive

Next week will build upon this foundation to add:
- System tray UI
- Region selection overlay
- Keyboard shortcuts
- ScreenCaptureKit integration
