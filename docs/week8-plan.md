# Week 8: Camera Integration & Performance Optimization

**Duration:** 5 days
**Phase:** Backend Integration - Phase 2 (Part 3)
**Goal:** Add camera overlay and optimize recording performance

---

## Overview

This week adds camera preview overlay (picture-in-picture) and focuses on performance optimization to ensure smooth recording even at 4K resolution with all features enabled.

---

## Success Criteria

- ✅ Camera overlay working (movable, resizable)
- ✅ Camera device selection functional
- ✅ CPU usage <25% during 1080P@30fps recording
- ✅ Memory footprint <250MB during recording
- ✅ No dropped frames during 30-min recording
- ✅ Smooth UI during recording (60fps)

---

## Daily Breakdown

### Day 34: Camera Capture Foundation

**Goal:** Capture camera feed and display as overlay

**Tasks:**
- [ ] Create `CameraEngine` service class
- [ ] Implement camera device enumeration (AVCaptureDevice)
- [ ] Capture camera feed using AVCaptureSession
- [ ] Create camera preview window overlay
- [ ] Test with built-in camera and external cameras

**Deliverables:**
- `CameraEngine.swift` (~250 lines)
- Camera preview window showing live feed
- Camera device selection

**Testing:**
- Built-in camera → verify preview
- External USB camera → verify preview
- Switch cameras → verify smooth transition
- No camera available → graceful handling

---

### Day 35: Camera Overlay Integration

**Goal:** Integrate camera as movable/resizable overlay in recordings

**Tasks:**
- [ ] Create draggable camera preview window
- [ ] Implement resize handles for camera window
- [ ] Save camera position/size in settings
- [ ] Composite camera feed into screen recording
- [ ] Test camera overlay in final video

**Deliverables:**
- Movable camera overlay
- Resizable camera window
- Camera composited in recording
- Position/size persistence

**Testing:**
- Drag camera window → verify position saved
- Resize camera → verify size saved
- Record with camera → verify overlay in video
- Toggle camera off → verify no overlay

---

### Day 36: Performance Profiling & CPU Optimization

**Goal:** Optimize CPU usage during recording

**Tasks:**
- [ ] Profile with Instruments (CPU, Time Profiler)
- [ ] Identify bottlenecks in encoding pipeline
- [ ] Optimize pixel buffer handling
- [ ] Implement frame skip strategy if needed
- [ ] Test CPU usage at various resolutions

**Deliverables:**
- CPU usage report (720P, 1080P, 2K, 4K)
- Optimized encoding pipeline
- Performance benchmarks documented

**Testing:**
- 1080P@30fps → verify CPU <25%
- 4K@30fps → verify CPU <40%
- Enable all features (audio, camera) → measure CPU
- Intel Mac vs Apple Silicon comparison

---

### Day 37: Memory & GPU Optimization

**Goal:** Optimize memory usage and GPU utilization

**Tasks:**
- [ ] Profile with Instruments (Allocations, Leaks)
- [ ] Fix any memory leaks
- [ ] Optimize buffer pool management
- [ ] Enable hardware acceleration where possible
- [ ] Test memory stability over long recordings

**Deliverables:**
- Memory usage report
- Zero memory leaks
- Optimized buffer management
- GPU acceleration enabled

**Testing:**
- Record for 30 minutes → verify no memory growth
- Record at 4K → verify memory <300MB
- Enable camera + audio → measure memory
- Check for leaks with Instruments

---

### Day 38: Advanced Settings & Polish

**Goal:** Add advanced recording settings and polish

**Tasks:**
- [ ] Add quality presets (Low, Medium, High, Best)
- [ ] Implement bitrate override option
- [ ] Add hardware acceleration toggle
- [ ] Create advanced settings section
- [ ] Polish camera UI and controls

**Deliverables:**
- Quality preset system
- Advanced settings panel
- Polished camera controls
- Documentation for settings

**Testing:**
- Quality presets → verify bitrate changes
- Hardware accel off → verify software encoding
- Test all preset combinations
- Settings persistence

---

## Key Files to Create/Modify

### New Files
- `MyRec/Services/Camera/CameraEngine.swift` (~250 lines)
- `MyRec/Windows/CameraOverlayWindow.swift` (~150 lines)
- `MyRec/Views/Settings/AdvancedSettingsView.swift` (~200 lines)

### Files to Modify
- `MyRec/Services/Recording/VideoEncoder.swift`
  - Add camera compositing
  - Performance optimizations
  - Hardware acceleration
- `MyRec/Services/Recording/RecordingManager.swift`
  - Integrate CameraEngine
  - Quality preset management
- `MyRec/Services/Settings/SettingsManager.swift`
  - Add camera settings
  - Add quality presets

---

## Technical Challenges

### Challenge 1: Camera Compositing Performance
**Issue:** Compositing camera overlay may be CPU-intensive
**Solution:**
- Use GPU-accelerated compositing (CoreImage)
- Optimize pixel format conversions
- Consider Metal for composition

### Challenge 2: Hardware Acceleration
**Issue:** Not all Macs support H.264 hardware encoding
**Solution:**
- Detect hardware support
- Fallback to software encoding
- Show warning if software encoding required

### Challenge 3: Memory Management
**Issue:** Large pixel buffers can consume lots of memory
**Solution:**
- Implement buffer pool with reuse
- Limit buffer queue size
- Release buffers promptly

---

## Performance Targets

### CPU Usage (1080P @ 30fps)
- Recording only: <20%
- Recording + Camera: <25%
- Recording + Camera + Audio: <25%

### Memory Footprint
- Idle: <50MB
- Recording 1080P: <200MB
- Recording 4K: <300MB

### Frame Drops
- 0% frame drops over 30-min recording
- Smooth 60fps UI during recording

### GPU Usage
- Hardware accelerated: <20% GPU
- Software encoding: <5% GPU

---

## Success Metrics

- [ ] Camera overlay works with 3+ camera devices
- [ ] CPU usage meets targets
- [ ] Memory usage meets targets
- [ ] Zero memory leaks over 1-hour recording
- [ ] Frame drops <0.1% over 30-min recording
- [ ] UI remains 60fps during recording
- [ ] Hardware acceleration working on M1+ Macs

---

## Dependencies

- AVFoundation for camera capture
- AVCaptureDevice for device enumeration
- CoreImage for GPU compositing (optional)
- Metal for advanced compositing (optional)
- VideoToolbox for hardware encoding

---

## Notes

- Focus on performance - this is critical for user experience
- Camera overlay should be optional and lightweight
- Test on both Intel and Apple Silicon Macs
- Document performance benchmarks for future reference
- Consider frame skip as last resort (quality over performance)

---

## End of Week Deliverable

**Demo:** Record a 4K video at 30fps with:
- Screen content (Xcode or browser)
- Camera overlay (bottom-right corner)
- System audio + microphone
- CPU usage <40%
- Memory <300MB
- Zero dropped frames over 5 minutes
- Perfect A/V sync maintained
