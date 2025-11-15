# MyRec - macOS Screen Recording App

A lightweight, minimalist screen recording application for macOS with essential recording features, intuitive UI, and comprehensive post-recording capabilities including video trimming.

<div align="center">

**Platform:** macOS 12.0+ (Intel & Apple Silicon)
**Language:** Swift 5.9+
**Frameworks:** AVFoundation, ScreenCaptureKit, SwiftUI

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com)
[![Swift Version](https://img.shields.io/badge/swift-5.9+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-Proprietary-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)](https://www.apple.com/macos)

</div>

---

## Features

### Core Recording
- **Multiple Resolution Support:** 720P, 1080P, 2K, 4K
- **Variable Frame Rates:** 15, 24, 30, 60 FPS
- **Audio Capture:** System audio, microphone, or both
- **Camera Integration:** Picture-in-picture webcam overlay
- **Cursor Control:** Toggle cursor visibility in recordings

### User Interface
- **System Tray App:** Minimal menu bar presence
- **Region Selection:** Custom recording areas with resize handles
- **Settings Bar:** Quick access to recording preferences
- **Countdown Timer:** 3-2-1 countdown before recording starts

### Post-Recording
- **Video Preview:** Immediate playback after recording
- **Video Trimming:** Edit start/end points with frame precision
- **File Management:** Organized saves to ~/Movies/ (configurable)
- **Metadata:** Track duration, file size, resolution, and creation date

---

## Quick Start

### Prerequisites

- **macOS 12.0 or later** (Monterey, Ventura, Sonoma, or Sequoia)
- **Xcode 15.0 or later** (for development)
- **Swift 5.9 or later** (included with Xcode)

### Installation (Development)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourcompany/myrec.git
   cd myrec/MyRec
   ```

2. **Open the project:**
   ```bash
   open MyRec.xcodeproj
   ```

3. **Build and run:**
   - Press `⌘R` in Xcode, or
   - Run the build script:
     ```bash
     ./scripts/build.sh Debug
     ```

4. **Grant permissions:**
   - On first launch, grant screen recording permission
   - Grant microphone and camera permissions as needed

---

## Development

### Project Structure

```
MyRec/
├── MyRec/                      # Main application code
│   ├── Models/                 # Data models
│   │   ├── Resolution.swift
│   │   ├── FrameRate.swift
│   │   ├── RecordingSettings.swift
│   │   ├── RecordingState.swift
│   │   └── VideoMetadata.swift
│   ├── Services/               # Business logic services
│   │   ├── Settings/
│   │   │   └── SettingsManager.swift
│   │   ├── Permissions/
│   │   │   └── PermissionManager.swift
│   │   └── Recording/          # (Week 3)
│   ├── Views/                  # SwiftUI views (Week 2+)
│   ├── ViewModels/             # View models (Week 2+)
│   ├── Utilities/              # Helper utilities
│   ├── Resources/              # Assets and resources
│   ├── AppDelegate.swift       # App lifecycle
│   └── MyRecApp.swift          # SwiftUI app entry point
├── MyRecTests/                 # Unit tests
│   ├── Models/
│   └── ...
├── scripts/                    # Build and utility scripts
│   ├── build.sh
│   └── test.sh
├── docs/                       # Documentation
│   ├── architecture.md
│   ├── implementation plan.md
│   └── requirements.md
└── README.md                   # This file
```

### Building

```bash
# Build for Debug (development)
./scripts/build.sh Debug

# Build for Release (distribution)
./scripts/build.sh Release

# Build universal binary (Intel + Apple Silicon)
xcodebuild -project MyRec.xcodeproj \
  -scheme MyRec \
  -configuration Release \
  -arch x86_64 -arch arm64 \
  ONLY_ACTIVE_ARCH=NO
```

**Build output location:**
- Debug: `~/Library/Developer/Xcode/DerivedData/MyRec-*/Build/Products/Debug/MyRec.app`
- Release: `~/Library/Developer/Xcode/DerivedData/MyRec-*/Build/Products/Release/MyRec.app`

### Testing

**Primary Testing:** Swift Package Manager (recommended)

```bash
# Run all tests
swift test

# Run with code coverage
swift test --enable-code-coverage

# Run specific test suite
swift test --filter ResolutionTests

# Run specific test method
swift test --filter ResolutionTests/testResolutionDimensions

# Run tests in parallel
swift test --parallel
```

**Current Test Status:**
- ✅ 23 tests across 7 test files
- ✅ 100% pass rate
- ✅ ~85-90% code coverage
- ✅ Execution time: ~0.05s

**Alternative:** Use Xcode for visual test runner (optional)
```bash
# Run tests via Xcode (requires test target setup)
xcodebuild test -project MyRec.xcodeproj -scheme MyRec -destination 'platform=macOS'
```

### Code Quality

```bash
# Run SwiftLint
swiftlint lint

# Auto-fix linting issues
swiftlint --fix

# Lint specific files
swiftlint lint --path MyRec/Models/
```

**Current Status:** 0 violations ✅

---

## Architecture

MyRec follows a clean, multi-layer architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (SwiftUI + NSAppKit)            │
│  - System Tray Controller                                   │
│  - Region Selection Overlay                                 │
│  - Settings Bar                                             │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Core Services Layer                      │
│  - RecordingManager (state machine)                         │
│  - SettingsManager (UserDefaults persistence)               │
│  - PermissionManager (screen/audio/camera)                  │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Video/Audio Capture & Processing               │
│  - ScreenCaptureEngine (ScreenCaptureKit)                   │
│  - VideoEncoder (H.264, MP4)                                │
└─────────────────────────────────────────────────────────────┘
```

For detailed architecture documentation, see [docs/architecture.md](docs/architecture.md).

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| **Language** | Swift 5.9+ |
| **UI Framework** | SwiftUI + NSAppKit |
| **Screen Capture** | ScreenCaptureKit (macOS 13+), CGDisplay (macOS 12) |
| **Video Encoding** | AVFoundation (H.264) |
| **Audio** | CoreAudio, AVAudioEngine |
| **File Format** | MP4 (ISO Base Media) |
| **Persistence** | UserDefaults |
| **Testing** | XCTest |
| **CI/CD** | GitHub Actions |
| **Code Quality** | SwiftLint |

---

## Usage

### First Launch

1. **Launch the app:**
   - The app icon appears in the menu bar (no dock icon)
   - Click the icon to see the menu

2. **Grant permissions:**
   - Screen recording permission (required)
   - Microphone permission (optional, for audio recording)
   - Camera permission (optional, for webcam overlay)

3. **Configure settings:**
   - Set default resolution and frame rate
   - Choose save location (default: ~/Movies/)
   - Configure keyboard shortcuts

### Recording a Video

1. **Start recording:**
   - Click menu bar icon → "Start Recording"
   - Or press `⌘⌥1` (default shortcut)

2. **Select region:**
   - Drag to select recording area
   - Resize with handles
   - Adjust settings in the settings bar

3. **Begin recording:**
   - Click "Record" button
   - 3-2-1 countdown begins
   - Recording starts

4. **Control recording:**
   - Pause: `⌘⌥1` or menu bar button
   - Stop: `⌘⌥2` or menu bar button

5. **Review and save:**
   - Preview window opens automatically
   - Trim video if needed
   - Save to configured location

### Keyboard Shortcuts

| Action | Shortcut | Customizable |
|--------|----------|--------------|
| Start/Pause Recording | `⌘⌥1` | ✅ |
| Stop Recording | `⌘⌥2` | ✅ |
| Open Settings | `⌘⌥,` | ✅ |
| Play/Pause (Trim Dialog) | `Space` | - |
| Previous Frame (Trim) | `←` | - |
| Next Frame (Trim) | `→` | - |

---

## Configuration

### Settings

All settings are persisted in UserDefaults and configured via:
- **Settings Window:** `⌘⌥,`
- **Settings Bar:** During region selection

### Available Options

**Recording Settings:**
- Resolution: 720P, 1080P, 2K, 4K
- Frame Rate: 15, 24, 30, 60 FPS
- Audio: System audio on/off
- Microphone: Microphone on/off
- Camera: Webcam overlay on/off
- Cursor: Cursor visibility on/off

**App Settings:**
- Save Path: Custom directory (default: ~/Movies/)
- Launch at Login: Auto-start with macOS
- Keyboard Shortcuts: Customize hotkeys

---

## File Format

### Video Specifications

| Setting | Value |
|---------|-------|
| **Container** | MP4 (ISO Base Media) |
| **Video Codec** | H.264 |
| **Audio Codec** | AAC |
| **Audio Bitrate** | 128-256 kbps |
| **Sample Rate** | 48 kHz |
| **Channels** | Stereo |

### Bitrates (Adaptive)

| Resolution | FPS | Bitrate |
|------------|-----|---------|
| 720P | 30 | ~2.5 Mbps |
| 1080P | 30 | ~5 Mbps |
| 2K | 30 | ~8 Mbps |
| 4K | 30 | ~15 Mbps |

### File Naming

- **Original:** `REC-YYYYMMDDHHMMSS.mp4`
- **Trimmed:** `REC-YYYYMMDDHHMMSS-trimmed.mp4`

**Example:** `REC-20251115143022.mp4` (recorded on Nov 15, 2025 at 2:30:22 PM)

---

## Performance

### System Requirements

**Minimum:**
- macOS 12.0 (Monterey)
- Intel Core i5 or Apple M1
- 4 GB RAM
- 1 GB free disk space

**Recommended:**
- macOS 13.0+ (Ventura or later)
- Intel Core i7 or Apple M1 Pro/Max
- 8 GB RAM
- SSD with 10+ GB free space

### Performance Targets

| State | Memory | CPU | GPU |
|-------|--------|-----|-----|
| **Idle** | < 50 MB | < 0.1% | - |
| **Recording (1080P @ 30FPS)** | 150-250 MB | 15-25% | 10-20% |

**Critical Requirements:**
- Audio/video sync: ± 50ms throughout entire session
- Pause/resume state switch: < 100ms
- Frame seek (trim dialog): < 200ms
- App launch: < 1 second

---

## Troubleshooting

### Common Issues

#### "Screen Recording Permission Required"

**Cause:** App doesn't have screen recording permission

**Solution:**
1. Open **System Settings** → **Privacy & Security** → **Screen Recording**
2. Enable MyRec in the list
3. Restart MyRec

#### Build Fails with SwiftLint Errors

**Cause:** SwiftLint sandbox restrictions

**Solution:**
1. Open `MyRec.xcodeproj` in Xcode
2. Select **MyRec** target → **Build Phases**
3. Find **Run Script** phase (SwiftLint)
4. Uncheck or delete temporarily
5. See `CLAUDE.md` for detailed troubleshooting

#### Tests Don't Run

**Cause:** Test target not configured

**Solution:**
See `docs/week1-remaining-setup.md` for step-by-step instructions to:
1. Create MyRecTests target
2. Add test files to target
3. Configure test scheme

#### App Doesn't Appear in Menu Bar

**Cause:** App crashed on launch or permissions denied

**Solution:**
1. Check Console.app for crash logs
2. Verify screen recording permission
3. Rebuild the app: `./scripts/build.sh Debug`

---

## Development Roadmap

### Phase 1: Foundation & Core Recording (Weeks 1-4)
- ✅ Week 1: Project setup, models, services (**81% complete**)
- Week 2: System tray, region selection
- Week 3: Recording engine
- Week 4: File management

### Phase 2: Recording Controls & Settings (Weeks 5-8)
- Week 5-6: Settings UI
- Week 7-8: Keyboard shortcuts

### Phase 3: Post-Recording & Preview (Weeks 9-11)
- Week 9-10: Preview window
- Week 11: Video playback

### Phase 4: Video Trimming (Weeks 12-14)
- Week 12-13: Trim functionality
- Week 14: Export and validation

### Phase 5: Polish & Launch (Weeks 15-16)
- Week 15: Optimization and testing
- Week 16: Distribution and release

For detailed timeline, see [docs/implementation plan.md](docs/implementation%20plan.md).

---

## Contributing

### Code Style

- Follow Swift naming conventions
- Run SwiftLint before committing
- Write tests for new features
- Update documentation

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes, commit
git add .
git commit -m "Add feature description"

# Push and create pull request
git push origin feature/your-feature-name
```

### Testing Requirements

- Unit tests for all models and services
- Integration tests for workflows
- Minimum 75% code coverage
- All tests must pass before merge

---

## Documentation

- **Architecture:** [docs/architecture.md](docs/architecture.md)
- **Requirements:** [docs/requirements.md](docs/requirements.md)
- **Implementation Plan:** [docs/implementation plan.md](docs/implementation%20plan.md)
- **Build Instructions:** [CLAUDE.md](CLAUDE.md)
- **Code Review:** [docs/week1-code-review.md](docs/week1-code-review.md)

---

## License

Copyright © 2025 Your Company. All rights reserved.

This software is proprietary and confidential. Unauthorized copying, distribution, or use is strictly prohibited.

---

## Support

### Reporting Issues

Found a bug? Please report it:
1. Check existing issues
2. Create a new issue with:
   - Description of the problem
   - Steps to reproduce
   - Expected vs. actual behavior
   - System information (macOS version, hardware)
   - Relevant logs or screenshots

### Feature Requests

Have an idea? We'd love to hear it:
1. Search existing feature requests
2. Open a new issue with the "enhancement" label
3. Describe the feature and use case

---

## Acknowledgments

- **Apple** - For ScreenCaptureKit, AVFoundation, and macOS frameworks
- **Swift Community** - For language and tooling support
- **Contributors** - For code, testing, and feedback

---

## Project Status

**Current Version:** v0.1.0 (Week 1 - Development)
**Status:** 🚧 In Development
**Week 1 Progress:** 81% complete (17/21 tasks)
**Build Status:** ✅ Passing
**SwiftLint:** ✅ 0 violations
**Tests:** 🟡 22 tests created (pending integration)

---

<div align="center">

**Made with ❤️ for macOS**

[Website](https://yourcompany.com) • [Documentation](docs/) • [Support](https://github.com/yourcompany/myrec/issues)

</div>
