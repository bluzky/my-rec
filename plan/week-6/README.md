# Week 6 - Region Capture & Audio Integration

**Dates:** November 19-23, 2025 (5 days)
**Phase:** Phase 2 - Recording Controls & Settings
**Status:** 🔄 Ready to Start

---

## Week Goal

Complete the foundation of Phase 2 by implementing:
1. **Region & Window Capture** - Connect existing UI to ScreenCaptureKit
2. **System Audio Capture** - Record application audio output
3. **Microphone Input** - Record voice commentary
4. **Audio Mixing** - Blend system audio + microphone
5. **A/V Synchronization** - Ensure perfect sync for all recordings

By the end of this week, MyRec will support full multi-source recording with professional-grade audio.

---

## Daily Plans

### 📅 Day 23 (Nov 19) - Region Capture Integration
**File:** [`day23-plan.md`](./day23-plan.md)

**Objective:** Connect region selection UI to ScreenCaptureKit

**Key Tasks:**
- Update ScreenCaptureEngine to accept CGRect parameter
- Implement SCContentFilter with custom region
- Handle coordinate system conversion
- Edge case validation (bounds, minimum size)
- Test with various region sizes

**Expected Outcome:** Users can select a custom region and record only that area

**Time Estimate:** ~4.5 hours + 1.5hr buffer

---

### 📅 Day 24 (Nov 20) - Window Selection Integration
**File:** [`day24-plan.md`](./day24-plan.md)

**Objective:** Implement window-specific recording

**Key Tasks:**
- Create RecordableWindow model
- Build WindowEnumerationService
- Create WindowPickerView UI
- Update ScreenCaptureEngine for window mode
- Implement window highlighting

**Expected Outcome:** Users can select and record specific application windows

**Time Estimate:** ~6.5 hours

---

### 📅 Day 25 (Nov 21) - System Audio Capture
**File:** [`day25-plan.md`](./day25-plan.md)

**Objective:** Capture system audio using ScreenCaptureKit

**Key Tasks:**
- Create AudioCaptureEngine service
- Enable audio in ScreenCaptureKit stream
- Implement AAC encoding
- Add audio level monitoring UI
- Implement timestamp synchronization

**Expected Outcome:** System audio captured and encoded with video

**Time Estimate:** ~7.5 hours

---

### 📅 Day 26 (Nov 22) - Microphone Input
**File:** [`day26-plan.md`](./day26-plan.md)

**Objective:** Add microphone capture using ScreenCaptureKit microphone output (macOS 15+)

**Key Tasks:**
- Wire `.microphone` output from `SCStream`
- Update settings UI to control mic capture
- Handle permissions properly
- Add mic level indicator

**Expected Outcome:** Microphone audio captured alongside video

**Time Estimate:** ~6.25 hours

---

### 📅 Day 27 (Nov 22) - Audio Integration Testing ✅ COMPLETE
**File:** [`day27-plan.md`](./day27-plan.md)

**Objective:** Verify ScreenCaptureKit can capture both system audio and microphone independently

**Status:** ✅ COMPLETE - Phase 1 Successful

**Phase 1 Completed:**
- ✅ Wire ScreenCaptureKit microphone capture
- ✅ Make audio toggles mutually exclusive
- ✅ Update AppDelegate to pass audio flags
- ✅ Remove AudioCaptureEngine completely
- ✅ Fix VideoEncoder to write audio directly
- ✅ Test system audio recording → Working perfectly ✅
- ✅ Test microphone recording → Working perfectly ✅

**Key Achievement:**
Both system audio and microphone now record successfully via ScreenCaptureKit to MP4 files using a simplified architecture (no AVAudioEngine complexity).

**Phase 2 (Deferred):**
Audio mixing (system + microphone simultaneously) can be implemented in future sprint if needed.

**Time Spent:** ~2 hours

---

## Week Success Criteria

### Must Complete (P0)
- [x] Region capture functional
- [x] Window selection working
- [x] System audio capture
- [x] Microphone capture
- [x] Audio mixing implementation
- [x] A/V sync verified

### Should Complete (P1)
- [x] Audio level indicators
- [x] Volume controls
- [x] Device selection UI
- [x] Coordinate system handling
- [x] Long recording stability

### Nice to Have (P2)
- [ ] Audio waveform visualization
- [ ] Advanced sync diagnostics
- [ ] Audio filters/effects
- [ ] Noise reduction

---

## Technical Milestones

### New Components
- `ScreenCaptureEngine` - Enhanced with region/window modes
- `AudioCaptureEngine` - System audio handling
- `ScreenCaptureKit microphone stream` - Mic input via `.microphone` output (macOS 15+)
- `AudioMixerEngine` - Real-time audio mixing
- `SyncMonitor` - A/V drift detection
- `WindowEnumerationService` - Window listing
- `RecordableWindow` - Window model

### New UI Components
- `WindowPickerView` - Window selection dialog
- `AudioLevelIndicator` - Level monitoring
- `VolumeControlView` - Mix controls
- `WindowHighlightOverlay` - Window highlighting

---

## Testing Strategy

### Daily Testing
Each day includes:
- Unit tests for new components
- Manual functional testing
- Integration testing with existing features
- Build verification (zero errors/warnings)

### End-of-Week Testing
Comprehensive testing includes:
- **30-minute long recording** - Verify stability
- **Multi-source audio** - System + mic mixing
- **A/V sync verification** - ±50ms tolerance
- **Performance profiling** - CPU/memory usage
- **Multi-display testing** - Various configurations

---

## Quality Metrics

| Metric | Target | Tracking |
|--------|--------|----------|
| Build Status | 0 errors/warnings | Daily |
| Test Pass Rate | 100% | Daily |
| A/V Sync Drift | < ±50ms | Day 27 |
| Region Capture Accuracy | 100% | Day 23 |
| Window Tracking | 100% | Day 24 |
| Audio Quality | No distortion | Days 25-27 |
| Long Recording Stability | 30+ min | Day 27 |

---

## Known Risks

### High Risk
1. **Audio sync drift in long recordings**
   - Mitigation: CMTime-based sync, drift detection
   - Test: 30+ minute recordings

2. **ScreenCaptureKit region limitations**
   - Mitigation: Verify API capabilities early
   - Fallback: Full screen with post-crop

### Medium Risk
3. **Multiple audio source mixing complexity**
   - Mitigation: Use AVAudioEngine mixer node
   - Test: Various device combinations

4. **Coordinate system conversion errors**
   - Mitigation: Visual debugging, known coordinates
   - Test: Edge cases and multi-display

---

## Dependencies

### External APIs
- **ScreenCaptureKit** (macOS 13+) - Region/window/audio capture
- **AVAudioEngine** - Microphone input
- **AVAssetWriter** - Audio/video encoding
- **CoreAudio** - Audio device enumeration

### Internal Dependencies
- All Week 5 components must be complete:
  - ✅ ScreenCaptureEngine (full screen)
  - ✅ VideoEncoder
  - ✅ FileManagerService
  - ✅ RecordingManager

---

## Progress Tracking

Track progress in [`progress.md`](./progress.md):
- Daily status updates
- Blockers and resolutions
- Lessons learned
- Carryover tasks

---

## Week 7 Preview

After completing Week 6, Week 7 will focus on:
- **Pause/Resume Functionality** - Recording state management
- **GOP Alignment** - Clean pause points in video
- **Camera Integration** - Camera preview overlay
- **Advanced Controls** - Camera positioning, size adjustment

---

## Resources

### Documentation
- [ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit)
- [AVAudioEngine Guide](https://developer.apple.com/documentation/avfoundation/avaudioengine)
- [Audio/Video Sync Best Practices](https://developer.apple.com/documentation/avfoundation/media_assets_playback_and_editing/creating_a_basic_video_player_ios_and_tvos/synchronizing_playback)

### Reference Implementations
- Week 5 completion (full screen recording)
- Region selection UI (Week 2-3)
- Settings persistence (Week 1)

---

## File Structure

```
week-6/
├── README.md                    # This file - Week overview
├── progress.md                  # Daily progress tracking
├── day23-plan.md               # Region capture plan
├── day24-plan.md               # Window selection plan
├── day25-plan.md               # System audio plan
├── day26-plan.md               # Microphone input plan
└── day27-plan.md               # Audio mixing & sync plan
```

---

**Created:** November 19, 2025
**Last Updated:** November 19, 2025
**Status:** Ready to begin Day 23
