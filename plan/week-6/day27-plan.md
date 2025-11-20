# Day 27 - Audio Integration Testing & Mixing

**Date:** November 20, 2025 (Revised)
**Goal:** Verify each audio source works independently, then implement mixing
**Status:** 🔄 In Progress

---

## Overview - REVISED APPROACH

Based on feedback, we're taking a more incremental approach to ensure stability:

**Phase 1: Individual Source Testing (Priority)**
First, verify that each audio source works correctly in isolation:
1. Test system audio recording ONLY (disable microphone)
2. Test microphone recording ONLY (disable system audio)
3. Confirm both sources produce valid audio in final video

**Phase 2: Audio Mixing (After Phase 1 confirmed working)**
Only after confirming both sources work independently:
1. Implement audio mixing logic (combine buffers)
2. Add volume controls for each source
3. Add A/V sync monitoring

**Current State Analysis:**
- ✅ Video capture working (ScreenCaptureEngine)
- ✅ System audio capture implemented via ScreenCaptureKit (Day 25)
- ✅ Microphone capture implemented via AVAudioEngine (Day 26)
- ⚠️ System audio recording NOT yet tested end-to-end
- ⚠️ Microphone recording NOT yet tested end-to-end
- ❌ No mutually exclusive toggle enforcement yet
- ❌ No audio mixing implemented
- ❌ A/V sync not verified

**Phase 1 Target State:**
- ✅ Users can enable system audio OR microphone (mutually exclusive)
- ✅ System audio only recording produces valid audio output
- ✅ Microphone only recording produces valid audio output
- ✅ Both tested with actual playback verification

**Phase 2 Target State:**
- ✅ System audio + microphone mixed into SINGLE audio track
- ✅ Individual volume controls for each source (0.0-1.0)
- ✅ Real-time audio mixing before encoding
- ✅ Audio/video sync verified (±50ms tolerance)

---

## Phase 1: Individual Source Testing

### Implementation Tasks

**Task 1: Make Audio Toggles Mutually Exclusive (30 min)**

**Goal:** Ensure only ONE audio source can be enabled at a time for testing

**Files to modify:**
- `MyRec/Views/Settings/SettingsBarView.swift`

**Changes:**
1. Add `onChange` handler to system audio toggle
2. Add `onChange` handler to microphone toggle
3. When one is enabled, automatically disable the other
4. Log which source is active

**Task 2: Test System Audio Recording (30 min)**

**Test procedure:**
1. Enable system audio toggle ONLY
2. Disable microphone toggle
3. Start recording (play music/video in background)
4. Record for 30 seconds
5. Stop recording
6. Open video file and verify audio is present
7. Check audio sync with video

**Success criteria:**
- [ ] Video file contains audio track
- [ ] Audio is audible and clear
- [ ] Audio matches what was playing during recording
- [ ] No crashes or errors

**Task 3: Test Microphone Recording (30 min)**

**Test procedure:**
1. Disable system audio toggle
2. Enable microphone toggle ONLY
3. Grant microphone permission if needed
4. Start recording (speak into microphone)
5. Record for 30 seconds
6. Stop recording
7. Open video file and verify microphone audio is present
8. Check audio quality

**Success criteria:**
- [ ] Video file contains audio track
- [ ] Microphone audio is audible and clear
- [ ] Voice is recognizable
- [ ] No crashes or errors

**Task 4: Debug and Fix Issues (60 min)**

Based on test results from Tasks 2 & 3:
- Fix any audio encoding issues
- Fix any synchronization problems
- Fix any crashes or errors
- Verify both sources work reliably

### Solution: Add Mixing Layer

```swift
// NEW: Buffer queue approach
class AudioCaptureEngine {
    private var systemAudioBuffers: [(buffer: CMSampleBuffer, timestamp: CMTime)] = []
    private var microphoneBuffers: [(buffer: AVAudioPCMBuffer, timestamp: CMTime)] = []
    private let bufferLock = NSLock()

    // NEW: Volume controls
    var systemVolume: Float = 1.0  // 0.0 to 1.0
    var microphoneVolume: Float = 1.0  // 0.0 to 1.0

    // When system audio arrives:
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        bufferLock.lock()
        systemAudioBuffers.append((sampleBuffer, timestamp))
        tryMixAndWrite()
        bufferLock.unlock()
    }

    // When microphone audio arrives:
    func processMicrophoneBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        bufferLock.lock()
        microphoneBuffers.append((buffer, calculateTimestamp(time)))
        tryMixAndWrite()
        bufferLock.unlock()
    }

    // Mix and write if we have both:
    private func tryMixAndWrite() {
        guard !systemAudioBuffers.isEmpty,
              !microphoneBuffers.isEmpty else { return }

        let sysBuf = systemAudioBuffers.removeFirst()
        let micBuf = microphoneBuffers.removeFirst()

        // Mix PCM data
        let mixed = mixBuffers(sysBuf, micBuf)

        // Write to single asset writer input
        assetWriterInput?.append(mixed)
    }
}
```

### Synchronization Strategy

```
System Audio Buffer → Queue →
                              ↓ [Match timestamps] → Mix → Write to AssetWriter
Microphone Buffer  → Queue →
                              ↑
                         Monitor drift
                         Log if > 50ms
```

**Phase 1 (Day 27):** Monitoring only - log drift, don't correct
**Phase 2 (Future):** Add correction if needed based on test results

---

## Revised Implementation Tasks (Simplified)

### Task 1: Add Audio Mixing to AudioCaptureEngine (90 min)

**File:** `MyRec/Services/AudioCaptureEngine.swift` (modify existing)

**Purpose:** Add buffer queuing and mixing logic

**Changes to make:**

```swift
// ADD: New properties
public class AudioCaptureEngine: NSObject, ObservableObject {
    // Mixing properties
    @Published var systemVolume: Float = 1.0
    @Published var microphoneVolume: Float = 1.0
    @Published var isMixingEnabled = false

    private var systemAudioBuffers: [CMSampleBuffer] = []
    private var microphoneBuffers: [CMSampleBuffer] = []
    private let bufferLock = NSLock()
    private var syncMonitor = SyncMonitor()

    // Mixing mode: when both system audio AND microphone enabled
    var shouldMixAudio: Bool {
        // Determined by RecordingManager based on which sources are enabled
        return isMixingEnabled
    }
}

// MODIFY: processSampleBuffer
func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
    if shouldMixAudio {
        // Queue for mixing
        bufferLock.lock()
        defer { bufferLock.unlock() }
        systemAudioBuffers.append(sampleBuffer)
        tryMixAndWrite()
    } else {
        // Write directly (system audio only mode)
        guard let input = assetWriterInput,
              input.isReadyForMoreMediaData else { return }
        updateAudioLevel(from: sampleBuffer)
        audioQueue.async { input.append(sampleBuffer) }
    }
}

// MODIFY: processMicrophoneBuffer
private func processMicrophoneBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
    updateMicrophoneLevel(from: buffer)

    guard isCapturing else { return }

    if shouldMixAudio {
        // Convert to CMSampleBuffer and queue for mixing
        if let sampleBuffer = convertToCMSampleBuffer(buffer, at: time) {
            bufferLock.lock()
            defer { bufferLock.unlock() }
            microphoneBuffers.append(sampleBuffer)
            tryMixAndWrite()
        }
    } else {
        // Write directly (microphone only mode)
        if let sampleBuffer = convertToCMSampleBuffer(buffer, at: time) {
            assetWriterInput?.append(sampleBuffer)
        }
    }
}

// NEW: Mix and write
private func tryMixAndWrite() {
    guard !systemAudioBuffers.isEmpty,
          !microphoneBuffers.isEmpty else { return }

    let systemBuffer = systemAudioBuffers.removeFirst()
    let micBuffer = microphoneBuffers.removeFirst()

    // Monitor sync
    let sysPTS = CMSampleBufferGetPresentationTimeStamp(systemBuffer)
    let micPTS = CMSampleBufferGetPresentationTimeStamp(micBuffer)
    syncMonitor.recordSyncPoint(videoTime: sysPTS, audioTime: micPTS)

    // Mix buffers
    if let mixedBuffer = mixBuffers(system: systemBuffer, microphone: micBuffer) {
        guard let input = assetWriterInput,
              input.isReadyForMoreMediaData else { return }

        audioQueue.async {
            input.append(mixedBuffer)
        }
    }
}

// NEW: Actual mixing logic
private func mixBuffers(system: CMSampleBuffer, microphone: CMSampleBuffer) -> CMSampleBuffer? {
    // Extract PCM data from both buffers
    guard let systemPCM = extractPCMData(from: system),
          let micPCM = extractPCMData(from: microphone) else {
        return nil
    }

    // Use shorter length
    let length = min(systemPCM.count, micPCM.count)
    var mixedData = [Float](repeating: 0, count: length)

    // Mix with volume controls
    for i in 0..<length {
        let systemSample = systemPCM[i] * systemVolume
        let micSample = micPCM[i] * microphoneVolume
        mixedData[i] = systemSample + micSample

        // Soft clipping to prevent distortion
        if mixedData[i] > 1.0 {
            mixedData[i] = tanh(mixedData[i])
        } else if mixedData[i] < -1.0 {
            mixedData[i] = tanh(mixedData[i])
        }
    }

    // Convert back to CMSampleBuffer using system buffer's timestamp
    return createCMSampleBuffer(
        from: mixedData,
        timestamp: CMSampleBufferGetPresentationTimeStamp(system),
        sampleRate: 48000
    )
}

// NEW: Extract PCM data from CMSampleBuffer
private func extractPCMData(from sampleBuffer: CMSampleBuffer) -> [Float]? {
    guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
        return nil
    }

    var length = 0
    var dataPointer: UnsafeMutablePointer<Int8>?

    let status = CMBlockBufferGetDataPointer(
        blockBuffer,
        atOffset: 0,
        lengthAtOffsetOut: &length,
        totalLengthOut: nil,
        dataPointerOut: &dataPointer
    )

    guard status == noErr, let data = dataPointer else {
        return nil
    }

    // Assuming Float32 PCM format
    let samples = UnsafeRawPointer(data).assumingMemoryBound(to: Float.self)
    let count = length / MemoryLayout<Float>.size

    return Array(UnsafeBufferPointer(start: samples, count: count))
}

// NEW: Create CMSampleBuffer from PCM data
private func createCMSampleBuffer(
    from pcmData: [Float],
    timestamp: CMTime,
    sampleRate: Double
) -> CMSampleBuffer? {
    // Implementation using AVAudioFormat and CMSampleBufferCreate
    // (Similar to existing convertToCMSampleBuffer method)
    // Details to be implemented during Task 1
    return nil  // Placeholder
}
```

**Subtasks:**
1. Add mixing properties and buffer queues
2. Modify processSampleBuffer to support mixing mode
3. Modify processMicrophoneBuffer to support mixing mode
4. Implement tryMixAndWrite logic
5. Implement mixBuffers with volume controls
6. Implement extractPCMData helper
7. Implement createCMSampleBuffer helper
8. Test with both audio sources enabled

---

### Task 2: Create SyncMonitor Helper (30 min)

**File:** `MyRec/Services/SyncMonitor.swift` (new)

**Purpose:** Monitor A/V sync drift and log warnings

```swift
import Foundation
import CoreMedia

class SyncMonitor {
    private var syncPoints: [(videoTime: CMTime, audioTime: CMTime, drift: Double)] = []
    private let maxDriftMs: Double = 50.0

    func recordSyncPoint(videoTime: CMTime, audioTime: CMTime) {
        let videoSeconds = CMTimeGetSeconds(videoTime)
        let audioSeconds = CMTimeGetSeconds(audioTime)
        let driftMs = (videoSeconds - audioSeconds) * 1000

        syncPoints.append((videoTime, audioTime, driftMs))

        // Keep last 100 points
        if syncPoints.count > 100 {
            syncPoints.removeFirst()
        }

        // Log significant drift
        if abs(driftMs) > maxDriftMs {
            print("⚠️ SYNC DRIFT: \(String(format: "%.2f", driftMs))ms at \(String(format: "%.2f", videoSeconds))s")
        }
    }

    func getCurrentDrift() -> Double {
        syncPoints.last?.drift ?? 0
    }

    func getAverageDrift() -> Double {
        guard !syncPoints.isEmpty else { return 0 }
        return syncPoints.map { $0.drift }.reduce(0, +) / Double(syncPoints.count)
    }

    func getMaxDrift() -> Double {
        syncPoints.map { abs($0.drift) }.max() ?? 0
    }

    func reset() {
        syncPoints.removeAll()
    }

    func printSyncReport() {
        print("📊 Sync Report:")
        print("   Total samples: \(syncPoints.count)")
        print("   Current drift: \(String(format: "%.2f", getCurrentDrift()))ms")
        print("   Average drift: \(String(format: "%.2f", getAverageDrift()))ms")
        print("   Max drift: \(String(format: "%.2f", getMaxDrift()))ms")
    }
}
```

---

### Task 3: Add Volume Control UI (45 min)

**File:** `MyRec/Views/Settings/SettingsBarView.swift` (modify existing)

**Purpose:** Add sliders for system audio and microphone volume

**Changes:**
```swift
// Add to existing SettingsBarView
VStack {
    // Existing settings...

    if viewModel.systemAudioEnabled || viewModel.microphoneEnabled {
        Divider()

        VStack(spacing: 8) {
            Text("Audio Levels")
                .font(.caption)
                .foregroundColor(.secondary)

            if viewModel.systemAudioEnabled {
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .frame(width: 16)
                    Slider(value: $viewModel.systemVolume, in: 0...1)
                        .frame(width: 100)
                    Text("\(Int(viewModel.systemVolume * 100))%")
                        .font(.caption2)
                        .frame(width: 35)
                }
            }

            if viewModel.microphoneEnabled {
                HStack {
                    Image(systemName: "mic")
                        .frame(width: 16)
                    Slider(value: $viewModel.microphoneVolume, in: 0...1)
                        .frame(width: 100)
                    Text("\(Int(viewModel.microphoneVolume * 100))%")
                        .font(.caption2)
                        .frame(width: 35)
                }
            }
        }
    }
}
```

**Also add to RegionSelectionViewModel:**
```swift
@Published var systemVolume: Float = 1.0
@Published var microphoneVolume: Float = 1.0

// In toggleSystemAudio() and toggleMicrophone()
// Connect these to audioEngine.systemVolume and audioEngine.microphoneVolume
```

---

### Task 4: Write Unit Tests (45 min)

**File:** `Tests/MyRecTests/AudioMixingTests.swift` (new)

**Purpose:** Test audio mixing logic

```swift
import XCTest
@testable import MyRec

final class AudioMixingTests: XCTestCase {
    func testVolumeMixing() {
        // Create mock PCM data
        let systemData: [Float] = [0.5, 0.5, 0.5, 0.5]
        let micData: [Float] = [0.3, 0.3, 0.3, 0.3]

        // Mix with different volumes
        let systemVolume: Float = 1.0
        let micVolume: Float = 0.5

        var mixed = [Float](repeating: 0, count: 4)
        for i in 0..<4 {
            mixed[i] = (systemData[i] * systemVolume) + (micData[i] * micVolume)
        }

        // Expected: 0.5 + (0.3 * 0.5) = 0.65
        XCTAssertEqual(mixed[0], 0.65, accuracy: 0.01)
    }

    func testSyncMonitor() {
        let monitor = SyncMonitor()

        let time1 = CMTime(seconds: 1.000, preferredTimescale: 1000)
        let time2 = CMTime(seconds: 1.001, preferredTimescale: 1000)

        monitor.recordSyncPoint(videoTime: time1, audioTime: time2)

        // Drift should be -1ms (audio ahead by 1ms)
        XCTAssertEqual(monitor.getCurrentDrift(), -1.0, accuracy: 0.1)
    }

    func testSoftClipping() {
        // Test that values > 1.0 are clipped
        let value: Float = 1.5
        let clipped = tanh(value)

        XCTAssertLessThan(clipped, 1.0)
        XCTAssertGreaterThan(clipped, 0.9)  // tanh(1.5) ≈ 0.905
    }
}
```

---

### Task 5: Integration Testing & Long Recording Test (120 min)

**Manual test scenarios:**

1. **Basic mixing test (10 min):**
   - [ ] Enable system audio only → record → verify audio present
   - [ ] Enable microphone only → record → verify audio present
   - [ ] Enable both → record → verify both audible in output

2. **Volume control test (15 min):**
   - [ ] System at 100%, mic at 50% → verify levels
   - [ ] System at 50%, mic at 100% → verify levels
   - [ ] System at 0% (muted), mic at 100% → verify only mic audible
   - [ ] Both at 50% → verify balanced mix

3. **Synchronization test (30 min):**
   - [ ] Record with visible timer on screen
   - [ ] Play audio click/beep every second
   - [ ] Record for 5 minutes
   - [ ] Check sync at 0s, 30s, 1min, 2min, 5min
   - [ ] Measure drift in video player/editor

4. **Long recording test (60 min):**
   - [ ] Record for 30+ minutes
   - [ ] Monitor console for drift warnings
   - [ ] Check memory usage (Activity Monitor)
   - [ ] Verify final sync is within ±50ms
   - [ ] Check for buffer overflow/underflow logs

5. **Edge cases (5 min):**
   - [ ] Very loud system audio + quiet mic
   - [ ] Very loud mic + quiet system audio
   - [ ] Both at maximum (check clipping/distortion)

---

---

## Phase 2: Audio Mixing Implementation

**NOTE:** Only proceed to Phase 2 after Phase 1 tests pass!

### Implementation Tasks

**Task 5: Create SyncMonitor Helper (30 min)**
- Create `MyRec/Services/SyncMonitor.swift`
- Implement drift tracking and logging
- Add console reporting

**Task 6: Implement Audio Mixing in AudioCaptureEngine (90 min)**
- Add buffer queues for system audio and microphone
- Implement `mixBuffers()` method to combine PCM data
- Add soft clipping to prevent distortion
- Update `processSampleBuffer()` to queue when mixing mode enabled
- Update `processMicrophoneBuffer()` to queue when mixing mode enabled

**Task 7: Add Volume Controls (45 min)**
- Add `@Published var systemVolume: Float = 1.0` to AudioCaptureEngine
- Add `@Published var microphoneVolume: Float = 1.0` to AudioCaptureEngine
- Add sliders to SettingsBarView
- Connect sliders to AudioCaptureEngine properties

**Task 8: Enable Both Audio Sources & Test Mixing (60 min)**
- Remove mutually exclusive toggle logic
- Allow both audio sources to be enabled simultaneously
- Test mixed audio recording
- Verify both sources audible in final video
- Check for clipping or distortion

---

## Revised Time Breakdown

### Phase 1: Individual Source Testing (Current Focus)
| Task | Estimated | Actual |
|------|-----------|--------|
| Make toggles mutually exclusive | 30 min | - |
| Test system audio recording | 30 min | - |
| Test microphone recording | 30 min | - |
| Debug and fix issues | 60 min | - |
| **Phase 1 Total** | **2.5 hours** | - |

### Phase 2: Audio Mixing (After Phase 1)
| Task | Estimated | Actual |
|------|-----------|--------|
| Create SyncMonitor | 30 min | - |
| Implement audio mixing logic | 90 min | - |
| Add volume controls | 45 min | - |
| Test mixing & verify quality | 60 min | - |
| Write unit tests | 45 min | - |
| **Phase 2 Total** | **~4.5 hours** | - |

**Total Estimated:** ~7 hours (split across 2 sessions if needed)

---

## Success Criteria

### Phase 1 Success Criteria (Must complete first)

**Functional:**
- [ ] Only one audio source can be enabled at a time (mutually exclusive toggles)
- [ ] System audio only recording works and produces audible output
- [ ] Microphone only recording works and produces audible output
- [ ] No crashes during recording or playback

**Quality:**
- [ ] Audio is clearly audible in both test cases
- [ ] Audio sync is acceptable (rough check, no precise measurement yet)
- [ ] No build errors or warnings

**Testing:**
- [ ] System audio test recorded and played back successfully
- [ ] Microphone test recorded and played back successfully
- [ ] Build passes: `swift test` runs without errors

### Phase 2 Success Criteria (After Phase 1 passes)

**Functional:**
- [ ] System audio + microphone mixed into single track
- [ ] Volume controls working (0-100% for each source)
- [ ] Both sources audible in final video
- [ ] No clipping or distortion

**Quality:**
- [ ] A/V sync within ±50ms throughout recording
- [ ] Max drift logged and monitored
- [ ] No memory leaks or crashes
- [ ] Zero build errors/warnings

**Testing:**
- [ ] Unit tests pass (swift test)
- [ ] Manual mixing tests pass
- [ ] Both sources audible and balanced in mixed recording

---

## Blockers & Risk Mitigation

**Potential Blockers:**
1. PCM format mismatch between system audio and microphone
   - **Mitigation:** Convert both to Float32 PCM before mixing

2. Buffer timing mismatch
   - **Mitigation:** Use presentation timestamps, queue buffers

3. Excessive drift accumulation
   - **Mitigation:** Log and monitor; implement correction if needed (Phase 2)

4. Memory buildup from buffer queues
   - **Mitigation:** Limit queue size, drop old buffers if needed

---

## Notes for Implementation

**Important:**
- Both processSampleBuffer and processMicrophoneBuffer must check `shouldMixAudio` flag
- When only ONE audio source enabled → write directly (no mixing overhead)
- When BOTH enabled → queue buffers and mix
- Use system audio timestamp as canonical time (it's from ScreenCaptureKit)
- Log ALL sync drift warnings for analysis

**Testing priority:**
1. Basic mixing (high priority)
2. Volume controls (high priority)
3. Short sync test (high priority)
4. Long recording (medium priority - can be done overnight)

---

## Results (End of Day)

**Status:** In Progress - Phase 1

### Phase 1 Results

**Completed:**
- [ ] Mutually exclusive toggles implemented
- [ ] System audio test completed
- [ ] Microphone test completed
- [ ] Both tests verified with playback

**Phase 1 Metrics:**
- Build status: -
- System audio quality: -
- Microphone audio quality: -
- Issues found: -

### Phase 2 Results (If time permits)

**Completed:**
- [ ] Audio mixing implemented
- [ ] Volume controls functional
- [ ] Mixed recording tested
- [ ] Unit tests passing

**Phase 2 Metrics:**
- Build status: -
- Test pass rate: -
- Max observed drift: -
- Mix quality: -

**Blockers encountered:** -

**Next steps:**
- If Phase 1 complete: Proceed to Phase 2
- If Phase 2 complete: Move to Week 7 tasks
- If blockers found: Debug and resolve before proceeding

---

**Last Updated:** November 20, 2025 (Day 27 plan revised - incremental approach)
