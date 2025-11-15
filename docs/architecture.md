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
User-configurable recording preferences including:
- Resolution (720P, 1080P, 2K, 4K, custom)
- Frame rate (15, 24, 30, 60 FPS)
- Audio/microphone/camera/cursor toggles

**File:** `MyRec/Models/RecordingSettings.swift`

### RecordingState
State machine for recording lifecycle (idle → recording → paused).

**File:** `MyRec/Models/RecordingState.swift`

**States:**
- `idle`: Not recording
- `recording(startTime: Date)`: Currently recording
- `paused(elapsedTime: TimeInterval)`: Recording paused

### VideoMetadata
File metadata for recorded videos including filename, size, duration, resolution, and formatted display strings.

**File:** `MyRec/Models/VideoMetadata.swift`

### Resolution
Enum representing supported video resolutions with computed width/height properties.

**File:** `MyRec/Models/Resolution.swift`

### FrameRate
Enum representing supported frame rates with display name formatting.

**File:** `MyRec/Models/FrameRate.swift`

## Services

### SettingsManager
Singleton service managing user preferences with UserDefaults persistence.

**File:** `MyRec/Services/Settings/SettingsManager.swift`

**Responsibilities:**
- Save/load recording settings
- Manage save path configuration
- Handle launch at login preference
- Provide reset to defaults functionality

**Key Properties:**
- `savePath`: Default save location for recordings
- `defaultResolution`: User's preferred resolution
- `defaultFrameRate`: User's preferred frame rate
- `launchAtLogin`: Auto-launch preference
- `defaultSettings`: Complete recording settings object

### PermissionManager
Singleton service handling macOS system permissions.

**File:** `MyRec/Services/Permissions/PermissionManager.swift`

**Responsibilities:**
- Check screen recording permission status
- Request microphone access
- Request camera access
- Display permission alerts with system settings guidance

**Permission Types:**
- Screen Recording (ScreenCaptureKit)
- Microphone (AVFoundation)
- Camera (AVFoundation)

### RecordingManager (Week 3)
Central coordinator for recording lifecycle and state management.

**Status:** To be implemented in Week 3

**Planned Responsibilities:**
- Coordinate video/audio capture
- Manage recording state transitions
- Handle pause/resume with GOP alignment
- Manage file encoding and output

## Application Structure

### AppDelegate
Main application delegate handling app lifecycle.

**File:** `MyRec/AppDelegate.swift`

**Responsibilities:**
- Configure as menu bar app (no dock icon)
- Initialize status bar controller
- Handle app termination
- Prevent quit on window close

### MyRecApp
SwiftUI app entry point with NSApplicationDelegateAdaptor.

**File:** `MyRec/MyRecApp.swift`

**Configuration:**
- Uses AppDelegate for lifecycle management
- Settings-only scene (menu bar app)

## Technology Stack

- **Language:** Swift 5.9+
- **Minimum macOS:** 12.0
- **UI Framework:** SwiftUI + NSAppKit
- **Capture:** ScreenCaptureKit (macOS 13+), CGDisplayStream (fallback)
- **Encoding:** AVFoundation (H.264)
- **File Format:** MP4
- **Testing:** XCTest
- **CI/CD:** GitHub Actions
- **Linting:** SwiftLint

## Build Configurations

### Debug
- Debug symbols: Yes
- Optimization: None (-Onone)
- Active architecture only: Yes
- Used for development and testing

### Release
- Debug symbols: No
- Optimization: Aggressive (-O)
- Universal binary: arm64 + x86_64
- Code signing: Developer ID Application
- Used for distribution

## Testing Strategy

### Unit Tests (75%+ coverage target)
- All models: 100% coverage
- All services: 85%+ coverage
- Edge cases and error handling

**Test Files:**
- `MyRecTests/Models/ResolutionTests.swift`
- `MyRecTests/Models/FrameRateTests.swift`
- `MyRecTests/Models/RecordingSettingsTests.swift`
- `MyRecTests/Models/RecordingStateTests.swift`
- `MyRecTests/Models/VideoMetadataTests.swift`
- `MyRecTests/SettingsManagerTests.swift`
- `MyRecTests/PermissionManagerTests.swift`

### Integration Tests (Week 1, Day 5)
- Cross-component integration
- Full workflow testing
- Platform compatibility (Intel + Apple Silicon)

## File Organization

```
MyRec/
├── MyRec/
│   ├── MyRecApp.swift              # App entry point
│   ├── AppDelegate.swift            # App lifecycle
│   ├── Models/
│   │   ├── Resolution.swift         # ✅ Week 1
│   │   ├── FrameRate.swift          # ✅ Week 1
│   │   ├── RecordingSettings.swift  # ✅ Week 1
│   │   ├── RecordingState.swift     # ✅ Week 1
│   │   └── VideoMetadata.swift      # ✅ Week 1
│   ├── Services/
│   │   ├── Settings/
│   │   │   └── SettingsManager.swift       # ✅ Week 1
│   │   ├── Permissions/
│   │   │   └── PermissionManager.swift     # ✅ Week 1
│   │   ├── Recording/
│   │   │   └── RecordingManager.swift      # ⏳ Week 3
│   │   ├── Capture/
│   │   │   └── ScreenCaptureEngine.swift   # ⏳ Week 3
│   │   ├── Video/
│   │   │   └── VideoEncoder.swift          # ⏳ Week 3
│   │   └── File/
│   │       └── RecordingFileManager.swift  # ⏳ Week 4
│   ├── Views/                               # ⏳ Week 2
│   ├── ViewModels/                          # ⏳ Week 2
│   └── Utilities/
├── MyRecTests/
│   ├── Models/                              # ✅ Week 1
│   ├── SettingsManagerTests.swift           # ✅ Week 1
│   └── PermissionManagerTests.swift         # ✅ Week 1
├── scripts/
│   ├── build.sh                             # ✅ Week 1
│   └── test.sh                              # ✅ Week 1
└── .github/workflows/
    └── build.yml                            # ✅ Week 1
```

## Week 1 Deliverables Summary

### Completed (12 tasks)
- ✅ DEV-001: Git Repository Configuration
- ✅ DEV-002: Xcode Project Creation
- ✅ DEV-003: CI/CD Pipeline
- ✅ DEV-004: SwiftLint Configuration
- ✅ DEV-005: Resolution Model
- ✅ DEV-006: FrameRate Model
- ✅ DEV-007: RecordingSettings Model
- ✅ DEV-008: RecordingState Model
- ✅ DEV-009: VideoMetadata Model
- ✅ DEV-010: SettingsManager Service
- ✅ DEV-011: PermissionManager Service
- ✅ DEV-012: AppDelegate Setup
- ✅ DEV-013: Build Scripts
- ✅ DEV-015: Architecture Documentation

### Foundation Established
- 5 core data models implemented
- 2 service managers operational
- Build and test automation ready
- Comprehensive test coverage (7 test files)
- CI/CD pipeline functional

## Next Steps (Week 2)

### UI Components
- StatusBarController with context menu
- RegionSelectionWindow with drag-to-select
- Resize handles (8 total: corners + edges)
- KeyboardShortcutManager
- SettingsBarView skeleton

### ScreenCaptureKit Integration
- Proof-of-concept implementation
- Permission handling integration
- Display/window enumeration

---

**Last Updated:** November 14, 2025
**Phase:** 1 - Foundation & Core Recording
**Week:** 1 - Project Kickoff & Infrastructure
**Status:** ✅ Complete
