# Day 21: Video Encoding + Integration (Encoding Phase)

**Status:** 📋 Planned
**Focus:** Add VideoEncoder + Connect to capture pipeline + Log encoding progress
**Goal:** See "Encoding... Frame 1 written, Frame 2 written..." + Create real MP4 file
**Time Estimate:** 6-8 hours

---

## Implementation Strategy

**Build on Day 20 → Add Encoding → Verify**

1. Build VideoEncoder with AVAssetWriter
2. Wire it to ScreenCaptureEngine (capture → encode flow)
3. Log encoding progress to console
4. Save MP4 file to temp location
5. **NO playback UI yet** - just verify file is created and playable in QuickTime

---

## Tasks

### 1. VideoEncoder Implementation ✅ Target

**Create:** `MyRec/Services/Recording/VideoEncoder.swift`

```swift
import AVFoundation

/// Encodes video frames to H.264/MP4 using AVAssetWriter
class VideoEncoder {
    // MARK: - Properties
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var isEncoding = false
    private var frameCount: Int = 0

    private let outputURL: URL
    private let resolution: Resolution
    private let frameRate: FrameRate

    // MARK: - Callbacks
    var onFrameEncoded: ((Int) -> Void)?
    var onEncodingFinished: ((URL, Int) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Lifecycle
    init(outputURL: URL, resolution: Resolution, frameRate: FrameRate) {
        self.outputURL = outputURL
        self.resolution = resolution
        self.frameRate = frameRate
    }

    // MARK: - Public Interface
    func startEncoding() throws {
        guard !isEncoding else { return }

        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Configure video input
        let videoSettings = createVideoSettings()
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        // Add input to writer
        guard let videoInput = videoInput,
              let assetWriter = assetWriter,
              assetWriter.canAdd(videoInput) else {
            throw EncodingError.configurationFailed
        }

        assetWriter.add(videoInput)

        // Start writing session
        guard assetWriter.startWriting() else {
            throw EncodingError.writerStartFailed
        }

        assetWriter.startSession(atSourceTime: .zero)
        isEncoding = true
        frameCount = 0

        print("✅ VideoEncoder: Started encoding to \(outputURL.lastPathComponent)")
    }

    func appendFrame(_ sampleBuffer: CMSampleBuffer) throws {
        guard isEncoding,
              let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else {
            return
        }

        if videoInput.append(sampleBuffer) {
            frameCount += 1

            // Log progress
            if frameCount % 30 == 0 {
                onFrameEncoded?(frameCount)
            }
        } else {
            throw EncodingError.appendFailed
        }
    }

    func finishEncoding() async throws -> URL {
        guard isEncoding else {
            throw EncodingError.notEncoding
        }

        isEncoding = false

        // Mark input as finished
        videoInput?.markAsFinished()

        // Finish writing
        await assetWriter?.finishWriting()

        if let error = assetWriter?.error {
            throw error
        }

        print("✅ VideoEncoder: Finished encoding - \(frameCount) frames written")
        onEncodingFinished?(outputURL, frameCount)

        return outputURL
    }

    // MARK: - Private Methods
    private func createVideoSettings() -> [String: Any] {
        let bitrate = calculateBitrate()

        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: resolution.width,
            AVVideoHeightKey: resolution.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: frameRate.value * 2, // GOP = 2 seconds
                AVVideoAllowFrameReorderingKey: true,
                AVVideoExpectedSourceFrameRateKey: frameRate.value,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
            ]
        ]
    }

    private func calculateBitrate() -> Int {
        let baseRate: Int
        switch resolution {
        case .hd720p:   baseRate = 2_500_000  // 2.5 Mbps
        case .fullHD:   baseRate = 5_000_000  // 5 Mbps
        case .twoK:     baseRate = 8_000_000  // 8 Mbps
        case .fourK:    baseRate = 15_000_000 // 15 Mbps
        case .custom(let size):
            let pixels = size.width * size.height
            baseRate = Int(pixels * 0.002) // ~0.002 bits per pixel
        }

        // Adjust for frame rate
        let fpsMultiplier = Double(frameRate.value) / 30.0
        return Int(Double(baseRate) * fpsMultiplier)
    }
}

// MARK: - Errors
enum EncodingError: LocalizedError {
    case configurationFailed
    case writerStartFailed
    case appendFailed
    case notEncoding

    var errorDescription: String? {
        switch self {
        case .configurationFailed:
            return "Failed to configure video encoder"
        case .writerStartFailed:
            return "Failed to start AVAssetWriter"
        case .appendFailed:
            return "Failed to append frame to video"
        case .notEncoding:
            return "Encoder is not currently encoding"
        }
    }
}
```

**Key Features:**
- Simple AVAssetWriter setup
- Frame counting during encoding
- Progress callbacks for logging
- Error handling
- Temporary file output

**Files to Create:**
- `MyRec/Services/Recording/VideoEncoder.swift` (~200 lines)

---

### 2. Connect ScreenCaptureEngine to VideoEncoder ✅ Target

**Modify:** `MyRec/Services/Recording/ScreenCaptureEngine.swift`

Add video encoding to the capture engine:

```swift
class ScreenCaptureEngine: NSObject, SCStreamDelegate, SCStreamOutput {
    // ADD: VideoEncoder reference
    private var videoEncoder: VideoEncoder?
    private var tempURL: URL?

    func startCapture(region: CGRect, resolution: Resolution, frameRate: FrameRate) async throws {
        // ... existing stream setup code ...

        // ADD: Create temp file URL
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).mp4")

        // ADD: Create and start encoder
        guard let tempURL = tempURL else {
            throw CaptureError.configurationFailed
        }

        videoEncoder = VideoEncoder(
            outputURL: tempURL,
            resolution: resolution,
            frameRate: frameRate
        )

        videoEncoder?.onFrameEncoded = { frame in
            print("💾 Frame \(frame) encoded to MP4")
        }

        videoEncoder?.onError = { error in
            print("❌ Encoding error: \(error)")
        }

        try videoEncoder?.startEncoding()
        print("✅ Encoder started - Output: \(tempURL.lastPathComponent)")

        // ... continue with stream setup ...
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        frameCount += 1

        // Send frame to encoder
        do {
            try videoEncoder?.appendFrame(sampleBuffer)

            // Log every 30 frames
            if frameCount % 30 == 0 {
                print("📹 Frame \(frameCount) → Encoder")
            }

            // Calculate elapsed time
            let presentationTime = sampleBuffer.presentationTimeStamp
            if startTime == nil {
                startTime = presentationTime
            }
            let elapsed = presentationTime - (startTime ?? .zero)

            // Notify UI
            onFrameCaptured?(frameCount, elapsed)

        } catch {
            print("❌ Failed to encode frame \(frameCount): \(error)")
            onError?(error)
        }
    }

    func stopCapture() async throws -> URL {
        // Stop stream
        try await stream?.stopCapture()
        stream = nil

        // Finish encoding
        guard let encoder = videoEncoder else {
            throw CaptureError.encoderNotInitialized
        }

        let outputURL = try await encoder.finishEncoding()
        print("✅ Encoding finished - File: \(outputURL.path)")

        // Reset
        videoEncoder = nil
        let result = outputURL
        tempURL = nil
        frameCount = 0
        startTime = nil

        return result
    }
}

// Update CaptureError enum
enum CaptureError: LocalizedError {
    case permissionDenied
    case captureUnavailable
    case configurationFailed
    case encoderNotInitialized  // ADD this case

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission denied"
        case .captureUnavailable:
            return "Screen capture is unavailable"
        case .configurationFailed:
            return "Failed to configure screen capture"
        case .encoderNotInitialized:
            return "Video encoder was not initialized"
        }
    }
}
```

---

### 3. Update AppDelegate Integration ✅ Target

**Modify:** `MyRec/AppDelegate.swift`

Update the stop recording handler to handle the video file:

```swift
@objc private func handleStopRecording() {
    Task { @MainActor in
        do {
            // Stop capture + get output file
            guard let videoURL = try await captureEngine?.stopCapture() else {
                throw NSError(domain: "Recording", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to get video file"
                ])
            }

            print("✅ Recording stopped")
            print("📁 File saved: \(videoURL.path)")
            print("📊 Total frames: \(frameCount)")

            // Verify file exists
            if FileManager.default.fileExists(atPath: videoURL.path) {
                let fileSize = try FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int64 ?? 0
                print("📏 File size: \(formatFileSize(fileSize))")

                // Open in QuickTime for manual verification
                NSWorkspace.shared.open(videoURL)

                print("✅ Opened video in QuickTime for verification")
            } else {
                print("❌ Warning: Video file not found at \(videoURL.path)")
            }

            // Show mock preview for now (real preview in Day 23)
            showMockPreview()

            // Reset
            frameCount = 0
            captureEngine = nil

        } catch {
            print("❌ Failed to stop recording: \(error)")
            showError("Failed to stop recording: \(error.localizedDescription)")
        }
    }
}

private func formatFileSize(_ bytes: Int64) -> String {
    let mb = Double(bytes) / 1_048_576.0
    return String(format: "%.2f MB", mb)
}
```

---

### 4. Manual Testing Checklist ✅ Target

**Test in this order:**

```
Encoding Integration:
☐ 1. Start recording → Console shows "✅ Encoder started"
☐ 2. Wait 5 seconds → Console shows both capture + encoding logs
☐ 3. Stop recording → Console shows "✅ Encoding finished"
☐ 4. Verify temp file created → Check /tmp/recording-*.mp4
☐ 5. Verify file size reasonable → ~1-2 MB per minute

File Verification:
☐ 6. Open in QuickTime → File plays correctly
☐ 7. Check duration → Matches recording time (±0.5s)
☐ 8. Check resolution → Get Info shows correct dimensions
☐ 9. Check video quality → No artifacts, smooth playback
☐ 10. Check frame rate → Smooth motion at selected FPS

Different Settings:
☐ 11. Record at 720p → Verify output resolution
☐ 12. Record at 1080p → Verify output resolution
☐ 13. Record at 30 FPS → Verify smooth playback
☐ 14. Record at 60 FPS → Verify smooth playback
☐ 15. Record 1 minute → Verify file size ~2.5 MB (1080p)

Console Logs:
☐ 16. See "📹 Frame X → Encoder" every second
☐ 17. See "💾 Frame X encoded to MP4" every second
☐ 18. See final "✅ Encoding finished" message
☐ 19. See file path printed to console
☐ 20. See file size printed to console

Performance:
☐ 21. CPU usage < 30% during encoding
☐ 22. Memory usage < 250 MB
☐ 23. No dropped frames (frame count steady)
☐ 24. Encoding keeps up with capture (no lag)
```

---

## Success Criteria

**By end of Day 21, verify:**

- ✅ Capture pipeline connected to encoder
- ✅ MP4 files created in temp directory
- ✅ Files are playable in QuickTime Player
- ✅ Duration matches recording time
- ✅ Resolution matches settings
- ✅ File size reasonable (~1-2 MB/min for 1080p)
- ✅ Console shows encoding progress logs
- ✅ No frame drops or encoding errors
- ✅ Can record multiple times without issues

**Console Output Example:**
```
📹 Starting capture...
✅ ScreenCaptureEngine: Capture started
✅ VideoEncoder: Started encoding to recording-ABC123.mp4
✅ Encoder started - Output: recording-ABC123.mp4
✅ Recording started - Region: (0.0, 0.0, 1920.0, 1080.0)
📹 Frame 30 → Encoder
💾 Frame 30 encoded to MP4
📹 Frame 60 → Encoder
💾 Frame 60 encoded to MP4
📹 Frame 90 → Encoder
💾 Frame 90 encoded to MP4
...
✅ ScreenCaptureEngine: Capture stopped - 1800 frames
✅ VideoEncoder: Finished encoding - 1800 frames written
✅ Encoding finished - File: /tmp/recording-ABC123.mp4
✅ Recording stopped
📁 File saved: /tmp/recording-ABC123.mp4
📊 Total frames: 1800
📏 File size: 2.34 MB
✅ Opened video in QuickTime for verification
```

---

## Common Issues & Troubleshooting

### Issue: AVAssetWriter fails to start
**Solution:** Check output URL is writable, file doesn't already exist, and video settings are valid

### Issue: Frames not being appended
**Solution:** Ensure `expectsMediaDataInRealTime = true` and check `isReadyForMoreMediaData` before appending

### Issue: File is corrupt or won't play
**Solution:** Make sure `finishEncoding()` is called and `assetWriter.finishWriting()` completes successfully

### Issue: File size too large
**Solution:** Check bitrate calculation - should be ~2.5 Mbps for 720p, ~5 Mbps for 1080p

---

## Next Steps

After Day 21 is complete, proceed to **[Day 22: File Management](day22-file-management.md)**

---

**Time Estimate:** 6-8 hours
**Status:** 📋 Planned
