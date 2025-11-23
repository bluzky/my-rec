# Audio Mixing Learnings: System Audio + Microphone on macOS

## Project Context
**Date:** November 2025
**Task:** Implement simultaneous system audio and microphone recording for macOS screen recorder
**Platform:** macOS 15+ using ScreenCaptureKit
**Challenge:** Mix two audio sources with different formats into single output stream

---

## 🎯 Critical Learnings

### 1. **AVAssetWriter Format Locking is Strict**

**Discovery:** AVAssetWriter locks to the **first audio format it receives** and rejects any subsequent format changes.

**Symptom:**
```
Error Domain=AVFoundationErrorDomain Code=-11800 "The operation could not be completed"
UserInfo={NSLocalizedFailureReason=An unknown error occurred (-12737)...}
```

**Root Cause:**
- First buffer: Non-interleaved Float32 stereo 48kHz (system audio native)
- Second buffer: Interleaved Float32 stereo 48kHz (after mixing)
- Writer rejects format change → encoding fails

**Solution:**
```swift
// Lock format UPFRONT before any audio is sent to writer
if !formatLocked {
    outputFormat = makeInterleavedFloatFormat(sampleRate: 48000, channels: 2)
    formatLocked = true
}

// Convert ALL buffers to this format before forwarding
let converted = convertBuffer(sampleBuffer, targetFormat: outputFormat)
encoder.appendAudio(converted)
```

**Key Insight:** Create a **stable output format** independent of input formats, convert everything to match it.

---

### 2. **Format Description Must Match Actual Data**

**Discovery:** The `CMAudioFormatDescription` must **exactly match** the actual bytes in the buffer.

**Wrong Approach:**
```swift
// ❌ BUG: Data is interleaved Float32, but format says non-interleaved Int16
let formatDesc = CMSampleBufferGetFormatDescription(originalBuffer)  // Non-interleaved
let mixed = mixToInterleavedFloats(...)
return makeBuffer(from: mixed, formatDescription: formatDesc)  // MISMATCH!
```

**Result:** "Evil voice" distortion, speed artifacts, or garbage audio.

**Correct Approach:**
```swift
// ✅ Create NEW format description matching actual data
var asbd = AudioStreamBasicDescription(
    mSampleRate: 48000,
    mFormatID: kAudioFormatLinearPCM,
    mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,  // Interleaved
    mChannelsPerFrame: 2,
    mBitsPerChannel: 32
)
var formatDesc: CMAudioFormatDescription?
CMAudioFormatDescriptionCreate(..., asbd: &asbd, ..., formatDescriptionOut: &formatDesc)

return makeBuffer(from: interleavedFloatData, formatDescription: formatDesc)
```

**Key Insight:** **Data format = Format description**, always. No exceptions.

---

### 3. **macOS Audio Formats Vary by Device**

**Discovery:** Different audio devices use completely different formats.

| Device | Sample Rate | Bit Depth | Format | Flags | Interleaved |
|--------|-------------|-----------|---------|-------|-------------|
| System Audio | 48000 Hz | 32-bit | Float32 | 41 | ❌ No (planar) |
| Headphone Mic | 16000 Hz | 16-bit | Int16 | 12 | ✅ Yes |
| Built-in Mac Mic | 44100 Hz | 32-bit | Float32 | 9 | ✅ Yes |
| USB Audio Interface | 48000-192000 Hz | 32-bit | Float32/Int32 | Varies | Varies |

**Flag Decoding:**
```swift
// Flags: 41 (0b101001) = System Audio
kAudioFormatFlagIsFloat (1) + kAudioFormatFlagIsPacked (8) + kAudioFormatFlagIsNonInterleaved (32)

// Flags: 12 (0b001100) = Headphone Mic
kAudioFormatFlagIsSignedInteger (4) + kAudioFormatFlagIsPacked (8)

// Flags: 9 (0b001001) = Built-in Mic
kAudioFormatFlagIsFloat (1) + kAudioFormatFlagIsPacked (8)
```

**Solution:** Build universal converter supporting all formats:
```swift
func convertToFloat(data: UnsafeMutableRawPointer, isFloat: Bool, bitsPerChannel: UInt32) -> [Float]? {
    if isFloat {
        switch bitsPerChannel {
        case 32: return directCopy()  // Float32 → Float32
        case 64: return convertDouble()  // Float64 → Float32
        }
    } else if isSigned {
        switch bitsPerChannel {
        case 16: return normalizeInt16()  // Int16 → Float (-1.0 to 1.0)
        case 32: return normalizeInt32()  // Int32 → Float
        }
    }
}
```

**Key Insight:** Never assume audio format. Always detect and convert dynamically.

---

### 4. **Device Switching Requires State Reset**

**Discovery:** When user switches microphone mid-recording, cached buffers with old format + new buffers with new format = **speed/pitch artifacts**.

**Example:**
```
Recording starts: Headphone mic (16kHz Int16)
[10 seconds later]
User switches to: Built-in mic (44.1kHz Float32)
```

**What Happens:**
- Mixer has cached: Last headphone buffer (16kHz Int16)
- New buffer arrives: Built-in mic buffer (44.1kHz Float32)
- Mix them together → **Timing mismatch → Audio speeds up**

**Solution:**
```swift
// Track last mic format
private var lastMicFormat: AudioStreamBasicDescription?

func addMic(_ sampleBuffer: CMSampleBuffer) {
    let currentFormat = getFormat(sampleBuffer)

    // Detect device change
    if let last = lastMicFormat, formatsDoNotMatch(last, currentFormat) {
        print("🔄 Mic device changed - clearing cached buffer")
        lastMic = nil  // Clear stale buffer
        micConverter = nil  // Reset converter
    }

    lastMicFormat = currentFormat
    lastMic = sampleBuffer
}
```

**Key Insight:** Always clear cached buffers when input format changes.

---

### 5. **Interleaved vs Non-Interleaved Audio**

**Discovery:** Audio data can be stored in two fundamentally different layouts.

**Interleaved (Most Microphones):**
```
[L0, R0, L1, R1, L2, R2, L3, R3, ...]
     ↑   ↑
   Left Right samples alternate
```
- **Single buffer** containing alternating channel samples
- Common for: Mics, most audio files
- Flag: `kAudioFormatFlagIsNonInterleaved` is **NOT set**

**Non-Interleaved / Planar (System Audio):**
```
Buffer 0: [L0, L1, L2, L3, ...]  (Left channel)
Buffer 1: [R0, R1, R2, R3, ...]  (Right channel)
```
- **Separate buffers** for each channel
- Common for: Professional audio, system audio capture
- Flag: `kAudioFormatFlagIsNonInterleaved` **IS set**

**Conversion Example:**
```swift
// Non-interleaved → Interleaved
let leftChannel = audioBufferList[0]  // [L0, L1, L2, ...]
let rightChannel = audioBufferList[1]  // [R0, R1, R2, ...]

var interleaved = [Float](repeating: 0, count: frames * 2)
for frame in 0..<frames {
    interleaved[frame * 2] = leftChannel[frame]      // L
    interleaved[frame * 2 + 1] = rightChannel[frame] // R
}
```

**Key Insight:** Always check `isNonInterleaved` flag and handle both layouts.

---

### 6. **Sample Rate Conversion (Resampling)**

**Discovery:** Converting between sample rates requires interpolation, not just dropping/duplicating samples.

**Wrong Approach:**
```swift
// ❌ BAD: Naive upsampling (16kHz → 48kHz)
for sample in input {
    output.append(sample)
    output.append(sample)  // Duplicate
    output.append(sample)  // Duplicate
}
// Result: Robotic/choppy audio
```

**Better: Linear Interpolation**
```swift
let ratio = toRate / fromRate  // 48000 / 16000 = 3.0
for outFrame in 0..<outputFrames {
    let srcPos = Double(outFrame) / ratio  // 0.0, 0.333, 0.667, 1.0...
    let srcFrame = Int(srcPos)             // 0, 0, 0, 1...
    let frac = Float(srcPos - Double(srcFrame))  // 0.0, 0.333, 0.667, 0.0...

    let sample1 = input[srcFrame]
    let sample2 = input[srcFrame + 1]
    output[outFrame] = sample1 * (1.0 - frac) + sample2 * frac  // Interpolate
}
```

**Best: AVAudioConverter (Professional Quality)**
```swift
let inputFormat = AVAudioFormat(streamDescription: &inputASBD)
let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)
let converter = AVAudioConverter(from: inputFormat, to: outputFormat)

converter.convert(to: outputBuffer, error: &error) { _, outStatus in
    outStatus.pointee = .haveData
    return inputBuffer
}
```

**Quality Comparison:**
- **Naive duplication:** Choppy, robotic
- **Linear interpolation:** Acceptable, slight artifacts
- **AVAudioConverter:** Professional quality, minimal artifacts

**Key Insight:** Use `AVAudioConverter` for production, linear interpolation for prototypes.

---

### 7. **Audio Mixing Without Distortion**

**Discovery:** Simply adding samples can cause clipping when both sources are loud.

**Problem:**
```swift
// ❌ Can clip: -1.0 to +1.0 range
mixed = systemSample + micSample
// If both are 0.8, result is 1.6 → CLIPPING!
```

**Solutions:**

**Option 1: Averaging (Reduces volume)**
```swift
mixed = (systemSample + micSample) / 2.0
// Max: (1.0 + 1.0) / 2 = 1.0 ✅
// Con: Both sources at half volume
```

**Option 2: Soft Clipping (tanh)**
```swift
mixed = tanh(systemSample + micSample)
// tanh asymptotically approaches ±1.0
// Smooth saturation instead of hard clipping
```

**Option 3: Limiter/Compressor (Professional)**
```swift
let sum = systemSample + micSample
if abs(sum) > threshold {
    mixed = sign(sum) * (threshold + (abs(sum) - threshold) / compressionRatio)
} else {
    mixed = sum
}
```

**RMS Monitoring:**
```swift
var rms: Float = 0
for sample in samples {
    rms += sample * sample
}
rms = sqrt(rms / Float(samples.count))
// Typical speech: 0.01-0.1
// Loud music: 0.3-0.7
```

**Key Insight:** Use `tanh()` for simple soft clipping in mixing applications.

---

### 8. **Thread Safety in Audio Callbacks**

**Discovery:** ScreenCaptureKit audio callbacks run on `.global()` queue, video on different queue.

**Problem:**
```swift
// ❌ RACE CONDITION
func handleAudioBuffer(_ buffer: CMSampleBuffer) {
    lastMic = buffer  // Thread A writes
}

func handleSystemBuffer(_ buffer: CMSampleBuffer) {
    if let mic = lastMic {  // Thread B reads
        mix(system: buffer, mic: mic)
    }
}
// Crash or corruption possible
```

**Solution: Serial Queue**
```swift
private let mixerQueue = DispatchQueue(label: "com.app.audiomixer", qos: .userInitiated)

func addMic(_ buffer: CMSampleBuffer) {
    mixerQueue.async {  // Serialize all access
        self.lastMic = buffer
    }
}

func addSystem(_ buffer: CMSampleBuffer) {
    mixerQueue.async {  // Same queue
        if let mic = self.lastMic {
            self.mix(system: buffer, mic: mic)
        }
    }
}
```

**Key Insight:** Always serialize access to shared state in audio processing.

---

### 9. **CMBlockBuffer Memory Management**

**Discovery:** `CMBlockBufferAppendBufferReference` keeps **references**, not copies.

**Wrong Approach:**
```swift
func makeBuffer(from channels: [[Float]]) -> CMSampleBuffer? {
    var blockBuffers: [CMBlockBuffer] = []

    for channelData in channels {
        var blockBuffer: CMBlockBuffer?
        channelData.withUnsafeBytes { ptr in
            CMBlockBufferCreateWithMemoryBlock(..., memoryBlock: nil, ...)
        }
        blockBuffers.append(blockBuffer!)
    }  // ⚠️ channelData goes out of scope here!

    // Combine references
    var combined: CMBlockBuffer?
    for block in blockBuffers {
        CMBlockBufferAppendBufferReference(combined, targetBBuf: block, ...)
    }

    return createSampleBuffer(dataBuffer: combined)
    // ❌ BUG: Points to freed memory!
}
```

**Correct Approach:**
```swift
// Allocate contiguous memory that outlives the function
let totalBytes = channels.count * bytesPerChannel
let buffer = malloc(totalBytes)  // Heap allocation

// Copy data into contiguous buffer
for (i, channelData) in channels.enumerated() {
    memcpy(buffer.advanced(by: i * bytesPerChannel), channelData, bytesPerChannel)
}

// Create block buffer with ownership transfer
var blockBuffer: CMBlockBuffer?
CMBlockBufferCreateWithMemoryBlock(
    allocator: kCFAllocatorDefault,
    memoryBlock: buffer,  // Transfer ownership
    blockAllocator: kCFAllocatorDefault,  // Will call free() on cleanup
    ...
)
```

**Key Insight:** CMBlockBuffer must own the memory, not reference stack/temporary allocations.

---

### 10. **Mono to Stereo Conversion**

**Discovery:** Simply duplicating mono to both channels works but isn't ideal for quality.

**Simple Approach (Used in this project):**
```swift
func monoToStereo(_ monoSamples: [Float]) -> [Float] {
    var stereo = [Float](repeating: 0, count: monoSamples.count * 2)
    for i in 0..<monoSamples.count {
        let sample = monoSamples[i]
        stereo[i * 2] = sample      // Left = mono
        stereo[i * 2 + 1] = sample  // Right = mono
    }
    return stereo
}
```

**Better: Slight Stereo Spread (Optional Enhancement)**
```swift
// Add slight delay/EQ difference for "wider" sound
stereo[i * 2] = sample * 0.7 + previousSample * 0.3  // Left (with history)
stereo[i * 2 + 1] = sample  // Right (direct)
```

**Best: Use Microphone's Native Channel Count**
```swift
// If AVAudioConverter is used, it handles this automatically
let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)
converter.convert(...)  // Handles mono→stereo professionally
```

**Key Insight:** For voice, simple duplication is acceptable. For music, use professional tools.

---

## 🏗️ Architecture Decisions

### **Decision 1: Interleaved vs Non-Interleaved Output**

**Initial Approach:** Keep system audio's native non-interleaved format
- **Pro:** No conversion for system audio
- **Con:** Complex buffer management, planar layout harder to work with

**Final Approach:** Convert everything to interleaved Float32
- **Pro:** Simpler code, consistent format, easier debugging
- **Con:** Extra conversion step for system audio

**Verdict:** Simplicity wins. Performance impact negligible for 48kHz stereo.

---

### **Decision 2: When to Convert Microphone**

**Option A:** Convert mic immediately on arrival
```swift
func addMic(_ buffer: CMSampleBuffer) {
    let converted = convertToTargetFormat(buffer)
    lastMic = converted
}
```
- **Pro:** Conversion happens once
- **Con:** Waste if system buffer never arrives

**Option B:** Convert mic only when mixing (CHOSEN)
```swift
func mix(system: CMSampleBuffer, mic: CMSampleBuffer) {
    let convertedMic = convertToTargetFormat(mic)
    return mixBuffers(system, convertedMic)
}
```
- **Pro:** Only convert when actually needed
- **Con:** Redundant if mic used multiple times

**Option C:** Use AVAudioConverter with caching (BEST)
```swift
private var micConverter: AVAudioConverter?

func convertMic(_ buffer: CMSampleBuffer) {
    if micConverter == nil {
        micConverter = AVAudioConverter(from: micFormat, to: targetFormat)
    }
    return micConverter.convert(buffer)
}
```
- **Pro:** Professional quality + caching
- **Con:** Slightly more complex

**Verdict:** Use Option C (AVAudioConverter) for production quality.

---

### **Decision 3: Mic Buffer Consumption Strategy**

**Current Approach:**
```swift
func mix(system: CMSampleBuffer, mic: CMSampleBuffer) {
    let mixed = performMixing(system, mic)
    lastMic = nil  // Consume after each use
    return mixed
}
```

**Limitation:** If system buffers arrive faster than mic, mic audio gets skipped.

**Alternative (Not Implemented):**
```swift
private var micQueue: [CMSampleBuffer] = []

func addMic(_ buffer: CMSampleBuffer) {
    micQueue.append(buffer)
}

func mix(system: CMSampleBuffer) {
    // Find mic buffer closest to system timestamp
    guard let matchingMic = findClosestMicBuffer(to: system) else { return system }
    return performMixing(system, matchingMic)
}
```

**Trade-off:** Current approach is simpler, works for typical use cases.

---

## 🐛 Common Pitfalls & Solutions

### Pitfall 1: **Assuming Float32 for All Audio**
```swift
// ❌ CRASH with Int16 microphones
let samples = data.assumingMemoryBound(to: Float.self)
```
**Fix:** Always check format flags first.

### Pitfall 2: **Ignoring AudioBufferList Buffer Count**
```swift
// ❌ Assumes always 2 buffers
let left = audioBufferList[0]
let right = audioBufferList[1]  // CRASH if mono!
```
**Fix:** Use `audioBufferList.count` dynamically.

### Pitfall 3: **Mixing Buffers with Different Lengths**
```swift
// ❌ CRASH if sizes differ
for i in 0..<systemSamples.count {
    mixed[i] = systemSamples[i] + micSamples[i]  // Crash if mic shorter!
}
```
**Fix:** Use `min(systemSamples.count, micSamples.count)`.

### Pitfall 4: **Not Handling NaN in RMS Calculations**
```swift
// ❌ Propagates NaN through calculations
let rms = sqrt(sum / Float(count))
if rms > threshold { ... }  // Comparison fails if NaN
```
**Fix:** Check `rms.isNaN` before using.

### Pitfall 5: **Forgetting to Update Frame Count After Resampling**
```swift
// ❌ Wrong frame count for sample buffer
let resampled = resample(samples, from: 16000, to: 48000)
let frameCount = samples.count / channels  // Wrong! Should use resampled.count
```

---

## 📊 Performance Considerations

### Measured Overhead (macOS 15, M1 Mac)

| Operation | Time | Impact |
|-----------|------|--------|
| Extract non-interleaved → interleaved | ~0.1ms | Negligible |
| Resample 16kHz→48kHz (linear) | ~0.3ms | Low |
| AVAudioConverter resampling | ~0.5ms | Medium |
| Mixing (tanh) | ~0.05ms | Negligible |
| Create CMSampleBuffer | ~0.1ms | Negligible |
| **Total per audio buffer** | **~1.0ms** | **Acceptable** |

**Budget:** Audio buffers arrive every ~20ms, so 1ms overhead = 5% CPU for audio mixing.

---

## 🎯 Quality Issues Encountered

### Issue: "Voice Recording Quality Not Good"

**Possible Causes:**

1. **Linear Interpolation Artifacts**
   - Current resampler uses linear interpolation
   - Can cause slight "robotic" quality
   - **Fix:** Use `AVAudioConverter` exclusively

2. **Soft Clipping Distortion**
   - `tanh()` can reduce dynamic range
   - **Fix:** Use simple addition if levels are controlled:
     ```swift
     mixed = systemSample * 0.7 + micSample * 0.3  // Weighted mix
     ```

3. **Sample Rate Mismatch**
   - Built-in mic: 44.1kHz → 48kHz conversion
   - Some quality loss in conversion
   - **Fix:** Accept trade-off or record at native 44.1kHz

4. **Microphone Gain Too Low**
   - RMS: 0.0012 is very quiet
   - **Fix:** Add gain boost:
     ```swift
     let micGain: Float = 3.0  // Boost microphone
     mixed = systemSample + (micSample * micGain)
     ```

5. **Noise Floor**
   - Built-in Mac mic has higher noise floor than external mics
   - **Fix:** Apply noise gate (cut samples below threshold)

---

## ✅ Best Practices Summary

1. **Always Lock Format Upfront**
   - Create stable output format before any audio forwarding
   - Convert all buffers to match this format

2. **Validate Format Before Conversion**
   - Check `mFormatFlags` for Float vs Int
   - Check `mBitsPerChannel` for bit depth
   - Check `isNonInterleaved` flag

3. **Use AVAudioConverter for Production**
   - Better quality than manual resampling
   - Handles edge cases automatically
   - Cache converters for performance

4. **Detect Device Changes**
   - Track last format received
   - Clear cached buffers on format change
   - Reset converters

5. **Serialize Audio Processing**
   - Use dedicated serial DispatchQueue
   - Prevent race conditions on shared state

6. **Monitor Audio Levels**
   - Calculate RMS for debugging
   - Detect silent/corrupt streams early
   - Check for NaN values

7. **Own Your Memory**
   - Don't reference stack allocations in CMBlockBuffer
   - Use heap memory with proper ownership transfer

8. **Test With Real Devices**
   - Different mics have different formats
   - Test device switching mid-recording
   - Verify long recordings (30+ minutes)

---

## 🔧 Tools for Debugging

### 1. **Audio Format Inspector**
```swift
func debugFormat(_ buffer: CMSampleBuffer) {
    guard let desc = CMSampleBufferGetFormatDescription(buffer),
          let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee else {
        return
    }

    let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
    let isSigned = (asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0
    let isNonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0

    print("""
    Format: \(isFloat ? "Float\(asbd.mBitsPerChannel)" : "Int\(asbd.mBitsPerChannel)")
    Rate: \(asbd.mSampleRate) Hz
    Channels: \(asbd.mChannelsPerFrame)
    Interleaved: \(isNonInterleaved ? "No (planar)" : "Yes")
    Flags: \(asbd.mFormatFlags)
    """)
}
```

### 2. **RMS Monitor**
```swift
func calculateRMS(_ samples: [Float]) -> Float {
    guard !samples.isEmpty else { return 0 }
    let sumSquares = samples.reduce(0) { $0 + $1 * $1 }
    return sqrt(sumSquares / Float(samples.count))
}
```

### 3. **Buffer Timing Inspector**
```swift
func debugTiming(_ buffer: CMSampleBuffer, label: String) {
    let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
    let duration = CMSampleBufferGetDuration(buffer)
    print("\(label) - PTS: \(pts.seconds)s Duration: \(duration.seconds)s")
}
```

---

## 📚 References

**Apple Documentation:**
- [Audio Format Services](https://developer.apple.com/documentation/coreaudio/audio_format_services)
- [AVAudioConverter](https://developer.apple.com/documentation/avfaudio/avaudioconverter)
- [CMSampleBuffer](https://developer.apple.com/documentation/coremedia/cmsamplebuffer-u71)
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)

**Key Concepts:**
- LPCM (Linear Pulse Code Modulation)
- Interleaved vs Non-interleaved audio
- Sample rate conversion (resampling)
- Audio format flags (ASBD)

---

## 🎓 Lessons Learned

1. **Audio is harder than video** - Format mismatches cause subtle, hard-to-debug issues
2. **Device diversity is real** - Never assume all mics use same format
3. **Quality matters** - Linear interpolation works but AVAudioConverter is better
4. **Simplicity wins** - Interleaved format easier to work with than planar
5. **Log everything** - Audio bugs are invisible without extensive logging
6. **Thread safety is critical** - Race conditions cause unpredictable corruption
7. **Test real hardware** - Simulators can't test audio device variations
8. **Accept trade-offs** - Perfect quality vs shipping a working product

---

**Document Version:** 1.0
**Last Updated:** November 23, 2025
**Status:** Production learnings from MyRec audio mixing implementation
