# Day 22: File Management + Final File Location (Save Phase)

**Status:** 📋 Planned
**Focus:** Move files from temp to ~/Movies/ + Add metadata + Log file operations
**Goal:** See "File saved to ~/Movies/REC-20251118143022.mp4" in console
**Time Estimate:** 4-6 hours

---

## Implementation Strategy

**Build on Day 21 → Add File Management → Verify**

1. Build FileManagerService
2. Move temp files to ~/Movies/ with proper naming
3. Extract and log video metadata (duration, size, resolution)
4. Update AppDelegate to use final file location
5. **Still using mock preview** - just verify files saved correctly

---

## Tasks

### 1. FileManagerService Implementation ✅ Target

**Create:** `MyRec/Services/FileManagement/FileManagerService.swift`

```swift
import Foundation
import AVFoundation

/// Handles file system operations for recordings
class FileManagerService {
    // MARK: - Properties
    private let settingsManager: SettingsManager
    private let fileManager = FileManager.default

    // MARK: - Initialization
    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    // MARK: - Public Interface
    func moveToFinalLocation(from tempURL: URL) throws -> URL {
        let finalURL = generateRecordingURL()
        try ensureRecordingDirectoryExists()

        // Move file from temp to final location
        try fileManager.moveItem(at: tempURL, to: finalURL)

        print("📁 Moved: \(tempURL.lastPathComponent) → \(finalURL.path)")
        return finalURL
    }

    func generateRecordingURL() -> URL {
        let timestamp = formatTimestamp(Date())
        let filename = "REC-\(timestamp).mp4"
        return settingsManager.saveLocationURL.appendingPathComponent(filename)
    }

    func getVideoMetadata(for url: URL) async throws -> VideoMetadata {
        let asset = AVURLAsset(url: url)

        // Load duration
        let duration = try await asset.load(.duration)

        // Load video track
        let tracks = try await asset.load(.tracks)
        let videoTrack = tracks.first(where: { $0.mediaType == .video })

        // Load video properties
        let naturalSize = try await videoTrack?.load(.naturalSize) ?? .zero
        let frameRate = try await videoTrack?.load(.nominalFrameRate) ?? 0

        // Get file size
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Log metadata
        print("📊 Metadata:")
        print("  Duration: \(duration.seconds)s")
        print("  Size: \(naturalSize)")
        print("  FPS: \(frameRate)")
        print("  File size: \(formatFileSize(fileSize))")

        return VideoMetadata(
            fileURL: url,
            duration: duration.seconds,
            resolution: Resolution.from(size: naturalSize),
            frameRate: FrameRate.from(fps: Int(frameRate)),
            fileSize: fileSize,
            createdAt: Date()
        )
    }

    func ensureRecordingDirectoryExists() throws {
        let url = settingsManager.saveLocationURL

        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("📂 Created directory: \(url.path)")
        }
    }

    // MARK: - Private Helpers
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: date)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.2f MB", mb)
    }
}
```

**Files to Create:**
- `MyRec/Services/FileManagement/FileManagerService.swift` (~150 lines)

---

### 2. Add VideoMetadata Model ✅ Target

**Create:** `MyRec/Models/VideoMetadata.swift`

```swift
import Foundation

struct VideoMetadata {
    let fileURL: URL
    let duration: TimeInterval
    let resolution: Resolution
    let frameRate: FrameRate
    let fileSize: Int64
    let createdAt: Date

    var filename: String {
        fileURL.lastPathComponent
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        let mb = Double(fileSize) / 1_048_576.0
        return String(format: "%.2f MB", mb)
    }
}

// MARK: - Resolution Extension
extension Resolution {
    static func from(size: CGSize) -> Resolution {
        let width = Int(size.width)
        let height = Int(size.height)

        switch (width, height) {
        case (1280, 720): return .hd720p
        case (1920, 1080): return .fullHD
        case (2560, 1440): return .twoK
        case (3840, 2160): return .fourK
        default: return .custom(size)
        }
    }
}

// MARK: - FrameRate Extension
extension FrameRate {
    static func from(fps: Int) -> FrameRate {
        switch fps {
        case 15: return .fps15
        case 24: return .fps24
        case 30: return .fps30
        case 60: return .fps60
        default: return .fps30
        }
    }
}
```

**Files to Create:**
- `MyRec/Models/VideoMetadata.swift` (~50 lines)

---

### 3. Update AppDelegate with File Management ✅ Target

**Modify:** `MyRec/AppDelegate.swift`

Add file management to the recording flow:

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    // ADD: File manager service
    private lazy var fileManagerService = FileManagerService(
        settingsManager: SettingsManager.shared
    )

    @objc private func handleStopRecording() {
        Task { @MainActor in
            do {
                // 1. Stop capture + get temp file
                guard let tempURL = try await captureEngine?.stopCapture() else {
                    throw NSError(domain: "Recording", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to get recording file"
                    ])
                }

                print("✅ Recording stopped - Processing file...")
                print("📊 Total frames captured: \(frameCount)")

                // 2. Move to final location
                let finalURL = try fileManagerService.moveToFinalLocation(from: tempURL)
                print("✅ File saved: \(finalURL.path)")

                // 3. Extract metadata
                let metadata = try await fileManagerService.getVideoMetadata(for: finalURL)
                print("✅ Metadata extracted")

                // 4. Open in Finder (for verification)
                NSWorkspace.shared.activateFileViewerSelecting([finalURL])
                print("✅ Opened Finder to file location")

                // 5. Show mock preview for now (real preview in Day 23)
                showMockPreview()

                // Reset
                frameCount = 0
                captureEngine = nil

            } catch {
                print("❌ Error: \(error.localizedDescription)")
                showError("Failed to save recording: \(error.localizedDescription)")
            }
        }
    }
}
```

---

### 4. Manual Testing Checklist ✅ Target

**Test in this order:**

```
File Operations:
☐ 1. Start + stop recording → Temp file created in /tmp/
☐ 2. File moved to ~/Movies/ → Check Finder
☐ 3. Filename format correct → REC-{timestamp}.mp4
☐ 4. Original temp file deleted → Check /tmp/
☐ 5. ~/Movies/ created if missing → Test with new directory

Metadata Extraction:
☐ 6. Console shows duration → Matches recording time
☐ 7. Console shows resolution → Matches settings
☐ 8. Console shows FPS → Matches settings
☐ 9. Console shows file size → Reasonable (~1-2 MB/min)
☐ 10. Metadata logged correctly → All fields present

Multiple Recordings:
☐ 11. Record twice → Two files with different timestamps
☐ 12. Files don't overwrite → Each has unique name
☐ 13. All files playable → Open each in QuickTime
☐ 14. Finder opens to file location → Correct file selected

Error Handling:
☐ 15. No write permission → Graceful error shown
☐ 16. Disk full → Graceful error shown (hard to test)
☐ 17. Invalid path → Fallback to ~/Movies/
☐ 18. Metadata extraction fails → Handles gracefully

Settings Integration:
☐ 19. Change save location → Files saved to new location
☐ 20. Create new folder → Directory created automatically
☐ 21. Different resolutions → Metadata shows correct values
☐ 22. Different FPS → Metadata shows correct values
```

---

## Success Criteria

**By end of Day 22, verify:**

- ✅ Files saved to ~/Movies/ (or configured location)
- ✅ Filename format: REC-{YYYYMMDDHHMMSS}.mp4
- ✅ Temp files cleaned up after move
- ✅ Directory created if missing
- ✅ Metadata extracted correctly (duration, resolution, FPS, size)
- ✅ Console shows full file operation flow
- ✅ Finder opens to show saved file
- ✅ Multiple recordings work without conflicts
- ✅ Files playable in QuickTime

**Console Output Example:**
```
📹 Starting capture...
✅ ScreenCaptureEngine: Capture started
✅ VideoEncoder: Started encoding to recording-ABC123.mp4
✅ Encoder started - Output: recording-ABC123.mp4
✅ Recording started - Region: (0.0, 0.0, 1920.0, 1080.0)
...
✅ Recording stopped - Processing file...
📊 Total frames captured: 1800
✅ ScreenCaptureEngine: Capture stopped - 1800 frames
✅ VideoEncoder: Finished encoding - 1800 frames written
✅ Encoding finished - Temp file: recording-ABC123.mp4
📁 Moved: recording-ABC123.mp4 → /Users/flex/Movies/REC-20251118143022.mp4
✅ File saved: /Users/flex/Movies/REC-20251118143022.mp4
📊 Metadata:
  Duration: 60.0s
  Size: (1920.0, 1080.0)
  FPS: 30.0
  File size: 2.34 MB
✅ Metadata extracted
✅ Opened Finder to file location
```

---

## Common Issues & Troubleshooting

### Issue: File move fails with "File exists"
**Solution:** Check timestamp generation - ensure milliseconds are included or use UUID for uniqueness

### Issue: Metadata extraction fails
**Solution:** Verify file is fully written before calling `getVideoMetadata()` - ensure `finishWriting()` completed

### Issue: Directory not created
**Solution:** Check `withIntermediateDirectories: true` is set in `createDirectory()` call

### Issue: Wrong save location
**Solution:** Verify `SettingsManager.shared.saveLocationURL` returns correct path

---

## Next Steps

After Day 22 is complete, proceed to **[Day 23: Preview Integration](day23-preview-integration.md)**

---

**Time Estimate:** 4-6 hours
**Status:** 📋 Planned
