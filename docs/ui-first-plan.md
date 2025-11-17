# MyRec - UI-First Implementation Plan

**Strategy:** Build all UI components with mock/placeholder data first, then hook up actual recording implementation later.

**Last Updated:** November 17, 2025 (Day 15-16 completed)

---

## Overview

This approach allows us to:
- Validate user experience and UI/UX design early
- Iterate quickly on design without backend complexity
- Get feedback on the complete user journey
- Build a solid UI foundation before adding complex recording logic

---

## UI Components to Implement

### 1. Settings Bar (Polish Existing) 🔨

**Current State:** Basic implementation exists
**Goal:** Production-ready, polished UI with all states

**Features to Add:**
- [ ] Hover effects on all buttons
- [ ] Active/inactive states for toggles
- [ ] Smooth transitions between states
- [ ] Tooltips for all controls
- [ ] Disabled states (e.g., can't change settings while recording)
- [ ] Visual feedback for button clicks
- [ ] Keyboard navigation support
- [ ] Accessibility labels

**Mock Behavior:**
- Settings changes update SettingsManager
- Record button triggers countdown animation
- All toggles can be clicked and show state changes

---

### 2. Status Bar Menu (Enhance Existing) 🔨

**Current State:** Basic menu exists
**Goal:** Complete menu with all states and actions

**Menu States:**

**Idle State:**
```
┌─────────────────────────┐
│ ● MyRec                 │
├─────────────────────────┤
│ ▶ Start Recording       │
│ ⚙ Settings...       ⌘⌥, │
│ 📂 Recording History... │
├─────────────────────────┤
│ About MyRec             │
│ Quit MyRec          ⌘Q  │
└─────────────────────────┘
```

**Recording State:**
```
┌─────────────────────────┐
│ ⏺ Recording - 00:03:24  │
├─────────────────────────┤
│ ⏸ Pause             ⌘⌥1 │
│ ⏹ Stop              ⌘⌥2 │
├─────────────────────────┤
│ 1920×1080 @ 30 FPS      │
│ 127.5 MB                │
└─────────────────────────┘
```

**Paused State:**
```
┌─────────────────────────┐
│ ⏸ Paused - 00:03:24     │
├─────────────────────────┤
│ ▶ Resume            ⌘⌥1 │
│ ⏹ Stop              ⌘⌥2 │
├─────────────────────────┤
│ 1920×1080 @ 30 FPS      │
│ 127.5 MB                │
└─────────────────────────┘
```

**Mock Behavior:**
- Timer counts up (using Timer)
- File size increases gradually
- Can toggle between states
- Clicking "Recording History" opens history window

---

### 3. Settings Dialog (New) ⭐

**Window Type:** Modal dialog (NSPanel)
**Size:** 600×500 fixed

**Layout:**
```
┌────────────────────────────────────────────────┐
│ Settings                                    ⊗  │
├────────────────────────────────────────────────┤
│                                                │
│  General                                       │
│  ┌────────────────────────────────────────┐   │
│  │ Save Location:                         │   │
│  │ [~/Movies/MyRec/           ] [Choose…] │   │
│  │                                        │   │
│  │ File Naming:                           │   │
│  │ ○ REC-YYYYMMDDHHMMSS.mp4              │   │
│  │ ○ Custom prefix: [MyRec_____]         │   │
│  │                                        │   │
│  │ ☑ Launch at login                     │   │
│  │ ☑ Show icon in Dock                   │   │
│  └────────────────────────────────────────┘   │
│                                                │
│  Recording                                     │
│  ┌────────────────────────────────────────┐   │
│  │ Default Resolution: [1080P        ▾]  │   │
│  │ Default FPS:        [30 FPS       ▾]  │   │
│  │ Default Format:     [MP4          ▾]  │   │
│  │                                        │   │
│  │ Countdown Duration: [3 seconds    ▾]  │   │
│  │ ☑ Show countdown before recording     │   │
│  │ ☑ Play sound when recording starts    │   │
│  │ ☑ Highlight cursor during recording   │   │
│  └────────────────────────────────────────┘   │
│                                                │
│  Keyboard Shortcuts                            │
│  ┌────────────────────────────────────────┐   │
│  │ Start/Pause:  [⌘⌥1            ] [Set] │   │
│  │ Stop:         [⌘⌥2            ] [Set] │   │
│  │ Settings:     [⌘⌥,            ] [Set] │   │
│  └────────────────────────────────────────┘   │
│                                                │
│                          [Cancel] [Save]       │
└────────────────────────────────────────────────┘
```

**Features:**
- Tab or section-based navigation (General, Recording, Keyboard, Advanced)
- File path picker integration
- All settings persist to UserDefaults
- Validation for file paths
- Keyboard shortcut recorder

**Mock Behavior:**
- All settings save/load from SettingsManager
- File picker opens native dialog
- Changes apply immediately or on "Save"

---

### 4. Recording History (New) ⭐

**Window Type:** Standalone window
**Size:** 800×600 resizable

**Layout:**
```
┌────────────────────────────────────────────────────────────────┐
│ Recording History                                  🔍 [Search] │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Recent Recordings                                             │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                                                          │ │
│  │  📹 REC-20251116103045.mp4                    Today      │ │
│  │      1920×1080 @ 30 FPS · 00:05:32 · 142.3 MB          │ │
│  │      [▶ Play] [✂ Trim] [📤 Share] [🗑 Delete]           │ │
│  │                                                          │ │
│  │  📹 REC-20251116095522.mp4                    Today      │ │
│  │      2560×1440 @ 60 FPS · 00:12:15 · 487.6 MB          │ │
│  │      [▶ Play] [✂ Trim] [📤 Share] [🗑 Delete]           │ │
│  │                                                          │ │
│  │  📹 REC-20251115184312.mp4                    Yesterday  │ │
│  │      1920×1080 @ 30 FPS · 00:03:45 · 95.2 MB           │ │
│  │      [▶ Play] [✂ Trim] [📤 Share] [🗑 Delete]           │ │
│  │                                                          │ │
│  │  📹 REC-20251115172048.mp4                    Yesterday  │ │
│  │      3840×2160 @ 30 FPS · 00:08:22 · 521.7 MB          │ │
│  │      [▶ Play] [✂ Trim] [📤 Share] [🗑 Delete]           │ │
│  │                                                          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  47 recordings · 12.4 GB total                                 │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

**Features:**
- List view with thumbnail previews
- Metadata display (resolution, FPS, duration, file size)
- Group by date (Today, Yesterday, This Week, etc.)
- Search functionality
- Sorting options (date, duration, size, name)
- Batch actions (delete multiple)
- Right-click context menu

**Mock Data:**
- Generate 10-15 fake recordings
- Randomized metadata (various resolutions, durations, dates)
- Click Play → opens Preview Dialog
- Click Trim → opens Trim Dialog (with mock video)

---

### 5. Preview Dialog (New) ⭐

**Window Type:** Standalone window
**Size:** 900×600 resizable

**Layout:**
```
┌────────────────────────────────────────────────────────────────┐
│ REC-20251116103045.mp4                                      ⊗  │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌─────────────────────────────┐  ┌──────────────────────┐   │
│  │                             │  │ Details              │   │
│  │                             │  │                      │   │
│  │                             │  │ Duration:            │   │
│  │      [VIDEO PREVIEW]        │  │ 00:05:32             │   │
│  │      [PLACEHOLDER]          │  │                      │   │
│  │                             │  │ Resolution:          │   │
│  │                             │  │ 1920 × 1080          │   │
│  │                             │  │                      │   │
│  │                             │  │ Frame Rate:          │   │
│  │                             │  │ 30 FPS               │   │
│  ├─────────────────────────────┤  │                      │   │
│  │ ▶ ━━━━━●━━━━━━━━━ 00:02:45 │  │ File Size:           │   │
│  │ 🔊 ━━━━●━━━━━━             │  │ 142.3 MB             │   │
│  └─────────────────────────────┘  │                      │   │
│                                    │ Created:             │   │
│                                    │ Nov 16, 2025         │   │
│                                    │ 10:30 AM             │   │
│                                    │                      │   │
│                                    │ Location:            │   │
│                                    │ ~/Movies/MyRec/      │   │
│                                    │                      │   │
│                                    ├──────────────────────┤   │
│                                    │ [✂ Trim Video]       │   │
│                                    │ [📤 Share]           │   │
│                                    │ [📂 Show in Finder]  │   │
│                                    │ [🗑 Delete]          │   │
│                                    └──────────────────────┘   │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

**Features:**
- Video player area (placeholder with play icon)
- Playback controls (play/pause, seek, volume)
- Metadata panel on the right
- Action buttons (Trim, Share, Show in Finder, Delete)
- Keyboard shortcuts (Space = play/pause, ←/→ = seek)

**Mock Behavior:**
- Show colored placeholder instead of actual video
- Seek bar updates position when dragged
- Play button toggles to pause icon
- Volume slider adjusts (no actual audio)
- "Trim Video" button opens Trim Dialog

---

### 6. Trim Dialog (New) ⭐

**Window Type:** Modal sheet
**Size:** 700×500 fixed

**Layout:**
```
┌────────────────────────────────────────────────────────────────┐
│ Trim Video                                                  ⊗  │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Preview                                                       │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                                                          │ │
│  │            [FRAME PREVIEW PLACEHOLDER]                   │ │
│  │                                                          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  Timeline                                                      │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ 0s      1s      2s      3s      4s      5s      6s       │ │
│  │ ├───────┼───────┼───────┼───────┼───────┼───────┼────    │ │
│  │ ┃▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░│    │ │
│  │ ┃◄─────── Selected Range ────────►│                │    │ │
│  │ │                                 ●                      │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  Start: 00:00:00  End: 00:04:32  Duration: 00:04:32           │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ ☑ Save as new file (keep original)                      │ │
│  │ Output: REC-20251116103045-trimmed.mp4                   │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│                                     [Cancel] [Save Trimmed]    │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

**Features:**
- Frame preview showing current playhead position
- Timeline with draggable start/end handles
- Time markers every second
- Selected range highlighted
- Playhead scrubber
- Duration calculation
- Output filename preview
- Play button to preview selected range

**Mock Behavior:**
- Dragging handles updates start/end times
- Scrubbing updates preview (show different colored frames)
- Play button animates playhead through selected range
- "Save Trimmed" shows progress dialog

---

### 7. Region Selection UX (Polish Existing) 🔨

**Current State:** Basic overlay with resize handles
**Goal:** Production-ready with animations and feedback

**Enhancements to Add:**
- [ ] 3-2-1 countdown overlay when recording starts
- [ ] Smooth fade-in animation when overlay appears
- [ ] Pulse animation on resize handles
- [ ] Better visual contrast (darker overlay, brighter selection)
- [ ] Corner radius on selection box
- [ ] Dimension display (e.g., "1920 × 1080") near cursor
- [ ] Snap to window edges when near (magnetic effect)
- [ ] Window detection highlights (already added)
- [ ] Escape key to cancel
- [ ] Enter key to confirm and start recording

**Countdown Animation:**
```
┌────────────────────────────────────┐
│                                    │
│                                    │
│              ╔═════╗               │
│              ║  3  ║               │
│              ╚═════╝               │
│                                    │
│         Starting recording...      │
│                                    │
└────────────────────────────────────┘
```

Large animated numbers (3 → 2 → 1 → GO) with fade/scale effects.

---

## Mock Data Models

### MockRecording
```swift
struct MockRecording {
    let id: UUID
    let filename: String
    let duration: TimeInterval
    let resolution: Resolution
    let frameRate: FrameRate
    let fileSize: Int64
    let createdDate: Date
    let thumbnailColor: Color // For placeholder
}
```

### MockRecordingGenerator
```swift
class MockRecordingGenerator {
    static func generate(count: Int) -> [MockRecording]
    static func randomRecording() -> MockRecording
}
```

---

## Implementation Order

### Week 3: Core UI Components (Nov 18-24)

**Day 10-11:** Mock Data & Settings Dialog
- [x] Create MockRecording models
- [x] Build Settings Dialog UI
- [x] Wire up settings persistence

**Day 12-13:** Home Page/Dashboard (Revised)
- [x] Build Home Page window with centered Record button
- [x] Generate mock recordings (5 most recent)
- [x] Add recent recordings list with thumbnails
- [x] Add action buttons (folder, trash, share)
- [x] Implement hover feedback (delete icon turns red)
- [x] Auto-close home page when recording starts
- [x] Add "Show Dashboard" to status bar menu
- [x] Remove Recording History feature (simplified approach)

**Day 14:** Preview Dialog
- [x] Build Preview Dialog layout
- [x] Create video placeholder
- [x] Add playback controls (mock)
- [x] Wire up metadata display
- [x] Add toolbar with action buttons (Trim, Open Folder, Delete, Share)
- [x] Implement 2-row control layout (progress + controls)
- [x] Add inline volume control with slider
- [x] Add playback speed dropdown menu (0.5x - 2x)
- [x] Add fullscreen button
- [x] Keyboard shortcuts (Space, ← →)
- [x] Remove sidebar for full-width video player

### Week 4: Trim UI & Polish (Nov 25-Dec 1)

**Day 15-16:** Trim Dialog
- [x] Build Trim Dialog UI
- [x] Create timeline component with time markers
- [x] Implement draggable start/end handles
- [x] Add frame preview placeholder
- [x] Wire up mock behavior (handle dragging, playback)
- [x] Integrate with AppDelegate and Preview Dialog

**Day 17-18:** Polish & Integration
- [ ] Polish Settings Bar
- [ ] Enhance Status Bar menu
- [ ] Polish Region Selection UX
- [ ] Add countdown animation
- [ ] Connect all UI components

**Day 19:** Testing & Refinement
- [ ] Test complete UI flow
- [ ] Fix UI bugs
- [ ] Refine animations
- [ ] Update documentation

---

## UI Testing Workflow

### Complete User Journey (Mock)
1. Launch app → Status bar icon appears
2. Click icon → Menu shows "Start Recording"
3. Click "Start Recording" → Region selection overlay appears
4. Drag to select region → Settings bar shows at bottom
5. Adjust settings (resolution, FPS, toggles)
6. Click Record → 3-2-1 countdown
7. Status bar shows "Recording - 00:00:03" (timer counts up)
8. Click Pause → Status bar shows "Paused"
9. Click Stop → Preview Dialog opens with mock video
10. Click "Trim Video" → Trim Dialog opens
11. Drag handles to select range → Click "Save Trimmed"
12. Close preview → Recording appears in History
13. Open Recording History → See all mock recordings
14. Click Settings → Settings Dialog opens

All of this works with mock data and placeholder visuals!

---

## Benefits of UI-First Approach

1. **Rapid Iteration:** Change UI quickly without backend constraints
2. **Early Feedback:** Validate UX with users/stakeholders
3. **Parallel Development:** Backend can be built independently
4. **Complete Vision:** See the full app experience early
5. **Better Planning:** Understand data requirements from UI needs
6. **Reduced Risk:** Catch UX issues before investing in backend

---

## Next Phase: Hook Up Implementation

**Week 5+:** Connect real recording engine
- Replace mock timer with actual recording time
- Replace placeholder with actual video capture
- Wire AVPlayer to Preview Dialog
- Implement actual trim functionality
- Connect file system for Recording History
- Add actual video encoding

---

## Documentation to Create

- [ ] UI component library documentation
- [ ] Mock data API documentation
- [ ] UI testing guide
- [ ] Screenshot/video demos of UI flow
- [ ] Design system documentation

---

**Status:** Day 15-16 completed - Trim Dialog fully implemented
**Target:** Complete all UI by end of Week 4
**Next Step:** Polish & Integration (Day 17-18)
**Completed:** Day 10-16 (Mock data, Settings Dialog, Home Page, Preview Dialog, Trim Dialog)
