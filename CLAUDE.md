# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MyRec** is a lightweight, minimalist screen recording application for macOS with essential recording features, intuitive UI, and comprehensive post-recording capabilities including video trimming.

**Platform:** macOS 12.0+ (Intel & Apple Silicon)
**Language:** Swift + SwiftUI
**Primary Frameworks:** AVFoundation, ScreenCaptureKit, NSAppKit

## Project Architecture

### High-Level Architecture

The application follows a multi-layer architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (SwiftUI + NSAppKit)            │
│  - System Tray Controller (NSStatusBar)                     │
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
│  - KeyboardShortcutManager (global hotkeys)                 │
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

### Key Components

**RecordingManager** - Central state machine managing recording lifecycle
- Recording states: idle, recording, paused
- Coordinates video/audio streams
- Handles pause/resume with GOP alignment
- Manages file encoding and output

**ScreenCaptureEngine** - Video capture abstraction
- Uses ScreenCaptureKit (macOS 13+)
- Fallback to CGDisplay API for macOS 12
- Supports full screen, window, and custom region capture
- Manages cursor visibility toggle

**AudioCaptureEngine** - Multi-source audio handling
- System audio via CoreAudio
- Microphone input via AVAudioEngine
- Real-time audio mixing
- Audio/video synchronization with ±50ms tolerance

**VideoEncoder** - Video encoding pipeline
- H.264 encoding with adaptive bitrate
- Resolution: 720P, 1080P, 2K, 4K, custom
- Frame rates: 15, 24, 30, 60 FPS
- MP4 container format

## Build & Development Commands

### Building
```bash
# Build for development (requires Xcode)
xcodebuild -project MyRec.xcodeproj -scheme MyRec -configuration Debug

# Build for release
xcodebuild -project MyRec.xcodeproj -scheme MyRec -configuration Release

# Build universal binary (Intel + Apple Silicon)
xcodebuild -project MyRec.xcodeproj -scheme MyRec -configuration Release -arch x86_64 -arch arm64
```

### Testing
```bash
# Run unit tests
xcodebuild test -project MyRec.xcodeproj -scheme MyRec -destination 'platform=macOS'

# Run specific test
xcodebuild test -project MyRec.xcodeproj -scheme MyRec -only-testing:MyRecTests/RecordingManagerTests/testPauseResume
```

### Code Quality
```bash
# Swift linting (if SwiftLint configured)
swiftlint lint

# Auto-fix linting issues
swiftlint --fix
```

## Core User Workflows

### Recording Workflow
1. User initiates via system tray menu or keyboard shortcut (⌘⌥1)
2. Region selection overlay appears with resize handles
3. Settings bar displays: Resolution, FPS, Camera, Audio, Mic, Pointer toggles
4. User clicks Record → 3-2-1 countdown → recording begins
5. System tray shows: elapsed time, pause button, stop button
6. User clicks Stop (or ⌘⌥2) → file saves to ~/Movies/

### Trim Workflow
1. After recording, preview window opens
2. User clicks "Trim Video" button
3. Trim dialog shows: video preview, timeline, draggable handles
4. User drags start/end handles to select range
5. User clicks Save → trimmed video exports as new file: `REC-{timestamp}-trimmed.mp4`

## Technical Specifications

### Video Settings
- **Codecs:** H.264 (video), AAC (audio)
- **Container:** MP4 (ISO Base Media File Format)
- **Resolutions:** 720P (1280×720), 1080P (1920×1080), 2K (2560×1440), 4K (3840×2160)
- **Frame Rates:** 15, 24, 30, 60 FPS
- **Bitrates (adaptive):**
  - 720P @ 30FPS: ~2.5 Mbps
  - 1080P @ 30FPS: ~5 Mbps
  - 2K @ 30FPS: ~8 Mbps
  - 4K @ 30FPS: ~15 Mbps

### Audio Settings
- **Codec:** AAC
- **Bitrate:** 128-256 kbps
- **Sample Rate:** 48 kHz
- **Channels:** Stereo

### File Management
- **Naming:** `REC-{YYYYMMDDHHMMSS}.mp4`
- **Default Location:** `~/Movies/` (configurable)
- **Trimmed Files:** `REC-{YYYYMMDDHHMMSS}-trimmed.mp4`
- **Permissions:** User read/write, auto-create directory if missing

### Keyboard Shortcuts (Customizable)
- **⌘⌥1** - Start/Pause recording
- **⌘⌥2** - Stop recording
- **⌘⌥,** - Open settings
- **Space** (in trim dialog) - Play/Pause
- **←/→** (in trim dialog) - Previous/Next frame

## Performance Targets

### Idle State
- Memory: < 50 MB
- CPU: < 0.1%
- Energy Impact: Minimal

### Recording (1080P @ 30FPS)
- Memory: 150-250 MB
- CPU: 15-25%
- GPU: 10-20% (hardware accelerated)
- Disk Write: ~5-7 MB/s sustained

### Critical Requirements
- Audio/video sync: within ±50ms throughout entire session
- Pause/resume state switch: < 100ms
- Frame seek (trim dialog): < 200ms
- App launch: < 1 second

## ScreenCaptureKit Usage

**Preferred API:** ScreenCaptureKit (macOS 13+)
**Fallback:** CGDisplayStream API (macOS 12)

When implementing screen capture:
- Request screen recording permission on first launch
- Use SCContentSharingPicker for macOS 13+ window selection
- Handle permission denials gracefully with user guidance
- Test on both Intel and Apple Silicon Macs
- Verify cursor capture toggle works correctly

## Audio Synchronization

Critical implementation details:
- Use AVAssetWriter with CMTime for precise timing
- Align audio/video timestamps from capture start
- Monitor drift during long recordings (1+ hour)
- Buffer management: maintain 2-3 second GOP alignment for pause/resume
- Test lip sync with camera preview enabled

## Settings Persistence

All user settings persist via UserDefaults:
- Save location path
- Last used resolution/FPS
- Camera/Audio/Mic/Pointer toggle states
- Keyboard shortcuts
- Launch at login preference

Never hard-code default values in UI code; centralize in SettingsManager.

## Error Handling Patterns

### Recording Errors
- Display user-friendly error dialogs
- Log technical details for debugging
- Allow retry without app restart
- Handle permission errors explicitly

### File Save Errors
- Check disk space before recording starts
- Handle permission issues with clear guidance
- Atomic writes using temp files
- File validation before playback
- Graceful degradation on corruption

## UI/UX Design Principles

- **Minimalist:** Dark theme (#1a1a1a background), clean interface
- **Unobtrusive:** Settings bar hides after recording starts
- **Responsive:** Real-time updates (elapsed time, countdown)
- **Visual Feedback:** Button state changes, recording area highlight
- **Standard Controls:** Follow macOS conventions

### Color Palette
- Background: `#1a1a1a` (Dark Charcoal)
- Text Primary: `#e0e0e0` (Light Gray)
- Text Secondary: `#999999` (Medium Gray)
- Primary Button: `#e74c3c` (Bright Red) - Record button
- Active Toggle: `#4caf50` (Green) - ON state
- Disabled: `#666666` (Medium Gray)

## Testing Strategy

### Unit Tests
- RecordingManager state transitions: 80% coverage
- SettingsManager persistence: 90% coverage
- File handling: 85% coverage
- Target: 85% overall code coverage

### Integration Tests
- Full recording workflow (select → record → pause → resume → stop → save)
- Settings persistence across app restarts
- Audio/video sync verification
- Trim operation accuracy

### Performance Tests
- CPU/GPU profiling during 1+ hour recordings
- Memory leak detection with Instruments
- Long-duration stability (2+ hours continuous recording)
- Pause/resume stress testing (100+ cycles)

### Compatibility Testing
- macOS 12, 13, 14, 15
- Intel Core i5/i7/i9 processors
- Apple Silicon M1/M2/M3 chips
- Multiple display configurations
- Various audio device combinations

## Code Organization Patterns

When adding new features:

1. **State Changes:** Update RecordingManager state machine first
2. **UI Updates:** Use SwiftUI @Published properties for reactive updates
3. **Persistence:** Add to SettingsManager for any user-configurable options
4. **Error Handling:** Use Result<Success, Error> pattern for failable operations
5. **Testing:** Write unit tests before implementation (TDD approach)

## Implementation Timeline Reference

The project follows a 5-phase, 16-week implementation plan:
- **Phase 1 (Weeks 1-4):** Foundation & Core Recording
- **Phase 2 (Weeks 5-8):** Recording Controls & Settings
- **Phase 3 (Weeks 9-11):** Post-Recording & Preview
- **Phase 4 (Weeks 12-14):** Video Trimming
- **Phase 5 (Weeks 15-16):** Polish, Optimization & Launch

Detailed phase documentation is in `docs/implementation plan.md`.

## Common Pitfalls to Avoid

1. **Audio Sync Drift:** Always use AVAssetWriter's timeline, not system clock
2. **Memory Leaks:** Properly release AVCaptureSession and related objects
3. **Permission Handling:** Request screen recording permission before capture attempt
4. **File Corruption:** Use atomic writes; validate files before playback
5. **Thread Safety:** All UI updates must happen on main thread
6. **GOP Alignment:** Pause/resume must align on keyframes to avoid artifacts

## Distribution & Release

### Code Signing
- Requires Apple Developer account ($99/year)
- Use "Developer ID Application" certificate for distribution
- Enable hardened runtime and notarization

### Notarization Process
```bash
# Sign the app
codesign --deep --force --verify --verbose --sign "Developer ID Application" MyRec.app

# Create DMG
hdiutil create -volname "MyRec" -srcfolder MyRec.app -ov -format UDZO MyRec.dmg

# Submit for notarization
xcrun notarytool submit MyRec.dmg --apple-id your@email.com --team-id TEAM_ID --wait

# Staple the notarization ticket
xcrun stapler staple MyRec.app
```

## Version Management

- **v1.0.0** - Initial release (core recording, trimming, settings)
- **v1.0.x** - Hotfixes (critical bugs, performance, compatibility)
- **v1.1.x** - Minor updates (UI/UX improvements, additional features)
- **v2.0.x** - Major updates (library view, advanced editing, presets)

## Documentation References

- Main requirements: `docs/requirements.md`
- Implementation plan: `docs/implementation plan.md`
- UI reference: `docs/UI quick references.md`
- Timeline: `docs/timeline index.md`
