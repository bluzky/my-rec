# Week 7: Audio Integration & Recording Controls

**Duration:** 5 days
**Phase:** Backend Integration - Phase 2 (Part 2)
**Goal:** Perfect audio/video sync and implement pause/resume functionality

---

## Overview

This week focuses on advanced audio features (mixing, synchronization) and critical recording controls (pause/resume, state management). By end of week, the app should have production-quality recording capabilities.

---

## Success Criteria

- ✅ System audio + microphone mixed into single track
- ✅ Audio/video sync within ±50ms throughout entire recording
- ✅ Pause/Resume works without artifacts
- ✅ Audio levels adjustable (system audio, mic gain)
- ✅ Recording state machine robust

---

## Daily Breakdown

### Day 29: Audio Mixing Pipeline

**Goal:** Combine system audio + microphone into single audio track

**Tasks:**
- [ ] Create `AudioMixer` class with AVAudioMixerNode
- [ ] Mix system audio + mic with individual volume controls
- [ ] Configure audio format conversion (all sources → 48kHz stereo)
- [ ] Implement real-time audio level monitoring
- [ ] Test mixed audio output

**Deliverables:**
- `AudioMixer.swift` (~200 lines)
- System audio + mic in single track
- Volume controls for each source

**Testing:**
- Play music + speak → verify both audible
- Adjust system audio volume → verify change
- Adjust mic gain → verify change
- Mute mic → verify only system audio

---

### Day 30: Audio/Video Synchronization

**Goal:** Ensure perfect A/V sync throughout recording

**Tasks:**
- [ ] Implement CMTime-based synchronization
- [ ] Align audio/video timestamps from capture start
- [ ] Add sync drift monitoring (log warnings if >50ms)
- [ ] Test long recordings (10+ minutes) for drift
- [ ] Implement automatic drift correction

**Deliverables:**
- Audio/video sync within ±50ms
- Drift monitoring and logging
- Sync correction algorithm

**Testing:**
- 1-minute recording → verify sync
- 10-minute recording → verify no drift
- 30-minute recording → measure drift
- Lip sync test (record video with speaking)

---

### Day 31: Pause/Resume Foundation

**Goal:** Implement pause/resume without breaking encoding

**Tasks:**
- [ ] Add pause state to `RecordingManager`
- [ ] Implement buffer management for paused segments
- [ ] Handle GOP (Group of Pictures) alignment for clean resume
- [ ] Update UI to reflect paused state
- [ ] Test pause/resume multiple times in single recording

**Deliverables:**
- Pause/Resume working without artifacts
- Clean GOP alignment (no visual glitches)
- UI updates properly

**Testing:**
- Record → pause → resume → verify smooth playback
- Pause 5 times in one recording → verify no issues
- Pause at various frame positions → verify GOP alignment

---

### Day 32: Audio Level Meters

**Goal:** Add real-time audio level visualization

**Tasks:**
- [ ] Create audio level meter UI component
- [ ] Implement peak/RMS level calculation
- [ ] Show separate meters for system audio + microphone
- [ ] Add visual clipping indicator (red when >0dB)
- [ ] Update in real-time during recording

**Deliverables:**
- `AudioLevelMeterView.swift` (~150 lines)
- Real-time level meters in settings bar
- Clipping indicators

**Testing:**
- Loud audio → verify meter shows high level
- Silence → verify meter at minimum
- Clipping → verify red indicator
- Visual smoothness (60fps updates)

---

### Day 33: Recording State Management & Polish

**Goal:** Robust state management and error handling

**Tasks:**
- [ ] Refactor `RecordingManager` state machine
- [ ] Add error recovery for edge cases
- [ ] Implement state persistence (survive app crash)
- [ ] Add recording duration limit (optional)
- [ ] Polish state transitions and notifications

**Deliverables:**
- Robust state machine
- Error recovery
- Edge case handling

**Testing:**
- Kill app during recording → verify cleanup
- Fill disk during recording → verify error handling
- Start/stop rapidly → verify stability
- Record for 2+ hours → verify no memory leaks

---

## Key Files to Create/Modify

### New Files
- `MyRec/Services/Audio/AudioMixer.swift` (~200 lines)
- `MyRec/Views/Audio/AudioLevelMeterView.swift` (~150 lines)

### Files to Modify
- `MyRec/Services/Audio/AudioCaptureEngine.swift`
  - Add audio mixing support
  - Implement level monitoring
- `MyRec/Services/Recording/RecordingManager.swift`
  - Add pause/resume logic
  - Implement state machine refactor
  - Add sync monitoring
- `MyRec/Services/Recording/VideoEncoder.swift`
  - Handle pause/resume in encoding
  - GOP alignment logic
- `MyRec/Views/Settings/SettingsBarView.swift`
  - Add audio level meters
  - Add pause button integration

---

## Technical Challenges

### Challenge 1: Audio/Video Sync Drift
**Issue:** Long recordings may accumulate sync drift
**Solution:**
- Use AVAssetWriter's timeline (not system clock)
- Monitor drift and log warnings
- Implement periodic sync correction

### Challenge 2: Pause/Resume GOP Alignment
**Issue:** Resuming mid-GOP causes visual artifacts
**Solution:**
- Pause at keyframe boundaries
- Buffer management for clean transitions
- Force keyframe on resume if needed

### Challenge 3: Audio Mixing Latency
**Issue:** Real-time mixing may introduce latency
**Solution:**
- Use low-latency audio engine settings
- Buffer size optimization
- Test with multiple audio sources

---

## Success Metrics

- [ ] Audio/video sync: ±50ms maximum drift
- [ ] Pause/Resume: zero visual artifacts
- [ ] Audio mixing: <10ms latency
- [ ] Level meters: 60fps update rate
- [ ] State machine: 100% edge case coverage
- [ ] Memory stable during 2+ hour recording
- [ ] Zero crashes in stress testing

---

## Dependencies

- AVAudioEngine for audio mixing
- AVAssetWriter for A/V sync
- CMTime for timestamp management
- VideoToolbox for GOP control

---

## Notes

- Audio sync is critical - don't rush this
- GOP alignment may require VideoToolbox APIs
- Consider using separate audio worker thread
- Level meters should be GPU-accelerated for smoothness

---

## End of Week Deliverable

**Demo:** Record a 5-minute video with:
- System audio (music playing)
- Microphone input (speaking)
- Pause 3 times during recording
- Resume each time cleanly
- Final video has perfect A/V sync, no glitches, both audio sources audible with adjustable levels
