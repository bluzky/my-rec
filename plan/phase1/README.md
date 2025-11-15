# Phase 1: Foundation & Core Recording

**Duration:** 4 weeks (Weeks 1-4)
**Goal:** Establish solid foundation with basic screen recording capability
**Team:** 5 people

---

## Week-by-Week Plans

### Week 1: Project Kickoff & Infrastructure
**File:** `week1-tasks.md`

**Focus:** Development environment, core architecture, foundational code

**20 Development Tasks:**
- DEV-001 to DEV-004: Project setup (Git, Xcode, CI/CD, SwiftLint)
- DEV-005 to DEV-009: Core data models (Resolution, FrameRate, RecordingSettings, RecordingState, VideoMetadata)
- DEV-010 to DEV-012: Services layer (SettingsManager, PermissionManager, AppDelegate)
- DEV-013 to DEV-015: Build & documentation (Scripts, configuration, architecture docs)
- DEV-016 to DEV-020: Testing & integration (Unit tests, integration tests, code review)

**Key Deliverables:**
- 9 code files (5 models, 2 services, 2 app structure)
- 7 test files with >75% coverage
- CI/CD pipeline functional
- Build scripts created
- Architecture documented

---

### Week 2: System Tray & Region Selection
**File:** `week2-system-tray-region-selection.md`

**Focus:** User interface components and interaction

**Key Components:**
- StatusBarController with context menu
- RegionSelectionWindow with drag-to-select
- Resize handles (8 total: 4 corners + 4 edges)
- KeyboardShortcutManager (⌘⌥1, ⌘⌥2)
- SettingsBarView skeleton
- ScreenCaptureKit proof-of-concept

**Key Deliverables:**
- System tray visible and functional
- Region selection overlay working
- Keyboard shortcuts responding
- Settings bar UI (no functionality yet)

---

### Week 3: Core Recording Engine
**File:** `week3-core-recording-engine.md`

**Focus:** Screen capture and video encoding

**Key Components:**
- ScreenCaptureEngine (full integration)
- VideoEncoder with H.264
- CountdownView with animation
- RecordingManager state machine
- End-to-end recording workflow

**Key Deliverables:**
- Can record screen to MP4 file
- Frame rate maintained
- No dropped frames
- Files playable in QuickTime

---

### Week 4: File Save & Optimization
**File:** `week4-file-save-optimization.md`

**Focus:** File management, error handling, polish

**Key Components:**
- RecordingFileManager with atomic writes
- Video metadata extraction
- Comprehensive error handling
- Performance optimization
- Phase 1 completion testing

**Key Deliverables:**
- Files save reliably
- All error scenarios handled
- Performance targets met
- Phase 1 complete and tested

---

## Phase 1 Success Criteria

### Functionality
- [x] Basic screen recording (full screen, window, region)
- [x] Video encoding to H.264 MP4
- [x] File save with atomic writes
- [x] System tray integration
- [x] Region selection with resize
- [x] Keyboard shortcuts

### Quality
- [x] 85%+ test coverage
- [x] No critical bugs
- [x] Code review complete
- [x] Documentation current

### Performance
- [x] CPU < 25% @ 1080P/30FPS
- [x] Memory < 250 MB during recording
- [x] No frame drops
- [x] App launch < 1 second

---

## Technology Stack

**Language:** Swift 5.9+
**UI Framework:** SwiftUI + NSAppKit
**Capture:** ScreenCaptureKit (macOS 13+), CGDisplayStream (fallback)
**Encoding:** AVFoundation (H.264)
**File Format:** MP4
**Testing:** XCTest
**Linting:** SwiftLint
**CI/CD:** GitHub Actions

---

## File Organization

```
MyRec/
├── MyRec/
│   ├── MyRecApp.swift
│   ├── AppDelegate.swift
│   ├── Models/
│   │   ├── Resolution.swift
│   │   ├── FrameRate.swift
│   │   ├── RecordingSettings.swift
│   │   ├── RecordingState.swift
│   │   └── VideoMetadata.swift
│   ├── Services/
│   │   ├── Settings/
│   │   │   └── SettingsManager.swift
│   │   ├── Permissions/
│   │   │   └── PermissionManager.swift
│   │   ├── Recording/
│   │   │   └── RecordingManager.swift (Week 3)
│   │   ├── Capture/
│   │   │   └── ScreenCaptureEngine.swift (Week 3)
│   │   ├── Video/
│   │   │   └── VideoEncoder.swift (Week 3)
│   │   └── File/
│   │       └── RecordingFileManager.swift (Week 4)
│   ├── Views/
│   │   ├── RegionSelection/
│   │   │   └── RegionSelectionView.swift (Week 2)
│   │   ├── Countdown/
│   │   │   └── CountdownView.swift (Week 3)
│   │   └── SettingsBar/
│   │       └── SettingsBarView.swift (Week 2)
│   ├── ViewModels/
│   └── Resources/
├── MyRecTests/
└── MyRec.xcodeproj
```

---

## Development Workflow

### Daily Development

```bash
# Pull latest changes
git pull origin develop

# Create feature branch
git checkout -b feature/your-feature

# Make changes, write tests

# Run linting
swiftlint

# Run tests
./scripts/test.sh

# Commit changes
git add .
git commit -m "feat: add feature description"

# Push and create PR
git push origin feature/your-feature
```

### Code Review Process

1. Create pull request to `develop`
2. Senior developer reviews
3. Address comments
4. All checks pass (CI/CD, linting, tests)
5. Merge to `develop`

---

## Testing Strategy

### Unit Tests
- All models: 100% coverage
- All services: 85%+ coverage
- Edge cases covered
- Mocking where appropriate

### Integration Tests
- Full workflows tested
- Cross-component integration
- Platform compatibility (Intel + Apple Silicon)

### Performance Tests
- CPU/GPU profiling
- Memory leak detection
- Long-duration recordings (1+ hour)

---

## Common Commands

### Build
```bash
# Debug build
./scripts/build.sh Debug

# Release build
./scripts/build.sh Release
```

### Test
```bash
# Run all tests
./scripts/test.sh

# Run specific test
xcodebuild test -project MyRec.xcodeproj -scheme MyRec -only-testing:MyRecTests/ResolutionTests
```

### Lint
```bash
# Run linting
swiftlint

# Auto-fix issues
swiftlint autocorrect
```

### Clean
```bash
# Clean build folder
xcodebuild clean -project MyRec.xcodeproj -scheme MyRec

# Delete DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData
```

---

## Troubleshooting

### Build Fails
1. Clean build folder (⌘⇧K)
2. Delete DerivedData
3. Restart Xcode
4. Verify Swift version

### Tests Fail
1. Run single test to isolate
2. Check test dependencies
3. Verify mocks/fixtures
4. Review recent changes

### SwiftLint Errors
1. Run `swiftlint autocorrect`
2. Review .swiftlint.yml rules
3. Fix remaining issues manually

### CI/CD Fails
1. Check GitHub Actions logs
2. Run build locally first
3. Verify Xcode version matches
4. Check environment variables

---

## Phase 1 Milestones

| Week | Milestone | Status | Progress |
|------|-----------|--------|----------|
| 1 | Infrastructure Ready | ✅ 81% Complete | 17/21 tasks ✅ Build Success |
| 2 | UI Components Complete | ⏳ Planned | 0/20 tasks |
| 3 | Recording Working | ⏳ Planned | 0/20 tasks |
| 4 | Phase 1 Complete | ⏳ Planned | 0/20 tasks |

**Last Updated:** November 15, 2025

---

## Next Steps After Phase 1

**Phase 2 (Weeks 5-8): Recording Controls & Settings**
- Settings bar functionality
- Pause/resume recording
- Audio capture (system audio + microphone)
- Camera preview overlay
- Enhanced recording controls

**Preparation for Phase 2:**
- Review audio capture APIs (CoreAudio, AVAudioEngine)
- Design camera preview UI
- Plan pause/resume buffer management
- Prepare audio/video sync strategy

---

## Resources

**Internal Documentation:**
- Main requirements: `../../docs/requirements.md`
- Implementation plan: `../../docs/implementation plan.md`
- CLAUDE.md: `../../CLAUDE.md`

**External Resources:**
- [ScreenCaptureKit Docs](https://developer.apple.com/documentation/screencapturekit)
- [AVFoundation Guide](https://developer.apple.com/documentation/avfoundation)
- [SwiftUI Docs](https://developer.apple.com/documentation/swiftui)

---

**Status:** Week 1 Ready to Start ✅
**Last Updated:** November 14, 2025
