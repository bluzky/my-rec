# Day 27 - Audio Mixing & Synchronization

**Date:** November 23, 2025
**Goal:** Mix system audio and microphone, ensure perfect A/V sync
**Status:** ⏳ Pending

---

## Overview

Today is the final day of Week 6, where we'll complete the audio integration by implementing professional-grade audio mixing and ensuring rock-solid audio/video synchronization. This is critical for recording quality.

**Current State:**
- ✅ Video capture working
- ✅ System audio capture working (Day 25)
- ✅ Microphone capture working (Day 26)
- ❌ No audio mixing (both sources separate)
- ❌ A/V sync not verified for long recordings

**Target State:**
- ✅ System audio + microphone mixed into single track
- ✅ Individual volume controls for each source
- ✅ Audio/video sync verified (±50ms tolerance)
- ✅ Drift detection and correction
- ✅ Long recording stability (30+ min)

---

## Technical Approach

### 1. Audio Mixing Strategy

```swift
// Real-time mixing using AVAudioEngine
let mixer = AVAudioMixerNode()

// Attach system audio
mixer.connect(systemAudioNode, to: mixer, format: audioFormat)
mixer.volume(forPlayer: systemAudioNode) = systemVolume

// Attach microphone
mixer.connect(microphoneNode, to: mixer, format: audioFormat)
mixer.volume(forPlayer: microphoneNode) = micVolume

// Output mixed audio
let mixedOutput = mixer.outputFormat(forBus: 0)
```

### 2. Synchronization Approach

```
Video Frame (CMTime: 00:00:01.033)
    ↓
System Audio Sample (CMTime: 00:00:01.035)  [+2ms drift]
    ↓
Mic Audio Sample (CMTime: 00:00:01.031)  [-2ms drift]
    ↓
Drift Detection: MAX_DRIFT = 50ms
    ↓
If drift > 50ms → Apply correction
    ↓
Write to AVAssetWriter with corrected timestamps
```

---

## Implementation Tasks

### Task 1: Create AudioMixerEngine (120 min)

**File:** `Sources/MyRec/Services/AudioMixerEngine.swift` (new)

**Purpose:** Mix multiple audio sources with volume control

```swift
import AVFoundation
import Accelerate

@MainActor
class AudioMixerEngine: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var systemVolume: Float = 1.0  // 0.0 to 1.0
    @Published var microphoneVolume: Float = 1.0  // 0.0 to 1.0
    @Published var mixedLevel: Float = 0.0

    // MARK: - Private Properties
    private var assetWriterInput: AVAssetWriterInput?
    private let mixQueue = DispatchQueue(label: "com.myrec.audiomix")
    private var pendingSystemBuffers: [TimestampedAudioBuffer] = []
    private var pendingMicBuffers: [TimestampedAudioBuffer] = []
    private let bufferLock = NSLock()

    // Sync tracking
    private var baselineTimestamp: CMTime?
    private var videoPTS: CMTime?  // Latest video presentation timestamp

    // MARK: - Setup
    func setupAudioInput(for assetWriter: AVAssetWriter) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 256000  // Higher bitrate for mixed audio
        ]

        let input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: settings
        )

        input.expectsMediaDataInRealTime = true

        guard assetWriter.canAdd(input) else {
            throw AudioMixerError.cannotAddInput
        }

        assetWriter.add(input)
        self.assetWriterInput = input
    }

    // MARK: - Audio Processing
    func processSystemAudioBuffer(_ buffer: CMSampleBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        let timestampedBuffer = TimestampedAudioBuffer(
            buffer: buffer,
            source: .system
        )

        pendingSystemBuffers.append(timestampedBuffer)
        tryMixBuffers()
    }

    func processMicrophoneBuffer(_ buffer: CMSampleBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        let timestampedBuffer = TimestampedAudioBuffer(
            buffer: buffer,
            source: .microphone
        )

        pendingMicBuffers.append(timestampedBuffer)
        tryMixBuffers()
    }

    func updateVideoTimestamp(_ timestamp: CMTime) {
        self.videoPTS = timestamp
    }

    // MARK: - Mixing Logic
    private func tryMixBuffers() {
        // Wait until we have buffers from both sources
        guard !pendingSystemBuffers.isEmpty,
              !pendingMicBuffers.isEmpty else {
            return
        }

        // Get oldest buffer from each source
        let systemBuffer = pendingSystemBuffers.removeFirst()
        let micBuffer = pendingMicBuffers.removeFirst()

        // Check timestamp alignment
        let systemPTS = CMSampleBufferGetPresentationTimeStamp(systemBuffer.buffer)
        let micPTS = CMSampleBufferGetPresentationTimeStamp(micBuffer.buffer)

        let drift = CMTimeGetSeconds(CMTimeSubtract(systemPTS, micPTS))

        if abs(drift) > 0.050 {  // 50ms threshold
            print("⚠️ Audio drift detected: \(drift * 1000)ms")
            // Apply correction (implementation below)
        }

        // Mix buffers
        if let mixedBuffer = mixBuffers(systemBuffer, micBuffer) {
            writeToAssetWriter(mixedBuffer)
        }
    }

    private func mixBuffers(
        _ systemBuffer: TimestampedAudioBuffer,
        _ micBuffer: TimestampedAudioBuffer
    ) -> CMSampleBuffer? {

        guard let systemData = extractPCMData(from: systemBuffer.buffer),
              let micData = extractPCMData(from: micBuffer.buffer) else {
            return nil
        }

        // Ensure same length (use shorter)
        let length = min(systemData.count, micData.count)

        // Apply volume and mix
        var mixedData = [Float](repeating: 0, count: length)

        for i in 0..<length {
            mixedData[i] = (systemData[i] * systemVolume) +
                          (micData[i] * microphoneVolume)

            // Soft clipping
            mixedData[i] = tanh(mixedData[i])
        }

        // Update mixed level for UI
        updateMixedLevel(from: mixedData)

        // Convert back to CMSampleBuffer
        return createSampleBuffer(
            from: mixedData,
            timestamp: CMSampleBufferGetPresentationTimeStamp(systemBuffer.buffer)
        )
    }

    private func extractPCMData(from buffer: CMSampleBuffer) -> [Float]? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(buffer) else {
            return nil
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

        guard let data = dataPointer else { return nil }

        // Convert to Float array
        let samples = UnsafeRawPointer(data)
            .assumingMemoryBound(to: Float.self)

        return Array(UnsafeBufferPointer(
            start: samples,
            count: length / MemoryLayout<Float>.size
        ))
    }

    private func createSampleBuffer(
        from pcmData: [Float],
        timestamp: CMTime
    ) -> CMSampleBuffer? {

        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 2,
            interleaved: false
        )!

        let frameLength = AVAudioFrameCount(pcmData.count / 2)

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: frameLength
        ) else {
            return nil
        }

        buffer.frameLength = frameLength

        // Copy PCM data to buffer
        let channelData = buffer.floatChannelData!
        for i in 0..<Int(frameLength) {
            channelData[0][i] = pcmData[i * 2]      // Left channel
            channelData[1][i] = pcmData[i * 2 + 1]  // Right channel
        }

        // Convert to CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(
                value: CMTimeValue(frameLength),
                timescale: 48000
            ),
            presentationTimeStamp: timestamp,
            decodeTimeStamp: .invalid
        )

        guard let formatDesc = audioFormat.formatDescription else {
            return nil
        }

        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleCount: CMItemCount(frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }

    private func writeToAssetWriter(_ buffer: CMSampleBuffer) {
        guard let input = assetWriterInput,
              input.isReadyForMoreMediaData else {
            return
        }

        mixQueue.async {
            input.append(buffer)
        }
    }

    private func updateMixedLevel(from pcmData: [Float]) {
        let rms = sqrt(
            pcmData.reduce(0) { $0 + $1 * $1 } / Float(pcmData.count)
        )

        DispatchQueue.main.async {
            self.mixedLevel = min(rms * 10, 1.0)
        }
    }

    func stopMixing() {
        assetWriterInput?.markAsFinished()
    }
}

// MARK: - Supporting Types
struct TimestampedAudioBuffer {
    let buffer: CMSampleBuffer
    let source: AudioSource

    enum AudioSource {
        case system
        case microphone
    }
}

enum AudioMixerError: Error {
    case cannotAddInput
    case bufferExtractionFailed
    case mixingFailed
}
```

---

### Task 2: Implement Drift Detection & Correction (60 min)

**File:** `Sources/MyRec/Services/SyncMonitor.swift` (new)

**Purpose:** Monitor and correct A/V sync drift

```swift
import Foundation
import CoreMedia

class SyncMonitor {
    private var baselineVideoTime: CMTime?
    private var baselineAudioTime: CMTime?
    private var driftHistory: [Double] = []
    private let maxDriftMs: Double = 50.0

    func recordSyncPoint(videoTime: CMTime, audioTime: CMTime) {
        if baselineVideoTime == nil {
            baselineVideoTime = videoTime
            baselineAudioTime = audioTime
            return
        }

        // Calculate elapsed time for each stream
        let videoElapsed = CMTimeGetSeconds(
            CMTimeSubtract(videoTime, baselineVideoTime!)
        )
        let audioElapsed = CMTimeGetSeconds(
            CMTimeSubtract(audioTime, baselineAudioTime!)
        )

        // Calculate drift
        let drift = (videoElapsed - audioElapsed) * 1000  // in milliseconds

        driftHistory.append(drift)

        // Keep last 100 measurements
        if driftHistory.count > 100 {
            driftHistory.removeFirst()
        }

        // Log significant drift
        if abs(drift) > maxDriftMs {
            print("⚠️ SYNC DRIFT: \(String(format: "%.2f", drift))ms")
        }
    }

    func getCurrentDrift() -> Double {
        guard !driftHistory.isEmpty else { return 0 }
        return driftHistory.last ?? 0
    }

    func getAverageDrift() -> Double {
        guard !driftHistory.isEmpty else { return 0 }
        return driftHistory.reduce(0, +) / Double(driftHistory.count)
    }

    func needsCorrection() -> Bool {
        abs(getAverageDrift()) > maxDriftMs
    }

    func suggestedCorrection() -> CMTime {
        let driftSeconds = getAverageDrift() / 1000.0
        return CMTime(seconds: -driftSeconds, preferredTimescale: 48000)
    }

    func reset() {
        baselineVideoTime = nil
        baselineAudioTime = nil
        driftHistory.removeAll()
    }
}
```

---

### Task 3: Add Volume Controls UI (60 min)

**File:** `Sources/MyRec/UI/Components/VolumeControlView.swift` (new)

```swift
import SwiftUI

struct VolumeControlView: View {
    @ObservedObject var mixer: AudioMixerEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Levels")
                .font(.headline)

            // System Audio
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("System Audio")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(mixer.systemVolume * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Slider(value: $mixer.systemVolume, in: 0...1)
                    .accentColor(.blue)
            }

            // Microphone
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("Microphone")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(mixer.microphoneVolume * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Slider(value: $mixer.microphoneVolume, in: 0...1)
                    .accentColor(.green)
            }

            Divider()

            // Mixed Output Level
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.orange)

                Text("Output")
                    .font(.caption)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))

                        RoundedRectangle(cornerRadius: 2)
                            .fill(levelColor)
                            .frame(width: geometry.size.width * CGFloat(mixer.mixedLevel))
                    }
                }
                .frame(height: 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var levelColor: Color {
        switch mixer.mixedLevel {
        case 0..<0.3: return .green
        case 0.3..<0.7: return .yellow
        case 0.7...1.0: return .red
        default: return .gray
        }
    }
}
```

---

### Task 4: Integrate Mixer with Recording Flow (45 min)

**File:** `Sources/MyRec/Managers/RecordingManager.swift`

**Updates:**
```swift
class RecordingManager: ObservableObject {
    @Published var audioMixer: AudioMixerEngine?

    func startRecording(
        settings: RecordingSettings,
        captureMode: CaptureMode
    ) async throws {

        // Create mixer if audio enabled
        if settings.systemAudioEnabled || settings.microphoneEnabled {
            let mixer = AudioMixerEngine()
            try mixer.setupAudioInput(for: videoEncoder.assetWriter)
            self.audioMixer = mixer
        }

        // Start video capture
        try await screenCaptureEngine.startCapture(/*...*/)

        // Start system audio
        if settings.systemAudioEnabled {
            screenCaptureEngine.onAudioBuffer = { [weak self] buffer in
                self?.audioMixer?.processSystemAudioBuffer(buffer)
            }
        }

        // Start microphone
        if settings.microphoneEnabled {
            try microphoneCaptureEngine?.startCapturing()
            microphoneCaptureEngine?.onAudioBuffer = { [weak self] buffer in
                self?.audioMixer?.processMicrophoneBuffer(buffer)
            }
        }
    }

    func stopRecording() async throws {
        audioMixer?.stopMixing()
        // ... rest of stop logic
    }
}
```

---

### Task 5: Long Recording Stability Test (90 min)

**Purpose:** Verify no drift over extended recordings

**Test Plan:**
1. **30-minute recording test:**
   - Record screen + system audio + mic for 30 min
   - Monitor drift in console logs
   - Verify final A/V sync

2. **Sync verification points:**
   - 0:00 - Start (baseline)
   - 5:00 - Check sync
   - 15:00 - Check sync
   - 30:00 - Check sync
   - Acceptable drift: < ±50ms

3. **Stress test:**
   - High CPU load during recording
   - Audio device changes
   - Volume adjustments during recording

---

## Testing Plan

### Unit Tests (45 min)

**File:** `Tests/MyRecTests/AudioMixerTests.swift` (new)

```swift
import XCTest
@testable import MyRec

final class AudioMixerTests: XCTestCase {
    func testVolumeMixing() {
        let mixer = AudioMixerEngine()

        mixer.systemVolume = 0.5
        mixer.microphoneVolume = 1.0

        // Create test buffers
        // Mix and verify output levels
    }

    func testSyncMonitor() {
        let monitor = SyncMonitor()

        let videoTime = CMTime(seconds: 1.0, preferredTimescale: 1000)
        let audioTime = CMTime(seconds: 1.001, preferredTimescale: 1000)

        monitor.recordSyncPoint(videoTime: videoTime, audioTime: audioTime)

        XCTAssertLessThan(abs(monitor.getCurrentDrift()), 50.0)
    }
}
```

---

### Manual Testing (120 min)

**Test Scenarios:**

1. **Basic mixing:**
   - [ ] Record with system audio only
   - [ ] Record with microphone only
   - [ ] Record with both sources
   - [ ] Verify both audible in playback

2. **Volume controls:**
   - [ ] Adjust system volume to 50%
   - [ ] Adjust mic volume to 75%
   - [ ] Record and verify levels correct
   - [ ] Test muting (volume = 0)

3. **Synchronization (critical):**
   - [ ] Record video with visible timer
   - [ ] Include audible beep every second
   - [ ] Check sync at 0s, 30s, 1min, 5min, 30min
   - [ ] Measure actual drift in video editor

4. **Edge cases:**
   - [ ] Very loud system audio + quiet mic
   - [ ] Quiet system audio + loud mic
   - [ ] Both at max volume (check clipping)
   - [ ] Rapid volume changes during recording

5. **Long duration:**
   - [ ] 30-minute recording
   - [ ] Monitor sync throughout
   - [ ] Check memory usage stays stable
   - [ ] Verify no buffer overflow

**Verification Checklist:**
- [ ] Mixed audio sounds natural
- [ ] Volume controls work as expected
- [ ] No clipping or distortion
- [ ] A/V sync within ±50ms
- [ ] Sync stable over 30+ min
- [ ] No memory leaks

---

## Expected Outcomes

### Functional Outcomes
✅ Audio mixing working perfectly
✅ Volume controls functional
✅ A/V sync verified (±50ms)
✅ Long recordings stable

### Technical Outcomes
✅ AudioMixerEngine implemented
✅ SyncMonitor tracking drift
✅ Volume UI integrated
✅ Drift correction working

### Quality Metrics
- Audio sync drift: < ±50ms
- Mixing quality: No distortion
- Long recording: 30+ min stable
- Zero memory leaks
- All tests passing

---

## Week 6 Completion Checklist

At end of Day 27, verify all week objectives:

### Core Features
- [ ] Region capture working (Day 23)
- [ ] Window capture working (Day 24)
- [ ] System audio capture (Day 25)
- [ ] Microphone capture (Day 26)
- [ ] Audio mixing (Day 27)
- [ ] A/V synchronization (Day 27)

### Quality Checks
- [ ] Zero build errors/warnings
- [ ] All unit tests pass
- [ ] Manual test scenarios pass
- [ ] Performance acceptable
- [ ] Memory usage stable

### Documentation
- [ ] Update week progress.md
- [ ] Document any blockers
- [ ] Note lessons learned
- [ ] Plan Week 7 adjustments

---

## Time Breakdown

| Task | Estimated | Actual |
|------|-----------|--------|
| AudioMixerEngine | 120 min | - |
| Drift detection | 60 min | - |
| Volume controls UI | 60 min | - |
| Integration | 45 min | - |
| Long recording test | 90 min | - |
| Unit tests | 45 min | - |
| Manual testing | 120 min | - |
| Week wrap-up | 30 min | - |
| **Total** | **~9.5 hours** | - |

---

## Results (End of Day)

**Status:** Not started

**Completed:**
- [ ] AudioMixerEngine created
- [ ] Audio mixing working
- [ ] Volume controls functional
- [ ] Sync verified
- [ ] Long recording tested
- [ ] All Week 6 objectives met

**Week 6 Summary:**
- (To be filled)

**Next Week (Week 7) Preview:**
- Pause/resume functionality
- Camera integration
- Advanced recording controls

---

**Last Updated:** November 19, 2025
