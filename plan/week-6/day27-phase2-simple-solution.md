# Day 27 Phase 2: Simple Audio Mixing Solution

**Created:** November 22, 2025
**Approach:** macOS 15+ dual-output capture + lightweight in-app mix
**Status:** Ready for Implementation (30 minutes)

---

## Executive Summary

On macOS 15+, ScreenCaptureKit exposes **two audio outputs**: `.audio` (system) and `.microphone` (mic). It does **not** auto-mix them; you must request both outputs and combine them. This “simple” path keeps code minimal: capture both outputs, up-mix mic to stereo, sum samples if formats already match (48kHz Float32 stereo), and forward the mixed buffer to the writer.

## Implementation Steps

### 1. Update SCStreamConfiguration

**File:** `MyRec/Services/Recording/ScreenCaptureEngine.swift`

Enable system audio on the stream configuration (macOS 15+); the mic is requested via the output type, not config:

```swift
private func setupStream(resolution: Resolution, frameRate: FrameRate) async throws {
    var config = SCStreamConfiguration()
    config.width = display.width
    config.height = display.height
    config.minimumFrameInterval = CMTime(value: 1, timescale: frameRate.toTimescale())
    config.capturesAudio = true                // system audio
    config.excludesCurrentProcessAudio = true  // avoid feedback from our own app
    config.queueDepth = 5
    // ... rest of config
}
```

When creating the stream, add both outputs:

```swift
let stream = SCStream(filter: filter, configuration: config, delegate: self)
try stream.addStreamOutput(self, type: .audio)        // system
try stream.addStreamOutput(self, type: .microphone)   // mic (15+ only)
```

### 2. Update Audio Toggles Logic

**File:** `MyRec/Views/Settings/SettingsBarView.swift`

Remove the mutually exclusive logic - allow both to be enabled:

```swift
// System audio toggle
ToggleIconButton(
    icon: "speaker.wave.2.fill",
    isOn: $settingsManager.defaultSettings.audioEnabled,
    help: "System Sound",
    isDisabled: isRecording,
    onIcon: "speaker.wave.2.fill",
    offIcon: "speaker.slash.fill"
)
// REMOVE the .onChange that makes them mutually exclusive

// Microphone toggle
ToggleIconButton(
    icon: "mic.fill",
    isOn: $settingsManager.defaultSettings.microphoneEnabled,
    help: "Microphone",
    isDisabled: isRecording,
    onIcon: "mic.fill",
    offIcon: "mic.slash.fill"
)
// REMOVE the .onChange that makes them mutually exclusive
```

### 3. Update Capture Logic

**File:** `MyRec/Services/Recording/ScreenCaptureEngine.swift`

Ensure macOS 15+ gating and wire both outputs:

```swift
public func startCapture(
    region: CGRect,
    resolution: Resolution,
    frameRate: FrameRate,
    withAudio: Bool = true,
    withMicrophone: Bool = true    // default on for 15+
) async throws {
    self.captureAudio = withAudio
    self.captureMicrophone = withMicrophone

    guard #available(macOS 15, *) else {
        throw CaptureError.unsupportedOSVersion
    }

    try await setupStream(resolution: resolution, frameRate: frameRate)
}
```

### 4. Handle Stream Output

Mix lightly when formats match (SC defaults to 48kHz Float32 stereo). Up-mix mic mono to L/R and sum to system samples; otherwise, fall back to the dominant source.

```swift
func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
    switch type {
    case .audio:
        mixer.addSystem(sb)
    case .microphone:
        mixer.addMic(sb)
    default:
        break
    }
}

final class SimpleMixer {
    private var lastMic: CMSampleBuffer?

    func addSystem(_ sb: CMSampleBuffer) {
        guard let mic = lastMic else { forward(sb); return }
        if let mixed = mix(system: sb, mic: mic) { forward(mixed) } else { forward(sb) }
    }

    func addMic(_ sb: CMSampleBuffer) { lastMic = sb }

    private func mix(system: CMSampleBuffer, mic: CMSampleBuffer) -> CMSampleBuffer? {
        guard formatsMatch(system, mic),
              let sys = pcmFloatData(system),
              let mic = pcmFloatData(mic) else { return nil }

        let count = min(sys.count, mic.count)
        var mixed = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let sysL = sys[i]
            let micL = mic[i]
            mixed[i] = tanh(sysL + micL) // soft clip
        }

        return makeBuffer(from: mixed, like: system)
    }

    // TODO: implement formatsMatch, pcmFloatData, makeBuffer
    private func forward(_ sb: CMSampleBuffer) { /* append to encoder */ }
}
```

## Benefits of This Approach

- ✅ Minimal surface change: request both outputs, small mixer
- ✅ Native A/V timestamps from ScreenCaptureKit
- ✅ Works on macOS 15+ without extra frameworks
- ⚠️ Light mixing only when formats match; else falls back to system-only audio

## Important Notes

1. **macOS 15+ Required**: Mic capture via `.microphone` output exists only on 15+
2. **Format Guard**: Simple mix assumes matching 48kHz Float32 stereo; otherwise, skip mixing or add `AVAudioConverter`
3. **No Volume Control/AEC**: No per-source volume or built-in echo cancellation; recommend headphones
4. **Single Output to Writer**: Mixer produces one audio buffer to feed the writer

## Testing

1. Enable both system audio and microphone
2. Record 30 seconds
3. Verify both sources are audible in the output
4. Test with headphones to prevent echo

## Summary

This simple approach leverages ScreenCaptureKit's built-in capabilities, requiring minimal code changes and providing reliable audio mixing with proper synchronization.
