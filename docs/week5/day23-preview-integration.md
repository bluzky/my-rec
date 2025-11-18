# Day 23: Preview Integration + Polish (UI Connection Phase)

**Status:** 📋 Planned
**Focus:** Connect real videos to preview UI + Load recordings list + Polish & test
**Goal:** Click stop → Preview opens with REAL video playing
**Time Estimate:** 6-8 hours

---

## Implementation Strategy

**Build on Day 22 → Connect UI → Complete Flow**

1. Wire PreviewDialogView to play real videos (AVPlayer)
2. Update HomePageView to load real recordings from ~/Movies/
3. Remove all mock data
4. Polish error handling and user feedback
5. **Complete end-to-end testing**

---

## Tasks

### 1. Preview Dialog Integration ✅ Target

**Modify:** `MyRec/Views/PreviewDialogView.swift`

Replace mock video with real AVPlayer:

```swift
import SwiftUI
import AVKit

struct PreviewDialogView: View {
    let videoMetadata: VideoMetadata
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // REPLACE mock thumbnail with real video player
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 400)
                    .cornerRadius(8)
                    .onAppear {
                        print("▶️ Playing video: \(videoMetadata.filename)")
                    }
            } else {
                // Loading state
                ProgressView("Loading video...")
                    .frame(height: 400)
            }

            // Metadata section (now using REAL data)
            VStack(spacing: 8) {
                HStack {
                    Text("Duration:")
                    Spacer()
                    Text(videoMetadata.formattedDuration)
                }
                HStack {
                    Text("File Size:")
                    Spacer()
                    Text(videoMetadata.formattedFileSize)
                }
                HStack {
                    Text("Resolution:")
                    Spacer()
                    Text(videoMetadata.resolution.displayName)
                }
                HStack {
                    Text("Frame Rate:")
                    Spacer()
                    Text(videoMetadata.frameRate.displayName)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Actions
            HStack(spacing: 12) {
                Button("Open Folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([videoMetadata.fileURL])
                    print("📂 Opened Finder to: \(videoMetadata.fileURL.path)")
                }

                Button("Trim Video") {
                    // TODO: Open trim dialog (keep existing mock for now)
                    print("✂️ Trim button clicked")
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 600)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanup()
        }
    }

    private func setupPlayer() {
        print("🎬 Setting up player for: \(videoMetadata.fileURL.lastPathComponent)")
        player = AVPlayer(url: videoMetadata.fileURL)

        // Auto-play
        player?.play()
        isPlaying = true

        // Log playback start
        print("▶️ Started playback")
    }

    private func cleanup() {
        player?.pause()
        player = nil
        print("⏹️ Player cleaned up")
    }
}
```

---

### 2. Update AppDelegate to Show Real Preview ✅ Target

**Modify:** `MyRec/AppDelegate.swift`

Update to show real preview instead of mock:

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    // ADD: Keep reference to preview window
    private var previewWindow: NSWindow?

    @objc private func handleStopRecording() {
        Task { @MainActor in
            do {
                // 1. Stop capture + get temp file
                guard let tempURL = try await captureEngine?.stopCapture() else {
                    throw NSError(domain: "Recording", code: -1)
                }

                print("✅ Recording stopped - Processing file...")
                print("📊 Total frames captured: \(frameCount)")

                // 2. Move to final location
                let finalURL = try fileManagerService.moveToFinalLocation(from: tempURL)
                print("✅ File saved: \(finalURL.path)")

                // 3. Extract metadata
                let metadata = try await fileManagerService.getVideoMetadata(for: finalURL)
                print("✅ Metadata extracted")
                print("✅ Processing complete")

                // 4. REMOVE showMockPreview()
                // ADD: Show REAL preview with video
                openPreviewDialog(with: metadata)

                // Reset
                frameCount = 0
                captureEngine = nil

            } catch {
                print("❌ Error: \(error.localizedDescription)")
                showError("Failed to save recording: \(error.localizedDescription)")
            }
        }
    }

    private func openPreviewDialog(with metadata: VideoMetadata) {
        print("🎬 Opening preview dialog")

        let previewView = PreviewDialogView(videoMetadata: metadata)
        let hostingController = NSHostingController(rootView: previewView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Recording Preview"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Keep reference to prevent deallocation
        previewWindow = window
    }

    // REMOVE showMockPreview() method entirely
}
```

---

### 3. Home Page Recordings List ✅ Target

**Modify:** `MyRec/Views/HomePageView.swift`

Load real recordings from disk:

```swift
import SwiftUI

struct HomePageView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var recordings: [VideoMetadata] = []
    @State private var isLoadingRecordings = false

    var body: some View {
        VStack {
            // Recordings list
            if isLoadingRecordings {
                ProgressView("Loading recordings...")
            } else if recordings.isEmpty {
                Text("No recordings yet")
                    .foregroundColor(.secondary)
            } else {
                List(recordings, id: \.fileURL) { recording in
                    RecordingRow(recording: recording)
                }
            }

            // Record button (existing)
            Button("Record Screen") {
                // ... existing code ...
            }
        }
        .onAppear {
            loadRecordings()
        }
    }

    private func loadRecordings() {
        isLoadingRecordings = true
        print("📂 Loading recordings from: \(settingsManager.saveLocationURL.path)")

        Task {
            do {
                let fileManager = FileManager.default
                let recordingsURL = settingsManager.saveLocationURL

                // Ensure directory exists
                if !fileManager.fileExists(atPath: recordingsURL.path) {
                    print("📂 No recordings directory found")
                    await MainActor.run {
                        recordings = []
                        isLoadingRecordings = false
                    }
                    return
                }

                // Load all REC-*.mp4 files
                let files = try fileManager
                    .contentsOfDirectory(
                        at: recordingsURL,
                        includingPropertiesForKeys: [.creationDateKey],
                        options: [.skipsHiddenFiles]
                    )
                    .filter { $0.pathExtension == "mp4" }
                    .filter { $0.lastPathComponent.hasPrefix("REC-") }
                    .sorted { url1, url2 in
                        // Sort by creation date (newest first)
                        let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate
                        let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate
                        return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                    }

                print("📊 Found \(files.count) recordings")

                // Load metadata for each file
                let fileManagerService = FileManagerService(settingsManager: settingsManager)
                var loadedRecordings: [VideoMetadata] = []

                for fileURL in files {
                    do {
                        let metadata = try await fileManagerService.getVideoMetadata(for: fileURL)
                        loadedRecordings.append(metadata)
                    } catch {
                        print("❌ Failed to load metadata for \(fileURL.lastPathComponent): \(error)")
                    }
                }

                await MainActor.run {
                    recordings = loadedRecordings
                    isLoadingRecordings = false
                    print("✅ Loaded \(recordings.count) recordings")
                }

            } catch {
                print("❌ Failed to load recordings: \(error)")
                await MainActor.run {
                    recordings = []
                    isLoadingRecordings = false
                }
            }
        }
    }
}

struct RecordingRow: View {
    let recording: VideoMetadata

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(recording.filename)
                    .font(.headline)
                Text("\(recording.formattedDuration) • \(recording.formattedFileSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Play") {
                NSWorkspace.shared.open(recording.fileURL)
            }
        }
        .padding(.vertical, 4)
    }
}
```

---

### 4. Remove Mock Data ✅ Target

**Cleanup Checklist:**

```
AppDelegate.swift:
☐ Remove mock timer setup
☐ Remove mock recording generation
☐ Remove showMockPreview() method
☐ Remove demo menu items

HomePageView.swift:
☐ Remove MockRecording references
☐ Remove mock data initialization
☐ Remove static mock recordings array

PreviewDialogView.swift:
☐ Remove mock thumbnail placeholder
☐ Remove mock metadata display
☐ Remove placeholder image assets

Models:
☐ Keep MockRecording model in test files only
☐ Remove any remaining mock data generators
```

---

### 5. End-to-End Integration Testing ✅ Target

**Complete Manual Test Checklist (52 items):**

```
🎬 Complete Recording Flow (Most Important):
☐ 1. Launch app → Home page appears with no recordings
☐ 2. Click "Record Screen" → Region selection appears
☐ 3. Select full-screen → Resize handles appear
☐ 4. Set resolution to 1080p, FPS to 30
☐ 5. Click Record → Countdown plays (3-2-1)
☐ 6. Recording starts → Status bar shows "🔴 00:00 | Frames: 0"
☐ 7. Wait 10 seconds → Timer updates to "🔴 00:10 | Frames: 300"
☐ 8. Status bar shows frame count increasing
☐ 9. Click Stop → Recording stops
☐ 10. Console shows full processing log
☐ 11. Preview dialog opens automatically
☐ 12. Video plays in preview (with sound if available)
☐ 13. Metadata shows correct duration (00:10)
☐ 14. Metadata shows correct file size (~2.5 MB)
☐ 15. Metadata shows 1080p resolution
☐ 16. Metadata shows 30 FPS
☐ 17. Click "Open Folder" → Finder opens to ~/Movies/
☐ 18. File named REC-{timestamp}.mp4 exists
☐ 19. Click Done → Preview closes
☐ 20. Home page now shows 1 recording in list

🏠 Home Page Recordings List:
☐ 21. Recording appears in list with correct filename
☐ 22. Shows duration and file size
☐ 23. Click "Play" → Opens in system player (QuickTime)
☐ 24. Record again → List now shows 2 recordings
☐ 25. Newest recording appears first

⌨️ Keyboard Shortcuts:
☐ 26. Press ⌘⌥1 → Recording starts
☐ 27. Press ⌘⌥2 → Recording stops
☐ 28. Press ⌘⌥, → Settings opens (if implemented)

📐 Different Resolutions:
☐ 29. Record at 720p → Verify output is 1280x720
☐ 30. Record at 1080p → Verify output is 1920x1080
☐ 31. Record at 2K → Verify output is 2560x1440

🎞️ Different Frame Rates:
☐ 32. Record at 30 FPS → Smooth playback
☐ 33. Record at 60 FPS → Smooth playback
☐ 34. Record at 15 FPS → Playback works (slower motion)

❌ Error Scenarios:
☐ 35. First launch → Permission dialog appears
☐ 36. Deny permission → Clear error message shown
☐ 37. Revoke permission → Error on next recording
☐ 38. Invalid save location → Falls back to ~/Movies/

⚡ Performance:
☐ 39. CPU usage < 30% during 1080p @ 30fps
☐ 40. Memory usage < 250 MB during recording
☐ 41. No frame drops in console logs
☐ 42. Record for 1 minute → No lag or stuttering
☐ 43. UI stays responsive during recording

📊 Console Logs Verification:
☐ 44. See "✅ Recording started" message
☐ 45. See "📹 Frame X → Encoder" every second
☐ 46. See "💾 Frame X encoded to MP4" every second
☐ 47. See "✅ Encoding finished" message
☐ 48. See "📁 Moved: ... → .../REC-....mp4" message
☐ 49. See "📊 Metadata: Duration, Size, FPS, File size"
☐ 50. See "✅ Processing complete"
☐ 51. See "🎬 Opening preview dialog"
☐ 52. See "▶️ Started playback"
```

---

## Success Criteria

**By end of Day 23, verify:**

**Core Functionality:**
- ✅ Complete flow: Start → Record → Stop → Preview → Play
- ✅ Real video plays in preview dialog
- ✅ Recordings list shows real files from ~/Movies/
- ✅ All mock data removed from UI
- ✅ Console logs show full pipeline operation

**Video Quality:**
- ✅ Videos playable in QuickTime Player
- ✅ No visual artifacts or corruption
- ✅ Smooth playback at all frame rates
- ✅ Correct resolution output

**UI/UX:**
- ✅ Preview opens automatically after recording
- ✅ Metadata displayed accurately
- ✅ "Open Folder" button works
- ✅ Home page loads recordings correctly
- ✅ Status bar shows real-time frame count

**Performance:**
- ✅ No crashes or errors
- ✅ CPU/memory within acceptable range
- ✅ UI stays responsive during recording
- ✅ Multiple recordings work without issues

**Console Output Example:**
```
🎬 Complete Recording Flow:

📹 Starting capture...
  Region: (0.0, 0.0, 1920.0, 1080.0)
  Resolution: 1080P
  Frame Rate: 30 FPS
✅ ScreenCaptureEngine: Capture started
✅ VideoEncoder: Started encoding to recording-ABC123.mp4
✅ Encoder started - Output: recording-ABC123.mp4
✅ Recording started - Region: (0.0, 0.0, 1920.0, 1080.0)
📹 Frame 30 → Encoder
💾 Frame 30 encoded to MP4
📹 Frame 60 → Encoder
💾 Frame 60 encoded to MP4
...
✅ Recording stopped - Processing file...
📊 Total frames captured: 300
✅ ScreenCaptureEngine: Capture stopped - 300 frames
✅ VideoEncoder: Finished encoding - 300 frames written
✅ Encoding finished - Temp file: recording-ABC123.mp4
📁 Moved: recording-ABC123.mp4 → /Users/flex/Movies/REC-20251118143022.mp4
✅ File saved: /Users/flex/Movies/REC-20251118143022.mp4
📊 Metadata:
  Duration: 10.0s
  Size: (1920.0, 1080.0)
  FPS: 30.0
  File size: 2.34 MB
✅ Metadata extracted
✅ Processing complete
🎬 Opening preview dialog
🎬 Setting up player for: REC-20251118143022.mp4
▶️ Started playback
▶️ Playing video: REC-20251118143022.mp4

🏠 Home Page:
📂 Loading recordings from: /Users/flex/Movies
📊 Found 1 recordings
✅ Loaded 1 recordings
```

---

## Common Issues & Troubleshooting

### Issue: Preview doesn't open
**Solution:** Check `previewWindow` is retained and `NSHostingController` is properly initialized

### Issue: Video doesn't play in preview
**Solution:** Verify file URL is correct and file exists before creating AVPlayer

### Issue: Recordings list is empty
**Solution:** Check file naming (must start with "REC-"), verify save location is correct

### Issue: Metadata shows wrong values
**Solution:** Ensure `Resolution.from()` and `FrameRate.from()` extension methods are implemented

---

## Week 5 Complete!

After completing Day 23, you will have:

1. ✅ Real screen recording working end-to-end
2. ✅ Files saved to ~/Movies/ with correct naming
3. ✅ Preview dialog playing real videos
4. ✅ Home page loading recordings from disk
5. ✅ All mock data removed
6. ✅ Full console logging for debugging
7. ✅ 52-point test checklist complete

**Congratulations! Backend integration is complete. Ready for Week 6: Audio Integration**

---

**Time Estimate:** 6-8 hours
**Status:** 📋 Planned
