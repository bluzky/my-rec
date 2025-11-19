# Week 6: Region/Window Capture & Audio Foundation

**Duration:** 5 days
**Phase:** Backend Integration - Phase 2 (Part 1)
**Goal:** Enable region/window capture and establish audio infrastructure

---

## Overview

This week focuses on connecting the existing region selection UI to the ScreenCaptureKit backend and establishing the foundation for audio capture (system audio + microphone).

---

## Success Criteria

- ✅ Recording works with custom region (not just full screen)
- ✅ Window capture mode functional
- ✅ System audio capture working
- ✅ Microphone input working
- ✅ Audio saves to separate files (video + audio testing)

---

## Daily Breakdown

### Day 24: Region Capture Implementation

**Goal:** Connect region selection UI to ScreenCaptureKit

**Tasks:**
- [ ] Modify `ScreenCaptureEngine.setupStream()` to use region parameter
- [ ] Implement `SCContentFilter` with display cropping
- [ ] Test region capture with various sizes
- [ ] Verify video output matches selected region
- [ ] Update resolution to match region dimensions

**Deliverables:**
- Region-based recording working
- Video dimensions match selected region
- No full-screen fallback

**Testing:**
- Record 1280x720 region → verify output is 1280x720
- Record custom 800x600 region → verify output
- Multi-monitor region selection

---

### Day 25: Window Capture Implementation

**Goal:** Enable window-specific recording mode

**Tasks:**
- [ ] Implement window enumeration with `SCShareableContent.getExcludingDesktopWindows()`
- [ ] Create window picker UI (simple list for now)
- [ ] Use `SCContentFilter(desktopIndependentWindow:)` for window capture
- [ ] Test with various apps (Safari, Finder, Xcode)
- [ ] Handle window close during recording

**Deliverables:**
- Window selection dialog
- Window-only recording (no desktop background)
- Graceful handling of window closure

**Testing:**
- Record Safari window → verify only window content
- Move window during recording → verify tracking
- Close window during recording → handle error

---

### Day 26: System Audio Capture Foundation

**Goal:** Capture system audio using CoreAudio

**Tasks:**
- [ ] Create `AudioCaptureEngine` service class
- [ ] Implement system audio capture with `AVCaptureScreenInput` or ScreenCaptureKit audio
- [ ] Configure audio format (48kHz, stereo, AAC)
- [ ] Test audio capture separately (save as .aac or .m4a)
- [ ] Verify audio quality and levels

**Deliverables:**
- `AudioCaptureEngine.swift` (~200 lines)
- System audio recording to separate file
- Audio format: 48kHz, stereo, AAC

**Testing:**
- Play music → record → verify audio quality
- System sounds → verify capture
- No audio playing → verify silence (not noise)

---

### Day 27: Microphone Input Implementation

**Goal:** Add microphone audio capture

**Tasks:**
- [ ] Extend `AudioCaptureEngine` with microphone support
- [ ] Use `AVAudioEngine` for mic input
- [ ] Implement mic selection (default device + picker)
- [ ] Test mic recording separately
- [ ] Handle mic permissions properly

**Deliverables:**
- Microphone recording functional
- Microphone device selection
- Proper permission handling

**Testing:**
- Speak into mic → record → verify audio
- Test with different mic devices
- Deny mic permission → verify graceful handling

---

### Day 28: Audio-Only Testing & Integration

**Goal:** Integrate audio into recording pipeline (parallel tracks)

**Tasks:**
- [ ] Update `VideoEncoder` to support audio track
- [ ] Add `AVAssetWriterInput` for audio
- [ ] Test system audio + video recording
- [ ] Test microphone + video recording
- [ ] Test system audio + microphone + video (3 sources)

**Deliverables:**
- MP4 files with video + audio track
- System audio toggle working
- Microphone toggle working

**Testing:**
- Record video + system audio → play in QuickTime
- Record video + mic → verify both tracks
- Toggle audio off → verify video-only file

---

## Key Files to Create/Modify

### New Files
- `MyRec/Services/Audio/AudioCaptureEngine.swift` (~300 lines)
- `MyRec/Views/Capture/WindowPickerView.swift` (~150 lines)

### Files to Modify
- `MyRec/Services/Recording/ScreenCaptureEngine.swift`
  - Update `setupStream()` to use region/window
  - Add window capture support
- `MyRec/Services/Recording/VideoEncoder.swift`
  - Add audio track support
  - Configure AVAssetWriterInput for audio
- `MyRec/AppDelegate.swift`
  - Wire up window capture mode
  - Integrate audio engine

---

## Technical Challenges

### Challenge 1: ScreenCaptureKit Region Cropping
**Issue:** SCContentFilter doesn't directly support region cropping
**Solution:** Use `contentRect` parameter or post-process frames

### Challenge 2: Audio/Video Sync
**Issue:** Audio and video timestamps may drift
**Solution:** Use CMTime for precise synchronization (implement in Week 7)

### Challenge 3: Multiple Audio Sources
**Issue:** System audio + mic need mixing
**Solution:** Create separate audio tracks for now, mix in Week 7

---

## Success Metrics

- [ ] Region recording accuracy: 100%
- [ ] Window capture works with 5+ apps
- [ ] System audio capture quality: >128kbps AAC
- [ ] Microphone input quality: >128kbps AAC
- [ ] Audio-video sync drift: <100ms (basic, will improve Week 7)
- [ ] Zero crashes when switching capture modes
- [ ] Build passes with 0 errors, 0 warnings

---

## Dependencies

- ScreenCaptureKit framework (macOS 13+)
- AVFoundation for audio
- AVAudioEngine for microphone
- CoreAudio for system audio

---

## Notes

- Focus on getting audio working first (separate files OK)
- Audio mixing and perfect sync will come in Week 7
- Window capture may need fallback for older macOS versions
- Keep UI simple for now (window picker can be polished later)

---

## End of Week Deliverable

**Demo:** Record a selected region with system audio playing music + speaking into microphone → resulting MP4 has video + both audio sources audible.
