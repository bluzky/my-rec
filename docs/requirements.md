# Screen Recording App - Requirements Document

## 1. Overview
A simple, lightweight screen recording application with essential recording features, minimal UI, and basic settings. The app focuses on core functionality: recording screen/window/region, with pause capability, and post-recording preview.

---

## 2. User Flow

### 2.1 Initiate Recording
- User accesses the app via:
  - System tray icon context menu â†’ "Record Screen"
  - Keyboard shortcut (default: âŒ˜ + âŒ¥ + 1 on macOS)

### 2.2 Select Recording Area
- Display selection interface allowing user to choose:
  - Full screen
  - Specific window
  - Custom region
- For custom region selection:
  - User can drag to define region boundaries
  - Display resize handles on region corners and edges
  - Show real-time dimension feedback (width Ã— height in pixels)
  - Allow user to adjust region with mouse dragging

### 2.3 Configure Recording Settings
- Display settings bar with options:
  - **Resolution**: Preset options (4K, 2K, 1080P, 720P) or custom dimensions
  - **Frame Rate (FPS)**: 15FPS, 24FPS, 30FPS, 60FPS
  - **Audio Recording**: Option to include/exclude system audio
  - **Output Format**: MP4 (default)
  - **Aspect Ratio**: Preset options (3:4, 4:3, 9:16, 16:9, "Customize", Full Screen)
  - Save location: Configurable via settings

### 2.4 Start Recording
- User clicks "Record" button on settings bar
- Hide the settings bar
- Display countdown timer (3 â†’ 2 â†’ 1)
- After countdown completes, begin recording

### 2.5 Recording in Progress
- Replace system tray icon with:
  - **Elapsed Time Display**: Shows recording duration (HH:MM:SS)
  - **Pause Button**: Click to pause recording
  - **Stop Button**: Click to stop and save recording
- Audio indicator: Visual cue if audio is being recorded
- Maintain minimal UI footprint

### 2.5.1 Camera Preview (if enabled)
- If camera toggle is ON in settings bar:
  - Show live camera feed preview in corner of recording area
  - Position: Bottom-right corner (default, user can drag)
  - Size: Typically 15-25% of recording area
  - Display frame/border around camera preview
  - Camera feed is included in the final recording

### 2.6 Pause Recording
- User clicks pause button â†’ recording pauses
- Pause button changes state (visual indicator)
- Timer stops updating
- User can:
  - Resume recording (click pause button again)
  - Stop recording

### 2.7 Stop Recording & Save
- User clicks stop button
- Recording ends and saves to configured location
- Default save location: `/Users/{username}/Movies/`
- Auto-generate filename: `REC-{timestamp}` (e.g., `REC-20251113143457.mp4`)
- Show save progress/confirmation

### 2.8 Preview Window
- After save completes, display preview window showing:
  - Video thumbnail/preview
  - File metadata:
    - File size
    - Duration
    - Resolution/Dimensions
    - Frame rate (FPS)
    - Format (mp4)
    - Creation timestamp
  - Action buttons:
    - Play/Preview
    - Trim Video
    - Open in finder/file manager
    - Delete
    - Copy/Share

### 2.9 Trim Video Dialog
- User clicks "Trim Video" button in preview window
- Display trim dialog with:
  - **Video Preview**: Shows video frame at current playhead position
  - **Timeline Scrubber**: Interactive timeline showing full video duration
    - Display frame-by-frame or thumbnail strip of video
    - Current playhead position indicator
  - **Trim Handles**: Draggable markers at start and end of trim range
    - Left handle: Trim start point
    - Right handle: Trim end point
    - Display current trim points as timestamps
  - **Playback Controls**: Play/pause to preview trim range
  - **Time Indicators**: Display start time, end time, and trimmed duration
  - **Action Buttons**:
    - Save: Export trimmed video (saves as new file)
    - Cancel: Close without trimming
    - Reset: Return to original full video
  - Allow precise trim by:
    - Dragging handles on timeline
    - Clicking on timeline to set playhead
    - Using keyboard arrows for frame-by-frame adjustment (optional)

---

## 3. System Tray Integration

### 3.1 Default State
- Display app icon in system tray
- Single click: Toggle app window
- Right-click context menu options:
  - Record Screen
  - Record Audio
  - Record Webcam
  - Open Home Page
  - Settings
  - Quit TapRecord

### 3.2 Recording State
- Replace icon with minimal recording indicator
- Display elapsed time
- Show pause and stop controls
- Clicking anywhere on tray icon shows recording controls overlay (if not already visible)

---

## 4. Settings

### 4.1 Settings Dialog/Window
Accessible from:
- System tray menu â†’ Settings
- Keyboard shortcut: (configurable, default: âŒ˜ + âŒ¥ + ,)

Settings options:
- **Save Location**: File path selector (default: `/Users/{username}/Movies/`)
- **Startup**: Checkbox - "Start at login"
- **Start/Pause Recording Shortcut**: Keyboard input (default: âŒ˜ + âŒ¥ + 1)
- **Stop Recording Shortcut**: Keyboard input (default: âŒ˜ + âŒ¥ + 2)
- **Version**: Display current app version
- **Share with Friends**: Button to share app

### 4.2 Default Settings
```
Save Location: /Users/{username}/Movies/
Startup: Disabled
Start/Pause: âŒ˜ + âŒ¥ + 1
Stop: âŒ˜ + âŒ¥ + 2
Output Format: MP4
Default Resolution: 1080P
Default FPS: 30FPS

Recording Defaults:
  Camera: Disabled
  System Audio: Enabled
  Microphone: Disabled
  Pointer: Enabled (Show mouse cursor)
```

---

## 5. Recording Settings Bar

### 5.1 Display
- Appears when user initiates recording selection
- Positioned near the selected recording area
- Contains minimal controls

### 5.2 Controls

#### Dimension & Resolution Settings
- **Size/Dimensions**: 
  - Shows current region width Ã— height
  - Allow manual input or drag-to-resize
  - Format: `{width} Ã— {height}` pixels
  
- **Resolution Preset**: Dropdown
  - 4K, 2K, 1080P, 720P
  - Selected resolution affects dimensions
  
- **FPS Selector**: Dropdown
  - 15FPS, 24FPS, 30FPS, 60FPS

#### Recording Options - Toggle Buttons (4 Buttons)
Four independent toggle buttons for recording options:

1. **Camera Toggle** (Webcam/Camera Icon)
   - ON: Enable webcam/camera capture
     - Display camera feed in corner of recording area
     - Camera window size: Configurable (typically 15-25% of recording area)
     - Camera position: Bottom-right corner by default (user can drag to reposition)
     - Show camera frame indicator/border
   - OFF: Disable camera capture
     - Hide camera feed preview

2. **System Audio Toggle** (Speaker/Sound Icon)
   - ON: Record system audio (speakers/application audio)
     - Visual indicator showing audio is being captured
   - OFF: Disable system audio capture

3. **Microphone Toggle** (Microphone Icon)
   - ON: Record microphone input
     - Visual indicator showing audio is being captured
   - OFF: Disable microphone capture

4. **Pointer/Cursor Toggle** (Cursor/Arrow Icon)
   - ON: Show mouse pointer in recording
     - Cursor remains visible and tracked
   - OFF: Hide mouse pointer from recording
     - Cursor hidden from final video output

#### Primary Action
- **Record Button**: Primary action button (red circle or obvious CTA)

### 5.3 Behavior
- All settings remain visible and adjustable until "Record" is clicked
- After "Record" clicked:
  - Settings bar hides
  - Countdown displays
  - Recording begins after countdown

---

## 6. File Management

### 6.1 Naming Convention
- Format: `REC-{YYYYMMDDHHMMSS}.mp4`
- Example: `REC-20251113143457.mp4`

### 6.2 Save Location
- Default: `~/Movies/`
- User configurable via Settings
- Create directory if it doesn't exist

### 6.3 File Metadata
- Capture and display:
  - File size (MB)
  - Duration (HH:MM:SS)
  - Resolution (width Ã— height)
  - Frame rate (FPS)
  - Creation timestamp

---

## 7. UI/UX Requirements

### 7.1 Minimalist Design
- Clean, dark-themed interface
- Minimal text labels
- Use icons where possible
- Avoid clutter and unnecessary elements

### 7.2 Responsive Controls
- Settings bar: Compact and moveable
- System tray controls: Always accessible
- Recording controls: Visible but unobtrusive

### 7.3 Visual Feedback
- Clear countdown display (3 â†’ 2 â†’ 1 â†’ Start)
- Elapsed time updates in real-time
- Button state changes (pause/resume visual difference)
- Recording area selection highlight

---

## 8. Technical Specifications

### 8.1 Video Output
- Format: MP4
- Codecs: H.264 (video), AAC (audio)
- Supported resolutions: 720P, 1080P, 2K, 4K, Custom
- Supported frame rates: 15, 24, 30, 60 FPS

### 8.2 Audio Options
- System audio capture
- Microphone input (optional)
- Audio bitrate: Configurable or auto

### 8.3 Platform Support
- Primary: macOS (as evidenced by screenshots)
- Keyboard shortcuts follow macOS conventions

---

## 9. Trim Video Feature

### 9.1 Trim Dialog Interface
- **Timeline Display**:
  - Full duration of video shown horizontally
  - Thumbnail frames or waveform preview (optional)
  - Current playhead position indicator
  - Playhead can be dragged or clicked to navigate

- **Trim Range Handles**:
  - Left handle: Set trim start point (in/trim-in)
  - Right handle: Set trim end point (out/trim-out)
  - Handles can be dragged along timeline
  - Snaps to frames for precision

- **Time Indicators**:
  - Show start time of trim range (HH:MM:SS)
  - Show end time of trim range (HH:MM:SS)
  - Show duration of trimmed segment
  - Show total original duration

- **Playback Controls**:
  - Play button: Preview the selected trim range
  - Pause button: Stop playback
  - Display current playback position during preview

- **Action Buttons**:
  - **Save**: Export trimmed video
    - Saves as new file: `REC-{timestamp}-trimmed.mp4`
    - Shows progress indicator
    - Closes dialog after save completes
  - **Cancel**: Close dialog without saving
  - **Reset**: Restore full video duration (reset handles to start/end)

### 9.2 Trim Workflow
1. User views preview window of recorded video
2. User clicks "Trim Video" button
3. Trim dialog opens with full video timeline
4. User drags trim handles to select desired range
5. User can preview trimmed range with Play button
6. User clicks Save to export trimmed video as new file
7. Original video remains unchanged
8. New trimmed video appears in home page/library

### 9.3 Trim Technical Details
- Re-encode only the trimmed portion (fast trimming if available)
- Preserve video quality and codec
- Support precise frame-level trimming
- Maintain audio synchronization during trim
- Output format: Same as original (MP4)

---

## 10. Error Handling

### 10.1 Recording Errors
- Display error message if recording fails
- Allow user to retry or cancel
- Log errors for debugging

### 10.2 File Save Errors
- Handle insufficient disk space
- Handle permission issues
- Display clear error message with resolution steps

### 10.3 Invalid Selection
- Prevent recording with invalid/zero-size regions
- Display validation message

---

## 11. Performance Considerations

- Minimal CPU/GPU usage during idle
- Efficient encoding during recording
- Responsive UI even during high-load recording
- Smooth countdown animation
- Real-time elapsed time display without lag

---

## 12. Additional Features (Optional/Future)

- Recording history/library view
- Quick access to recent recordings
- Keyboard shortcut customization UI
- Video editing/trimming integration
- Screenshot capability
- Webcam recording
- Audio-only recording mode
- Custom watermark
- Recording presets (Gaming, Presentation, Tutorial, etc.)

---

## 13. Accessibility

- Keyboard navigation support
- Clear visual indicators for button states
- High contrast mode support
- Screen reader compatibility for critical UI elements

---

## Appendix: Summary of Key Interactions

| Action | Trigger | Result |
|--------|---------|--------|
| Open Recording | System tray menu OR âŒ˜âŒ¥1 | Display region selection + settings bar |
| Select Region | Drag mouse | Update region with resize handles |
| Adjust Settings | Dropdowns/Inputs | Update resolution, FPS, audio settings |
| Start Recording | Click Record button | Hide settings, show 3-2-1 countdown, begin recording |
| Pause Recording | Click Pause in tray | Pause recording, update pause button state |
| Resume Recording | Click Pause again | Resume recording, update timer |
| Stop Recording | Click Stop in tray OR âŒ˜âŒ¥2 | End recording, save file, show preview |
| Open Trim Dialog | Click "Trim Video" in preview | Display trim dialog with timeline |
| Adjust Trim Range | Drag trim handles OR click timeline | Update trim start/end points |
| Preview Trim Range | Click Play in trim dialog | Play selected trim range |
| Save Trimmed Video | Click Save in trim dialog | Export trimmed video as new file, close dialog |
| Cancel Trim | Click Cancel in trim dialog | Close trim dialog without saving |
| Preview Complete | User interaction | Save recording to file system |
