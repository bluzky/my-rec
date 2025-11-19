# Day 25 - System Audio Capture

**Date:** November 21, 2025
**Goal:** Implement system audio capture using ScreenCaptureKit audio streams
**Status:** ⏳ Pending

---

## Overview

Today we'll implement system audio capture - recording the audio output from applications playing on the Mac. This is a critical feature for recording tutorials, demos, and presentations.

**Current State:**
- ✅ Video capture working (screen, region, window)
- ❌ No audio capture
- ❌ Silent video recordings

**Target State:**
- ✅ System audio captured alongside video
- ✅ Audio encoded to AAC in MP4
- ✅ Audio/video synchronized
- ✅ Audio levels monitored

---

## Technical Approach

### 1. ScreenCaptureKit Audio API

```swift
// Enable audio in stream configuration
let config = SCStreamConfiguration()
config.capturesAudio = true
config.sampleRate = 48000
config.channelCount = 2

// Handle audio in stream output
extension ScreenCaptureEngine: SCStreamOutput {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {

        switch type {
        case .screen:
            // Handle video (existing)
            handleVideoSampleBuffer(sampleBuffer)

        case .audio:
            // Handle audio (new)
            handleAudioSampleBuffer(sampleBuffer)

        @unknown default:
            break
        }
    }
}
```

### 2. Audio Processing Pipeline

```
System Audio Output
    ↓
ScreenCaptureKit (PCM samples)
    ↓
AudioCaptureEngine (buffer management)
    ↓
AVAssetWriterInput (AAC encoding)
    ↓
MP4 File (audio track)
```

---

## Implementation Tasks

### Task 1: Create AudioCaptureEngine (90 min)

**File:** `Sources/MyRec/Services/AudioCaptureEngine.swift` (new)

**Purpose:** Manage audio capture and processing

```swift
import AVFoundation
import CoreMedia

@MainActor
class AudioCaptureEngine: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isCapturing = false
    @Published var audioLevel: Float = 0.0  // 0.0 to 1.0

    // MARK: - Private Properties
    private var assetWriterInput: AVAssetWriterInput?
    private var audioQueue = DispatchQueue(label: "com.myrec.audio")

    private var audioSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
    }

    // MARK: - Public Methods
    func setupAudioInput(for assetWriter: AVAssetWriter) throws {
        guard assetWriter.canApply(outputSettings: audioSettings,
                                   forMediaType: .audio) else {
            throw AudioError.unsupportedSettings
        }

        let input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: audioSettings
        )

        input.expectsMediaDataInRealTime = true

        if assetWriter.canAdd(input) {
            assetWriter.add(input)
            self.assetWriterInput = input
        } else {
            throw AudioError.cannotAddInput
        }
    }

    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let input = assetWriterInput,
              input.isReadyForMoreMediaData else {
            return
        }

        // Calculate audio level for monitoring
        updateAudioLevel(from: sampleBuffer)

        // Write to asset writer
        audioQueue.async { [weak self] in
            input.append(sampleBuffer)
        }
    }

    func startCapturing() {
        isCapturing = true
    }

    func stopCapturing() {
        isCapturing = false
        assetWriterInput?.markAsFinished()
    }

    // MARK: - Private Methods
    private func updateAudioLevel(from sampleBuffer: CMSampleBuffer) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &length,
            totalLengthOut: nil,
            dataPointerOut: &dataPointer
        )

        guard let data = dataPointer else { return }

        // Calculate RMS (Root Mean Square) for audio level
        let samples = UnsafeBufferPointer(
            start: UnsafeMutableRawPointer(data)
                .assumingMemoryBound(to: Int16.self),
            count: length / MemoryLayout<Int16>.size
        )

        var sum: Float = 0
        for sample in samples {
            let normalized = Float(sample) / Float(Int16.max)
            sum += normalized * normalized
        }

        let rms = sqrt(sum / Float(samples.count))
        DispatchQueue.main.async {
            self.audioLevel = rms
        }
    }
}

// MARK: - Errors
enum AudioError: Error {
    case unsupportedSettings
    case cannotAddInput
    case captureFailed
}
```

---

### Task 2: Update ScreenCaptureEngine for Audio (60 min)

**File:** `Sources/MyRec/Services/ScreenCaptureEngine.swift`

**Changes:**
1. Enable audio in stream configuration
2. Handle audio sample buffers
3. Pass to AudioCaptureEngine

```swift
class ScreenCaptureEngine: NSObject, ObservableObject {
    private var audioCaptureEngine: AudioCaptureEngine?

    func startCapture(
        resolution: Resolution,
        frameRate: FrameRate,
        mode: CaptureMode,
        captureAudio: Bool = true  // New parameter
    ) async throws {

        // Configure stream for audio
        let streamConfig = SCStreamConfiguration()
        // ... existing video config ...

        if captureAudio {
            streamConfig.capturesAudio = true
            streamConfig.sampleRate = 48000
            streamConfig.channelCount = 2
        }

        // Initialize audio engine if needed
        if captureAudio {
            audioCaptureEngine = AudioCaptureEngine()
        }

        // ... rest of setup
    }
}

// MARK: - SCStreamOutput
extension ScreenCaptureEngine: SCStreamOutput {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {

        switch type {
        case .screen:
            handleVideoSampleBuffer(sampleBuffer)

        case .audio:
            handleAudioSampleBuffer(sampleBuffer)

        @unknown default:
            break
        }
    }

    private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        audioCaptureEngine?.processSampleBuffer(sampleBuffer)
    }
}
```

---

### Task 3: Integrate with VideoEncoder (75 min)

**File:** `Sources/MyRec/Services/VideoEncoder.swift`

**Changes:**
1. Support audio track in AVAssetWriter
2. Coordinate video and audio inputs
3. Ensure proper synchronization

```swift
class VideoEncoder: ObservableObject {
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var audioCaptureEngine: AudioCaptureEngine?

    func startEncoding(
        outputURL: URL,
        resolution: Resolution,
        frameRate: FrameRate,
        includeAudio: Bool
    ) throws {

        // Create asset writer
        assetWriter = try AVAssetWriter(
            outputURL: outputURL,
            fileType: .mp4
        )

        // Add video input (existing)
        setupVideoInput(resolution: resolution, frameRate: frameRate)

        // Add audio input (new)
        if includeAudio {
            audioCaptureEngine = AudioCaptureEngine()
            try audioCaptureEngine?.setupAudioInput(for: assetWriter!)
        }

        // Start writing
        guard assetWriter!.startWriting() else {
            throw EncodingError.cannotStartWriting
        }

        assetWriter!.startSession(atSourceTime: .zero)
    }

    func processAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        audioCaptureEngine?.processSampleBuffer(sampleBuffer)
    }

    func finishEncoding() async throws {
        // Mark audio input as finished
        audioCaptureEngine?.stopCapturing()

        // Wait for both inputs
        videoInput?.markAsFinished()

        // Finish writing
        await assetWriter?.finishWriting()
    }
}
```

---

### Task 4: Add Audio Level Indicator UI (45 min)

**File:** `Sources/MyRec/UI/Components/AudioLevelIndicator.swift` (new)

**Purpose:** Visual feedback for audio levels

```swift
import SwiftUI

struct AudioLevelIndicator: View {
    @ObservedObject var audioEngine: AudioCaptureEngine
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(audioEngine.audioLevel > 0.01 ? .green : .gray)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))

                    // Level bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(levelColor)
                        .frame(width: geometry.size.width * CGFloat(audioEngine.audioLevel))
                }
            }
            .frame(height: 4)

            Text(String(format: "%.0f%%", audioEngine.audioLevel * 100))
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 35, alignment: .trailing)
        }
    }

    private var levelColor: Color {
        switch audioEngine.audioLevel {
        case 0..<0.3: return .green
        case 0.3..<0.7: return .yellow
        case 0.7...1.0: return .red
        default: return .gray
        }
    }
}
```

---

### Task 5: Update Settings Bar (30 min)

**File:** `Sources/MyRec/UI/RegionSelectionWindow.swift`

**Changes:**
1. Show audio level indicator when recording
2. Add system audio toggle
3. Display audio status

```swift
var settingsBar: some View {
    HStack {
        // ... existing controls ...

        if recordingManager.isRecording {
            AudioLevelIndicator(
                audioEngine: recordingManager.audioCaptureEngine,
                label: "System"
            )
            .frame(width: 150)
        }
    }
}
```

---

### Task 6: Audio Synchronization Setup (45 min)

**File:** `Sources/MyRec/Services/VideoEncoder.swift`

**Purpose:** Ensure audio and video stay in sync

```swift
class VideoEncoder: ObservableObject {
    private var recordingStartTime: CMTime?
    private let syncQueue = DispatchQueue(label: "com.myrec.sync")

    func processVideoBuffer(_ sampleBuffer: CMSampleBuffer, at time: CMTime) {
        // Store start time on first buffer
        if recordingStartTime == nil {
            recordingStartTime = time
        }

        // Calculate relative timestamp
        let relativeTime = CMTimeSubtract(time, recordingStartTime!)

        // Append with adjusted timestamp
        if videoInput?.isReadyForMoreMediaData == true {
            videoInput?.append(adjustTimestamp(sampleBuffer, to: relativeTime))
        }
    }

    func processAudioBuffer(_ sampleBuffer: CMSampleBuffer, at time: CMTime) {
        guard let startTime = recordingStartTime else {
            // Wait for video to start first
            return
        }

        // Calculate relative timestamp
        let relativeTime = CMTimeSubtract(time, startTime)

        // Append with adjusted timestamp
        if audioInput?.isReadyForMoreMediaData == true {
            audioInput?.append(adjustTimestamp(sampleBuffer, to: relativeTime))
        }
    }

    private func adjustTimestamp(
        _ sampleBuffer: CMSampleBuffer,
        to newTime: CMTime
    ) -> CMSampleBuffer {
        var timingInfo = CMSampleTimingInfo()
        timingInfo.presentationTimeStamp = newTime
        timingInfo.decodeTimeStamp = .invalid

        var adjustedBuffer: CMSampleBuffer?

        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            timingArray: &timingInfo,
            sampleBufferOut: &adjustedBuffer
        )

        return adjustedBuffer ?? sampleBuffer
    }
}
```

---

## Testing Plan

### Unit Tests (45 min)

**File:** `Tests/MyRecTests/AudioCaptureEngineTests.swift` (new)

```swift
import XCTest
@testable import MyRec

final class AudioCaptureEngineTests: XCTestCase {
    func testAudioEngineInitialization() {
        let engine = AudioCaptureEngine()
        XCTAssertFalse(engine.isCapturing)
        XCTAssertEqual(engine.audioLevel, 0.0)
    }

    func testAudioInputSetup() throws {
        let engine = AudioCaptureEngine()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.mp4")

        let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        try engine.setupAudioInput(for: assetWriter)

        XCTAssertNotNil(assetWriter.inputs.first(where: { $0.mediaType == .audio }))
    }

    func testAudioLevelCalculation() {
        // Create mock audio sample buffer
        // Test level calculation
        // Verify range 0.0-1.0
    }
}
```

---

### Manual Testing (60 min)

**Test Scenarios:**

1. **Basic system audio:**
   - [ ] Play music in Spotify/Apple Music
   - [ ] Start screen recording
   - [ ] Verify audio is captured
   - [ ] Check audio level indicator responds
   - [ ] Playback recorded video - audio present

2. **Different audio sources:**
   - [ ] YouTube video
   - [ ] System notifications
   - [ ] Game audio
   - [ ] Multiple apps simultaneously

3. **Audio quality:**
   - [ ] No distortion at normal levels
   - [ ] No crackling or artifacts
   - [ ] Stereo channels working
   - [ ] Bitrate appropriate (128 kbps)

4. **Synchronization:**
   - [ ] Record video with visible audio (timer beep)
   - [ ] Verify audio in sync at start
   - [ ] Check sync at 1 min mark
   - [ ] Check sync at 5 min mark
   - [ ] Acceptable drift < 50ms

5. **Edge cases:**
   - [ ] No audio playing (silent recording)
   - [ ] Very loud audio (check clipping)
   - [ ] Audio device change during recording
   - [ ] Multiple simultaneous sounds

**Verification Checklist:**
- [ ] Audio captured successfully
- [ ] AAC encoding working
- [ ] Audio level indicator functional
- [ ] Synchronization accurate
- [ ] File playback in QuickTime/VLC
- [ ] No audio artifacts or distortion

---

## Expected Outcomes

### Functional Outcomes
✅ System audio captured
✅ Audio encoded to AAC
✅ Audio/video synchronized
✅ Audio levels monitored

### Technical Outcomes
✅ AudioCaptureEngine implemented
✅ ScreenCaptureKit audio enabled
✅ VideoEncoder supports audio track
✅ Timestamp synchronization working

### Quality Metrics
- Zero build errors/warnings
- All tests pass
- Audio sync within ±50ms
- No audio distortion
- AAC bitrate 128 kbps

---

## Blockers & Risks

### Potential Blockers
1. **Audio permission issues:**
   - ScreenCaptureKit handles automatically
   - No additional permission needed for macOS 13+

2. **Timestamp synchronization:**
   - Use CMTime from sample buffers
   - AVAssetWriter handles alignment

3. **Buffer overflow:**
   - Implement queue management
   - Drop frames if buffers full

---

## Time Breakdown

| Task | Estimated | Actual |
|------|-----------|--------|
| AudioCaptureEngine | 90 min | - |
| ScreenCaptureEngine update | 60 min | - |
| VideoEncoder integration | 75 min | - |
| Audio level UI | 45 min | - |
| Settings bar update | 30 min | - |
| Synchronization | 45 min | - |
| Testing | 105 min | - |
| **Total** | **~7.5 hours** | - |

---

## Dependencies

### Required
- ✅ ScreenCaptureEngine (Days 20, 23-24)
- ✅ VideoEncoder (Day 21)
- ✅ RecordingManager

---

## Results (End of Day)

**Status:** Not started

**Completed:**
- [ ] AudioCaptureEngine created
- [ ] System audio capture working
- [ ] Audio encoding to AAC
- [ ] Audio level indicator functional
- [ ] Synchronization implemented
- [ ] Tests passing

**Blockers:** None

**Next Day:** Microphone input

---

**Last Updated:** November 19, 2025
