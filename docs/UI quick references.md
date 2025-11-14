================================================================================
SCREEN RECORDING APP - QUICK REFERENCE GUIDE
================================================================================

TRIM VIDEO DIALOG - FINAL LAYOUT
────────────────────────────────────────────────────────────────────────────

┌──────────────────────────────────────────────────────────────────────────┐
│  ⊙ ⊙ ⊙    REC-20251113143457.mp4 - Trim                    [✕]        │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │                   ▶  [Video Preview Frame]                       │ │
│  │                                                                    │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ──────────────────────────────────────────────────────────────────────  │
│  Time: 00:00 - 00:26  │  [✂️ Trim]  │  [🗑️ Delete]  │  [🔊 ON]       │
│  ──────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  [◄─────────────●──────────────────────────────────────────────────┤]   │
│   ├──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼     │
│   00  02  04  06  08  10 12 14 16 18 20 22 24 26                        │
│                                                                          │
│  ──────────────────────────────────────────────────────────────────────  │
│  [⏮ PRV]  [⏸ Play]  [⏭ FFW]      [SAVE AS] [SAVE]                 │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

4 Sections:
1. Video Preview (top) - Shows current frame
2. Controls Row - Time display, Trim, Delete, Audio toggle
3. Timeline - Draggable handles for start/end, time labels
4. Playback - Previous, Play/Pause, Forward, Save buttons


SYSTEM TRAY RECORDING CONTROLS
────────────────────────────────────────────────────────────────────────────

┌────────────────────────────────────┐
│  [00:04:27]   [⏸]   [⏹]          │
└────────────────────────────────────┘

3 Controls Only:
  • [00:04:27] - Timer (HH:MM:SS)
  • [⏸] - Pause/Resume
  • [⏹] - Stop Recording


PREVIEW WINDOW LAYOUT
────────────────────────────────────────────────────────────────────────────

┌─────────────────────────────┬────────────────────────┐
│  Preview Area (70%)         │  Metadata (30%)        │
│                             │                        │
│  • Video playback           │  • Filename            │
│                             │  • File Size           │
│  • Timeline scrubber        │  • Duration            │
│                             │  • Created             │
│  Playback Controls:         │  • Dimensions          │
│  [⏮] [⏸] [▶] [⏭]          │  • FPS                 │
│  [════════●════]            │  • Format              │
│  00:06 / 00:26              │                        │
│                             │  ─────────────────────
│                             │  [   ✂️ Trim   ]
│                             │  ─────────────────────
│                             │  [📁] [🗑️] [↑] Share
└─────────────────────────────┴────────────────────────┘


RECORDING SETTINGS BAR
────────────────────────────────────────────────────────────────────────────

[✕] Size ▼│ 1440×875 │ 1080P ▼│ 30FPS ▼│ [🎥] [🔊] [🎤] [➡️] [●]

Left to Right:
  • Close button
  • Size selector
  • Resolution dropdown
  • FPS dropdown
  • 4 Toggle buttons: Camera | Audio | Microphone | Pointer
  • Red Record button


SYSTEM TRAY CONTEXT MENU
────────────────────────────────────────────────────────────────────────────

┌──────────────────────────────────┐
│  🎥  Record Screen     ⌘⌥1      │
│  🎤  Record Audio               │
│  📹  Record Webcam              │
│  ─────────────────────────────   │
│  🏠  Open Home Page             │
│  ⚙️   Settings         ⌘⌥,      │
│  ─────────────────────────────   │
│  ❌  Quit TapRecord             │
└──────────────────────────────────┘


USER WORKFLOW - COMPLETE FLOW
────────────────────────────────────────────────────────────────────────────

1. INITIATE RECORDING
   User clicks system tray icon menu → "Record Screen"
   OR presses keyboard shortcut ⌘⌥1

2. SELECT AREA & CONFIGURE
   • Select Full Screen / Window / Custom Region
   • Adjust region dimensions with resize handles
   • Configure: Resolution, FPS, Camera, Audio, Mic, Pointer
   • Settings bar remains visible until "Record" clicked

3. START RECORDING
   User clicks red Record button
   ↓
   Settings bar hides
   ↓
   Countdown timer shows: 3 → 2 → 1
   ↓
   Recording begins, system tray shows controls

4. RECORDING IN PROGRESS
   System tray shows:
   • Elapsed time (updates every second)
   • Pause button (to pause/resume)
   • Stop button (to end recording)

5. STOP & SAVE
   User clicks stop button (or presses ⌘⌥2)
   ↓
   Recording ends and saves to ~/Movies/
   ↓
   Default filename: REC-{YYYYMMDDHHMMSS}.mp4

6. PREVIEW RECORDING
   Preview window opens with:
   • Left: Video player with controls
   • Right: File metadata
   • Actions: Open in Finder, Delete, Trim, Share

7. OPTIONAL: TRIM VIDEO
   User clicks "Trim" button
   ↓
   Trim dialog opens with 4 sections
   ↓
   Drag handles to select trim range
   ↓
   Click [SAVE] or [SAVE AS]
   ↓
   Trimmed video saved as new file


KEYBOARD SHORTCUTS
────────────────────────────────────────────────────────────────────────────

Recording:
  ⌘⌥1    - Start/Pause recording
  ⌘⌥2    - Stop recording
  ⌘⌥,    - Open settings

Trim Dialog:
  Space  - Play/Pause
  ←      - Previous frame
  →      - Next frame
  ⌘S     - Save
  ⌘⇧S    - Save as


COLOR PALETTE
────────────────────────────────────────────────────────────────────────────

Background:       #1a1a1a (Dark Charcoal)
Text:             #e0e0e0 (Light Gray)
Primary Button:   #e74c3c (Bright Red) - Record
Secondary Button: #007AFF (Blue) - Save
Active Toggle:    #4caf50 (Green) - ON
Disabled:         #666666 (Medium Gray)


FILE SPECIFICATIONS
────────────────────────────────────────────────────────────────────────────

Format:           MP4
Video Codec:      H.264
Audio Codec:      AAC
Resolutions:      720P, 1080P, 2K, 4K, Custom
Frame Rates:      15, 24, 30, 60 FPS
Save Location:    ~/Movies/ (default, configurable)
Filename:         REC-{YYYYMMDDHHMMSS}.mp4


TOGGLE BUTTONS (4 ON SETTINGS BAR)
────────────────────────────────────────────────────────────────────────────

1. 🎥 Camera
   ON  → Webcam feed in corner of recording area (bottom-right)
        Repositionable by user, 15-25% of recording area
   OFF → No camera in recording

2. 🔊 System Audio
   ON  → Records system/app audio (speakers)
   OFF → No system audio

3. 🎤 Microphone
   ON  → Records microphone input
   OFF → No microphone input

4. ➡️ Pointer/Cursor
   ON  → Mouse cursor visible in recording
   OFF → Mouse cursor hidden from recording


DESIGN PHILOSOPHY
────────────────────────────────────────────────────────────────────────────

✓ Minimalist - Only essential controls visible
✓ Clean - Dark theme, light text for contrast
✓ Efficient - Quick access to core functions
✓ Intuitive - Standard macOS conventions
✓ Unobtrusive - Doesn't interfere with recording
✓ Responsive - Updates in real-time


DEVELOPMENT PRIORITY
────────────────────────────────────────────────────────────────────────────

Phase 1 - Core Recording:
  1. System tray integration
  2. Region selection
  3. Basic recording (video only)
  4. Save to file

Phase 2 - Recording Controls:
  1. Pause/resume
  2. Elapsed time display
  3. Countdown timer
  4. Settings bar

Phase 3 - Advanced Features:
  1. Audio options (system, mic)
  2. Camera preview overlay
  3. Cursor visibility toggle
  4. Resolution/FPS selection

Phase 4 - Post-Recording:
  1. Preview window
  2. Metadata display
  3. File management (delete, share)
  4. Settings dialog

Phase 5 - Trim Feature:
  1. Trim dialog UI
  2. Timeline scrubber
  3. Frame-by-frame editing
  4. Export options


TESTING CHECKLIST
────────────────────────────────────────────────────────────────────────────

Recording:
  ☐ Record full screen
  ☐ Record window
  ☐ Record custom region
  ☐ Pause/resume recording
  ☐ Stop recording
  ☐ Countdown timer works
  ☐ Elapsed time updates

Settings:
  ☐ Resolution changes work
  ☐ FPS selection works
  ☐ Camera toggle works
  ☐ Audio toggles work
  ☐ Mic toggle works
  ☐ Pointer toggle works

Preview:
  ☐ Preview window opens
  ☐ Metadata displays correctly
  ☐ Playback controls work
  ☐ Actions buttons work

Trim:
  ☐ Trim dialog opens
  ☐ Timeline scrubber works
  ☐ Handles are draggable
  ☐ Playback controls work
  ☐ Save/Save As works
  ☐ Trimmed file created

System Integration:
  ☐ Keyboard shortcuts work
  ☐ System tray icon visible
  ☐ File saved to correct location
  ☐ Settings persist


================================================================================
Version: 1.0 | Status: Complete | Ready for Development
================================================================================
