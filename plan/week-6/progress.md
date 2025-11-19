# Week 6 Progress - Region Capture & Audio Integration

**Week Goal:** Complete Phase 2 foundation by implementing region/window capture and full audio integration (system + microphone)

**Status:** 🔄 In Progress
**Start Date:** November 19, 2025
**Target Completion:** November 23, 2025 (5 days)

---

## Week Overview

This week focuses on connecting the existing region selection UI to ScreenCaptureKit and implementing complete audio capture capabilities. By the end of this week, users will be able to:

- ✅ Record full screen (already working)
- 🎯 Record specific regions (custom coordinates)
- 🎯 Record specific windows
- 🎯 Record with system audio
- 🎯 Record with microphone input
- 🎯 Record with both audio sources mixed

---

## Daily Breakdown

### Day 23 (November 19) - Region Capture Integration
**Goal:** Connect region selection UI to ScreenCaptureKit for custom region recording

**Status:** ✅ Completed

**Tasks:**
- [x] Update ScreenCaptureEngine to accept CGRect parameter
- [x] Implement SCContentFilter with custom region
- [x] Connect RegionSelectionWindow bounds to capture engine
- [x] Test region capture with various sizes
- [x] Handle edge cases (region outside screen bounds)

**Expected Outcome:** Users can select a region and record only that area ✅

---

### Day 24 (November 20) - Window Selection Integration
**Goal:** Implement window-specific recording using ScreenCaptureKit window filtering

**Status:** ⏳ Pending

**Tasks:**
- [ ] Implement window enumeration using SCShareableContent
- [ ] Create window selection UI/picker
- [ ] Implement SCContentFilter for specific windows
- [ ] Add window highlighting in selection overlay
- [ ] Test with multiple windows and displays

**Expected Outcome:** Users can select and record specific application windows

---

### Day 25 (November 21) - System Audio Capture
**Goal:** Implement system audio capture using ScreenCaptureKit audio streams

**Status:** ⏳ Pending

**Tasks:**
- [ ] Create AudioCaptureEngine service
- [ ] Implement system audio capture via ScreenCaptureKit
- [ ] Set up audio sample buffer handling
- [ ] Implement audio format conversion (PCM to AAC)
- [ ] Add audio level monitoring
- [ ] Write unit tests for audio capture

**Expected Outcome:** System audio is captured and encoded with video

---

### Day 26 (November 22) - Microphone Input
**Goal:** Implement microphone capture using AVAudioEngine

**Status:** ⏳ Pending

**Tasks:**
- [ ] Set up AVAudioEngine for microphone input
- [ ] Request microphone permissions
- [ ] Implement audio input node configuration
- [ ] Add microphone level monitoring
- [ ] Test with various audio input devices
- [ ] Write unit tests for microphone capture

**Expected Outcome:** Microphone audio is captured alongside video

---

### Day 27 (November 23) - Audio Mixing & Synchronization
**Goal:** Mix system audio and microphone, ensure perfect A/V sync

**Status:** ⏳ Pending

**Tasks:**
- [ ] Implement audio mixing (system + mic)
- [ ] Add volume controls for each audio source
- [ ] Implement audio/video timestamp synchronization
- [ ] Add drift detection and correction
- [ ] Test long recordings (30+ min) for sync accuracy
- [ ] Comprehensive A/V sync testing

**Expected Outcome:** Both audio sources mix perfectly with video, no drift

---

## Week Objectives

### Must-Have (P0)
- ✅ Region capture working (Days 23-24)
- ✅ System audio capture (Day 25)
- ✅ Microphone capture (Day 26)
- ✅ Audio/video synchronization (Day 27)

### Should-Have (P1)
- ✅ Window selection UI
- ✅ Audio level monitoring
- ✅ Multiple audio device support

### Nice-to-Have (P2)
- Volume controls for audio sources
- Audio waveform visualization
- Advanced sync diagnostics

---

## Testing Strategy

### Daily Testing
- Build passes with zero errors/warnings
- Unit tests pass (swift test)
- Manual functional testing of day's feature
- Integration testing with existing features

### End-of-Week Testing
- [ ] Full recording workflow (region + audio)
- [ ] Window recording workflow
- [ ] Audio-only recording test
- [ ] Long-duration recording (1+ hour)
- [ ] Multi-display testing
- [ ] Performance profiling

---

## Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Region capture accuracy | 100% | ⏳ |
| Window capture accuracy | 100% | ⏳ |
| Audio sync drift | < ±50ms | ⏳ |
| System audio capture | Working | ⏳ |
| Microphone capture | Working | ⏳ |
| Mixed audio quality | No distortion | ⏳ |
| Build status | 0 errors/warnings | ⏳ |
| Test pass rate | 100% | ⏳ |

---

## Risks & Mitigations

### Risk 1: ScreenCaptureKit region filtering complexity
**Severity:** Medium
**Mitigation:** Start with simple CGRect filtering, iterate based on testing

### Risk 2: Audio synchronization drift
**Severity:** High
**Mitigation:** Use CMTime-based timestamps, implement drift detection

### Risk 3: Multiple audio source mixing
**Severity:** Medium
**Mitigation:** Use AVAudioEngine mixer node, test with various devices

---

## Notes & Decisions

### Architecture Decisions
- **Audio Engine:** Use ScreenCaptureKit for system audio (macOS 13+), AVAudioEngine for mic
- **Audio Mixing:** Perform mixing in real-time before encoding
- **Sync Strategy:** Use CMTime from AVAssetWriter as canonical timeline
- **Region Capture:** Use SCContentFilter with display and rect parameters

### API Choices
- ScreenCaptureKit for region/window capture (requires macOS 13+)
- No fallback for macOS 12 region capture (full screen only)
- AVAudioEngine for microphone (cross-version compatibility)

---

## Carryover from Week 5

✅ All Week 5 objectives completed:
- ScreenCaptureEngine with full screen capture
- VideoEncoder with H.264/MP4
- FileManagerService with metadata
- Zero errors/warnings build

No blockers or carryover tasks.

---

## Next Week Preview (Week 7)

**Focus:** Pause/Resume functionality + Camera integration

Planned topics:
- Recording state management (pause/resume)
- GOP alignment for clean pause points
- Camera preview overlay
- Camera position and size controls
- Advanced recording controls

---

## Daily Status Updates

### Day 23 Update
**Date:** November 19, 2025
**Status:** ✅ Completed
**Time Spent:** ~1.75 hours (under budget)
**Completed:**
- ✅ ScreenCaptureEngine updated with region support
- ✅ Coordinate conversion implemented (NSWindow → ScreenCaptureKit)
- ✅ Region validation with bounds checking and minimum size (100×100)
- ✅ Unit tests created (ScreenCaptureEngineTests.swift)
- ✅ Build passes with no errors
**Blockers:** None
**Notes:**
- Integration simpler than expected - most plumbing already existed
- ScreenCaptureEngine already had region parameter but wasn't using it
- Main work was implementing region usage in setupStream()
- Added validateRegion() and convertToScreenCaptureCoordinates() methods
- All edge cases handled with proper logging
- Manual test guide created for verification

### Day 24 Update
**Date:** November 20, 2025
**Status:** Not started
**Completed:** -
**Blockers:** -
**Notes:** -

### Day 25 Update
**Date:** November 21, 2025
**Status:** Not started
**Completed:** -
**Blockers:** -
**Notes:** -

### Day 26 Update
**Date:** November 22, 2025
**Status:** Not started
**Completed:** -
**Blockers:** -
**Notes:** -

### Day 27 Update
**Date:** November 23, 2025
**Status:** Not started
**Completed:** -
**Blockers:** -
**Notes:** -

---

**Last Updated:** November 19, 2025
**Updated By:** Development Team
