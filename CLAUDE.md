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

## Development Methodology

### Sprint-Based Development (1-Week Cycles)

This project follows a structured, incremental development approach with weekly sprints:

#### Weekly Sprint Structure

**Directory Organization:**
```
plan/
├── week-1/
│   ├── progress.md           # Week overview: main goal + daily todo tracking
│   ├── day1-plan.md         # Detailed plan for Day 1
│   ├── day2-plan.md         # Detailed plan for Day 2
│   └── ...
├── week-2/
│   └── ...
└── master-progress.md       # Overall project progress tracking
```

#### Sprint Workflow

**1. Sprint Planning (Start of Week)**
- Create `week-N/` directory
- Define week's main goal in `progress.md`
- Create daily plan files (`day1-plan.md`, `day2-plan.md`, etc.)
- Break down tasks into testable, incremental units
- Prepare all planning documents before implementation begins

**2. Daily Development**
- Work from the day's plan file
- Each day's work must be independently testable
- For dependencies on future work: use console logs or placeholders
- Build incrementally - verify each piece separately
- At end of day:
  - Update day plan with status and results
  - Update week `progress.md` with completed tasks

**3. Sprint Completion (End of Week)**
- Review all daily outcomes
- Update `progress.md` with final week status
- Update `master-progress.md` with sprint achievements
- Document any blockers or carry-over tasks

#### Development Principles

**Testability First:**
- Every day's implementation must be verifiable
- Write tests before or alongside code (TDD)
- Use `swift test` to validate changes
- Mock dependencies that aren't ready yet

**Incremental Building:**
- Start with smallest working unit
- Add complexity gradually
- Each commit should build successfully
- Avoid "big bang" integrations

**Documentation Updates:**
- Update progress files in real-time
- Document decisions and trade-offs
- Keep master plan synchronized with reality
- Track deviations from original estimates

**Placeholder Strategy:**
- Console logs for UI not yet implemented
- Mock objects for future integrations
- Stub methods with clear TODO comments
- Always return valid data types (never crash)

#### Example Daily Plan Structure

```markdown
# Week 5 - Day 1: File Manager Core Implementation

## Goal
Implement FileManager with save location management

## Tasks
- [ ] Create FileManager class structure
- [ ] Implement save location validation
- [ ] Add directory creation logic
- [ ] Write unit tests for each method

## Dependencies
- SettingsManager (completed Week 4)

## Testing
- Test with valid/invalid paths
- Verify directory creation
- Check permission handling

## Status
[Updated at end of day]

## Results
[What was completed, blockers, next steps]
```

## Build & Development Commands

### Prerequisites

1. **Xcode 15.0+** installed from the Mac App Store
2. **Swift 5.9+** (comes with Xcode)
3. **SwiftLint** (optional but recommended):
   ```bash
   brew install swiftlint
   ```

### Build System

MyRec uses **dual build systems**:

1. **Swift Package Manager (`Package.swift`)** - Recommended
   - Fast, lightweight testing: `swift test`
   - CI/CD friendly
   - Cross-platform development
   - Tests work out of the box

2. **Xcode Project (`MyRec.xcodeproj`)** - Optional
   - Visual debugging in Xcode
   - Rich UI test runner
   - Detailed code coverage reports
   - App building and distribution

**For development:** Use `swift test` for testing and `xcodebuild` for building the app.


### Building

```bash
# Quick build using provided script (recommended)
./scripts/build.sh Debug

# Build for development using xcodebuild
xcodebuild -project MyRec.xcodeproj -scheme MyRec -configuration Debug -destination 'platform=macOS'

# Build for release
./scripts/build.sh Release

# Or with xcodebuild:
xcodebuild -project MyRec.xcodeproj -scheme MyRec -configuration Release

# Build universal binary (Intel + Apple Silicon)
xcodebuild -project MyRec.xcodeproj -scheme MyRec -configuration Release -arch x86_64 -arch arm64 ONLY_ACTIVE_ARCH=NO
```

**Build Output Location:**
- Debug: `~/Library/Developer/Xcode/DerivedData/MyRec-*/Build/Products/Debug/MyRec.app`
- Release: `~/Library/Developer/Xcode/DerivedData/MyRec-*/Build/Products/Release/MyRec.app`

### Testing

**Recommended:** Use Swift Package Manager for fast, lightweight testing.

```bash
# Run all tests (recommended)
swift test

# Run tests with code coverage
swift test --enable-code-coverage

# Run specific test suite
swift test --filter ResolutionTests

# Run specific test method
swift test --filter ResolutionTests/testResolutionDimensions

# Run tests in parallel
swift test --parallel
```

**Alternative:** Use Xcode for visual test runner and detailed coverage (requires Xcode test target setup):
```bash
# Run tests via Xcode (if test target configured)
xcodebuild test -project MyRec.xcodeproj -scheme MyRec -destination 'platform=macOS'

# Or use Xcode UI: Product → Test (⌘U)
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
5. User clicks Save → trimmed video exports as new file: `MyRecord-{timestamp}-trimmed.mp4`

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
- **Naming:** `MyRecord-{YYYYMMDDHHMMSS}.mp4`
- **Default Location:** `~/Movies/` (configurable)
- **Trimmed Files:** `MyRecord-{YYYYMMDDHHMMSS}-trimmed.mp4`
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

## Documentation References

- Main requirements: `docs/requirements.md`
- Implementation plan: `plan/master implementation plan.md`
- UI reference: `docs/UI quick references.md`
- Timeline: `docs/timeline index.md`
