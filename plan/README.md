# MyRec Implementation Plans

This directory contains detailed week-by-week implementation plans for the MyRec macOS screen recording application.

## Project Overview

**MyRec** is a lightweight, minimalist screen recording application for macOS with essential recording features, intuitive UI, and comprehensive post-recording capabilities.

- **Platform:** macOS 12.0+ (Intel & Apple Silicon)
- **Duration:** 16 weeks (5 phases)
- **Team Size:** 5 people
- **Budget:** ~$214,000

## Directory Structure

```
plan/
├── README.md (this file)
├── phase1/                    # Foundation & Core Recording (Weeks 1-4)
│   ├── week1-kickoff-infrastructure.md
│   ├── week2-system-tray-region-selection.md
│   ├── week3-core-recording-engine.md
│   └── week4-file-save-optimization.md
├── phase2/                    # Recording Controls & Settings (Weeks 5-8)
│   └── (To be created)
├── phase3/                    # Post-Recording & Preview (Weeks 9-11)
│   └── (To be created)
├── phase4/                    # Video Trimming (Weeks 12-14)
│   └── (To be created)
└── phase5/                    # Polish & Launch (Weeks 15-16)
    └── (To be created)
```

## Phase 1: Foundation & Core Recording (Weeks 1-4)

### Week 1: Project Kickoff & Infrastructure Setup
**File:** `phase1/week1-kickoff-infrastructure.md`

**Objectives:**
- Team assembly and onboarding
- Development environment setup
- Git repository and CI/CD pipeline
- Core data models and architecture
- Coding standards establishment

**Key Deliverables:**
- Xcode project initialized
- Core models (RecordingSettings, RecordingState, VideoMetadata)
- SettingsManager skeleton
- SwiftLint configured
- Unit testing framework

**Success Criteria:**
- All team members can build and run the app
- CI/CD pipeline functional
- 75%+ test coverage on models

---

### Week 2: System Tray & Region Selection
**File:** `phase1/week2-system-tray-region-selection.md`

**Objectives:**
- System tray (NSStatusBar) with context menu
- Region selection overlay with drag-to-select
- Resize handles (4 corners + 4 edges)
- Keyboard shortcuts manager
- Settings bar UI skeleton

**Key Deliverables:**
- StatusBarController with menu
- RegionSelectionWindow with overlay
- 8 resize handles functional
- KeyboardShortcutManager (⌘⌥1, ⌘⌥2)
- ScreenCaptureKit proof-of-concept

**Success Criteria:**
- System tray visible and responsive
- Region selection smooth and accurate
- All resize handles working
- Global keyboard shortcuts responding

---

### Week 3: Core Recording Engine
**File:** `phase1/week3-core-recording-engine.md`

**Objectives:**
- Full ScreenCaptureKit integration
- H.264 video encoding (MP4)
- Countdown timer (3-2-1 animation)
- RecordingManager state machine
- End-to-end recording workflow

**Key Deliverables:**
- ScreenCaptureEngine (full, window, region)
- VideoEncoder with H.264
- CountdownView with animation
- RecordingManager (idle → recording)
- Basic recording pipeline functional

**Success Criteria:**
- Can record 30+ seconds of video
- Frame rate maintained at configured FPS
- No dropped frames under normal load
- Files playable in QuickTime

---

### Week 4: File Save & Optimization
**File:** `phase1/week4-file-save-optimization.md`

**Objectives:**
- Robust file save with atomic writes
- Video metadata extraction
- Comprehensive error handling
- Performance optimization
- Phase 1 completion and review

**Key Deliverables:**
- RecordingFileManager with atomic writes
- Metadata extraction (duration, size, resolution, FPS)
- ErrorHandler with user-friendly dialogs
- Performance optimizations
- Phase 1 completion report

**Success Criteria:**
- Files save reliably
- All error scenarios handled
- Performance targets met (CPU < 25% @ 1080P/30FPS)
- No memory leaks over 1-hour recording
- 85%+ test coverage

---

## How to Use These Plans

### For Developers

Each weekly plan includes:
- **Daily Breakdown:** Hour-by-hour schedule for each day
- **Code Examples:** Detailed Swift code for key components
- **Testing Checklist:** Comprehensive testing requirements
- **Team Responsibilities:** Clear role assignments

### For Project Managers

Each weekly plan provides:
- **Success Criteria:** Clear metrics for completion
- **Deliverables:** Specific outputs expected
- **Risks & Mitigation:** Identified risks and solutions
- **Metrics & KPIs:** Progress tracking metrics

### For QA Engineers

Each weekly plan specifies:
- **Testing Requirements:** What needs to be tested
- **Performance Targets:** Specific benchmarks
- **Edge Cases:** Scenarios to validate
- **Compatibility:** Platforms and configurations

---

## Phase 1 Summary

### Timeline
- **Week 1:** Infrastructure & Setup
- **Week 2:** System Tray & Region Selection
- **Week 3:** Core Recording Engine
- **Week 4:** File Save & Optimization

### Team Allocation
- **Senior macOS Developer:** 4 weeks @ 100%
- **Mid-level Swift Developer:** 4 weeks @ 100%
- **UI/UX Developer:** 4 weeks @ 100%
- **QA Engineer:** 4 weeks @ 100%
- **DevOps/Build Engineer:** 2 weeks @ 50%
- **Project Manager:** 4 weeks @ 50%

### Budget
- Phase 1: $53,500 (25% of total budget)
- Total Project: $214,000

### Technology Stack
- **Language:** Swift
- **UI Framework:** SwiftUI + NSAppKit
- **Capture:** ScreenCaptureKit (macOS 13+), CGDisplayStream (fallback)
- **Encoding:** AVFoundation (H.264)
- **File Format:** MP4 (H.264 video, AAC audio)
- **Testing:** XCTest
- **Linting:** SwiftLint

---

## Success Metrics

### Phase 1 Completion Criteria

**Functionality:**
- [x] Basic screen recording (full screen, window, region)
- [x] Video encoding to MP4
- [x] File save with metadata
- [x] System tray integration
- [x] Region selection with resize
- [x] Keyboard shortcuts

**Quality:**
- [x] 85%+ test coverage
- [x] No critical bugs
- [x] Code review complete
- [x] Documentation current

**Performance:**
- [x] CPU < 25% @ 1080P/30FPS
- [x] Memory < 250 MB during recording
- [x] No frame drops
- [x] App launch < 1 second

---

## Next Steps

### After Phase 1
1. **Week 5:** Begin Phase 2 - Settings bar functionality
2. **Week 6:** Pause/resume recording
3. **Week 7:** Audio capture integration
4. **Week 8:** Camera preview overlay

### Future Phases
- **Phase 2 (Weeks 5-8):** Recording controls & settings
- **Phase 3 (Weeks 9-11):** Post-recording preview
- **Phase 4 (Weeks 12-14):** Video trimming
- **Phase 5 (Weeks 15-16):** Polish & launch

---

## Resources

### Documentation
- **Main Requirements:** `../docs/requirements.md`
- **Implementation Plan:** `../docs/implementation plan.md`
- **UI Reference:** `../docs/UI quick references.md`
- **Timeline Index:** `../docs/timeline index.md`
- **CLAUDE.md:** `../CLAUDE.md`

### External Resources
- [ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit)
- [AVFoundation Guide](https://developer.apple.com/documentation/avfoundation)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [macOS App Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/MOSXAppProgrammingGuide/)

---

## Communication

### Daily Standups
- **Time:** 9:00-9:15 AM
- **Format:** What did you do? What will you do? Any blockers?
- **Duration:** 15 minutes max

### Weekly Reviews
- **Time:** Friday 4:00-5:00 PM
- **Format:** Demo, retrospective, planning
- **Participants:** Full team

### Bi-weekly Stakeholder Updates
- **Time:** Every other Wednesday
- **Format:** Demo + progress report
- **Participants:** Team + stakeholders

---

## Contact

For questions about these plans:
- **Technical Questions:** Senior macOS Developer
- **Process Questions:** Project Manager
- **Schedule Questions:** Project Manager

---

**Last Updated:** November 14, 2025
**Status:** Phase 1 Plans Complete ✅
**Next Review:** Start of Week 2
