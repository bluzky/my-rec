# Day 23 - Region Capture Manual Testing Guide

**Date:** November 19, 2025
**Purpose:** Verify region capture integration works correctly

---

## Prerequisites

1. Build and run the app: `xcodebuild -project MyRec.xcodeproj -scheme MyRec -configuration Debug`
2. Grant screen recording permission when prompted
3. Have QuickTime Player or another video player ready

---

## Test Scenarios

### Test 1: Small Region Capture
**Goal:** Verify small regions work correctly

**Steps:**
1. Click "Start Recording" from status bar menu
2. Draw a small region: ~400×300 pixels
3. Click Record button
4. Wait 5 seconds
5. Click Stop from status bar

**Expected Results:**
- ✅ Recording captures only the selected region
- ✅ Video dimensions match region size (~400×300)
- ✅ Console shows: "📐 Using custom region: ..."
- ✅ Console shows: "📐 Output size: 400x300" (approximately)
- ✅ No black bars in the video

**Console Output to Look For:**
```
📐 Using custom region: (x, y, width, height)
📐 SCK coordinates: (x, y, width, height)
📐 Output size: WxH
```

---

### Test 2: Large Region Capture
**Goal:** Verify large regions work correctly

**Steps:**
1. Click "Start Recording"
2. Draw a large region: ~1600×1200 pixels
3. Click Record
4. Wait 5 seconds
5. Click Stop

**Expected Results:**
- ✅ Recording captures the full selected region
- ✅ Video dimensions match region size
- ✅ No performance degradation
- ✅ File size appropriate for region size

---

### Test 3: Edge Region
**Goal:** Verify regions at screen edges work

**Steps:**
1. Click "Start Recording"
2. Position region at top-left corner of screen
3. Click Record
4. Wait 5 seconds
5. Click Stop

**Expected Results:**
- ✅ No clipping or artifacts
- ✅ Coordinates handled correctly
- ✅ Video shows correct screen content

---

### Test 4: Center Region
**Goal:** Verify centered regions work

**Steps:**
1. Click "Start Recording"
2. Position region in center of screen (~800×600)
3. Click Record
4. Move mouse around inside the region
5. Wait 5 seconds
6. Click Stop

**Expected Results:**
- ✅ Mouse cursor visible in recording
- ✅ Only the selected region content is captured
- ✅ Coordinate conversion correct

---

### Test 5: Minimum Size Validation
**Goal:** Verify minimum size enforcement

**Steps:**
1. Click "Start Recording"
2. Try to draw a very small region (< 100×100)
3. Click Record
4. Check console output

**Expected Results:**
- ✅ Console shows: "⚠️ Region adjusted from ... to ..."
- ✅ Region expanded to at least 100×100
- ✅ Recording still works

---

### Test 6: Oversized Region
**Goal:** Verify region clamping to screen bounds

**Steps:**
1. Click "Start Recording"
2. Draw region extending beyond screen edge
3. Click Record
4. Check console output

**Expected Results:**
- ✅ Console shows: "⚠️ Region adjusted from ... to ..."
- ✅ Region clamped to screen bounds
- ✅ Recording works without errors

---

### Test 7: Different Aspect Ratios
**Goal:** Verify various aspect ratios

**Test Cases:**
- **16:9 region:** 1280×720
- **4:3 region:** 800×600
- **21:9 region:** 2560×1080 (if screen allows)
- **Square region:** 600×600

**Expected Results:**
- ✅ All aspect ratios captured correctly
- ✅ No stretching or distortion
- ✅ Video plays back with correct aspect ratio

---

## Verification Checklist

After each test, verify:

- [ ] **Console Logs:**
  - [ ] "📐 Using custom region: ..." appears
  - [ ] "📐 SCK coordinates: ..." appears
  - [ ] "📐 Output size: ..." matches expected dimensions
  - [ ] No error messages

- [ ] **Video Output:**
  - [ ] File created in ~/Movies/
  - [ ] Video plays correctly
  - [ ] Dimensions match selected region
  - [ ] No black bars or artifacts
  - [ ] Content matches expected screen area

- [ ] **App Behavior:**
  - [ ] No crashes or freezes
  - [ ] Status bar updates correctly
  - [ ] Preview window shows correct video

---

## Debug Console Commands

### Check Video Dimensions
```bash
# Get video info
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 ~/Movies/MyRecord-*.mp4

# Example output: 800,600
```

### Check Video Duration
```bash
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ~/Movies/MyRecord-*.mp4
```

---

## Known Issues / Expected Behaviors

1. **Coordinate System:** NSWindow uses bottom-left origin, ScreenCaptureKit uses top-left
   - Should be transparent to user
   - Console logs show conversion happening

2. **Minimum Size:** Regions smaller than 100×100 are expanded
   - Warning logged to console
   - Recording still works

3. **Screen Bounds:** Regions extending beyond screen are clamped
   - Warning logged to console
   - Recording still works

---

## Success Criteria

Day 23 is successful if:

✅ All 7 test scenarios pass
✅ Console shows correct region coordinates
✅ Video output dimensions match selected regions
✅ No crashes or errors
✅ Coordinate conversion works correctly
✅ Edge cases handled gracefully

---

## Troubleshooting

### Problem: Region not captured, full screen recorded instead
**Solution:** Check if `captureRegion` is `.zero` - should see "📐 Using full screen..." in console

### Problem: Wrong screen area captured
**Solution:** Coordinate conversion issue - check console for "📐 SCK coordinates"

### Problem: Video dimensions don't match region
**Solution:** Check validation logs for "⚠️ Region adjusted from..."

### Problem: App crashes on record
**Solution:** Check screen recording permission: System Settings > Privacy & Security > Screen Recording

---

**Last Updated:** November 19, 2025
