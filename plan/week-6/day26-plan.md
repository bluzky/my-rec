# Day 26 - Microphone Input

**Date:** November 22, 2025
**Goal:** Implement microphone capture using AVAudioEngine
**Status:** ⏳ Pending

---

## Overview

Today we'll add microphone input capture, allowing users to record voice commentary alongside screen and system audio. This is essential for tutorials, presentations, and narrated recordings.

**Current State:**
- ✅ Video capture working
- ✅ System audio capture working (Day 25)
- ❌ No microphone input

**Target State:**
- ✅ Microphone audio captured
- ✅ Mic level monitoring
- ✅ Mic selection from available devices
- ✅ Mic toggle in UI
- ✅ Mic audio mixed with system audio

---

## Technical Approach

### 1. AVAudioEngine for Microphone

```swift
// Setup audio engine
let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode

// Configure format
let format = inputNode.outputFormat(forBus: 0)

// Install tap
inputNode.installTap(
    onBus: 0,
    bufferSize: 1024,
    format: format
) { buffer, time in
    // Process PCM audio buffer
    self.processMicrophoneBuffer(buffer, at: time)
}

// Start engine
try audioEngine.start()
```

### 2. Audio Flow

```
Microphone Hardware
    ↓
AVAudioEngine.inputNode
    ↓
PCM Audio Buffer
    ↓
MicrophoneCaptureEngine
    ↓
AVAssetWriterInput (AAC)
    ↓
MP4 File (mixed audio track)
```

---

## Implementation Tasks

### Task 1: Create MicrophoneCaptureEngine (90 min)

**File:** `Sources/MyRec/Services/MicrophoneCaptureEngine.swift` (new)

**Purpose:** Manage microphone input and processing

```swift
import AVFoundation
import CoreAudio

@MainActor
class MicrophoneCaptureEngine: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isCapturing = false
    @Published var micLevel: Float = 0.0  // 0.0 to 1.0
    @Published var availableDevices: [AudioDevice] = []
    @Published var selectedDevice: AudioDevice?

    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var assetWriterInput: AVAssetWriterInput?
    private let audioQueue = DispatchQueue(label: "com.myrec.microphone")

    private var audioFormat: AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 2,
            interleaved: false
        )!
    }

    // MARK: - Initialization
    override init() {
        super.init()
        enumerateAudioDevices()
    }

    // MARK: - Public Methods
    func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    func setupAudioInput(for assetWriter: AVAssetWriter) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]

        let input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: settings
        )

        input.expectsMediaDataInRealTime = true

        guard assetWriter.canAdd(input) else {
            throw MicrophoneError.cannotAddInput
        }

        assetWriter.add(input)
        self.assetWriterInput = input
    }

    func startCapturing() throws {
        // Create audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine!.inputNode

        // Set input device if selected
        if let device = selectedDevice {
            try setInputDevice(device)
        }

        // Get input format
        let inputFormat = inputNode!.outputFormat(forBus: 0)

        // Install tap
        inputNode!.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: inputFormat
        ) { [weak self] buffer, time in
            self?.processMicBuffer(buffer, at: time)
        }

        // Start engine
        try audioEngine!.start()
        isCapturing = true
    }

    func stopCapturing() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        assetWriterInput?.markAsFinished()
        isCapturing = false
    }

    // MARK: - Private Methods
    private func processMicBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        // Update mic level
        updateMicLevel(from: buffer)

        // Convert to CMSampleBuffer
        guard let sampleBuffer = convertToCMSampleBuffer(buffer, at: time) else {
            return
        }

        // Write to asset writer
        guard let input = assetWriterInput,
              input.isReadyForMoreMediaData else {
            return
        }

        audioQueue.async {
            input.append(sampleBuffer)
        }
    }

    private func updateMicLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(
            from: 0,
            to: Int(buffer.frameLength),
            by: buffer.stride
        ).map { channelDataValue[$0] }

        let rms = sqrt(
            channelDataValueArray.reduce(0) { $0 + $1 * $1 } / Float(buffer.frameLength)
        )

        DispatchQueue.main.async {
            self.micLevel = min(rms * 10, 1.0)  // Scale and clamp
        }
    }

    private func convertToCMSampleBuffer(
        _ buffer: AVAudioPCMBuffer,
        at time: AVAudioTime
    ) -> CMSampleBuffer? {

        guard let formatDescription = buffer.format.formatDescription else {
            return nil
        }

        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(
                value: CMTimeValue(buffer.frameLength),
                timescale: CMTimeScale(buffer.format.sampleRate)
            ),
            presentationTimeStamp: CMTime(
                seconds: time.sampleTime / buffer.format.sampleRate,
                preferredTimescale: CMTimeScale(buffer.format.sampleRate)
            ),
            decodeTimeStamp: .invalid
        )

        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: CMItemCount(buffer.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }

    private func enumerateAudioDevices() {
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )

        // Filter for input devices
        let devices = deviceIDs.compactMap { deviceID -> AudioDevice? in
            guard hasInputChannels(deviceID) else { return nil }
            return AudioDevice(id: deviceID)
        }

        DispatchQueue.main.async {
            self.availableDevices = devices
            self.selectedDevice = devices.first
        }
    }

    private func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: 0
        )

        var propertySize: UInt32 = 0
        AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        )

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>
            .allocate(capacity: Int(propertySize))
        defer { bufferListPointer.deallocate() }

        AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            bufferListPointer
        )

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }

    private func setInputDevice(_ device: AudioDevice) throws {
        // Set preferred input device
        // Implementation depends on device selection approach
    }
}

// MARK: - Audio Device Model
struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    var name: String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var propertySize = UInt32(MemoryLayout<CFString>.size)

        AudioObjectGetPropertyData(
            id,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceName
        )

        return deviceName as String
    }
}

// MARK: - Errors
enum MicrophoneError: Error {
    case permissionDenied
    case cannotAddInput
    case deviceNotAvailable
    case captureFailed
}
```

---

### Task 2: Update RecordingManager for Mic (45 min)

**File:** `Sources/MyRec/Managers/RecordingManager.swift`

**Changes:**
1. Add microphone capture engine
2. Coordinate system audio + mic
3. Handle permissions

```swift
class RecordingManager: ObservableObject {
    @Published var microphoneCaptureEngine: MicrophoneCaptureEngine?

    func startRecording(
        settings: RecordingSettings,
        captureMode: CaptureMode
    ) async throws {

        // Request mic permission if needed
        if settings.microphoneEnabled {
            let micEngine = MicrophoneCaptureEngine()

            guard await micEngine.requestPermission() else {
                throw RecordingError.microphonePermissionDenied
            }

            self.microphoneCaptureEngine = micEngine
        }

        // Start video and system audio (existing)
        try await screenCaptureEngine.startCapture(/*...*/)

        // Start microphone if enabled
        if settings.microphoneEnabled {
            try microphoneCaptureEngine?.startCapturing()
        }

        state = .recording
    }

    func stopRecording() async throws {
        // Stop microphone
        microphoneCaptureEngine?.stopCapturing()

        // Stop video and system audio (existing)
        // ...
    }
}
```

---

### Task 3: Add Mic Toggle to Settings (30 min)

**File:** `Sources/MyRec/Models/RecordingSettings.swift`

**Changes:**
```swift
struct RecordingSettings: Codable {
    // ... existing properties ...
    var microphoneEnabled: Bool = false
    var microphoneDeviceID: AudioDeviceID?

    enum CodingKeys: String, CodingKey {
        // ... existing cases ...
        case microphoneEnabled
        case microphoneDeviceID
    }
}
```

**File:** `Sources/MyRec/UI/RegionSelectionWindow.swift`

```swift
var settingsBar: some View {
    HStack {
        // ... existing controls ...

        Toggle(isOn: $settings.microphoneEnabled) {
            Image(systemName: "mic.fill")
        }
        .toggleStyle(.button)
        .help("Microphone: \(settings.microphoneEnabled ? "On" : "Off")")

        if recordingManager.isRecording && settings.microphoneEnabled {
            AudioLevelIndicator(
                audioEngine: recordingManager.microphoneCaptureEngine,
                label: "Mic"
            )
            .frame(width: 120)
        }
    }
}
```

---

### Task 4: Microphone Device Picker (60 min)

**File:** `Sources/MyRec/UI/MicrophoneSettingsView.swift` (new)

**Purpose:** Allow users to select input device

```swift
import SwiftUI

struct MicrophoneSettingsView: View {
    @ObservedObject var micEngine: MicrophoneCaptureEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Microphone Settings")
                .font(.headline)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Select Input Device:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(micEngine.availableDevices) { device in
                    HStack {
                        Image(systemName: device == micEngine.selectedDevice
                              ? "checkmark.circle.fill"
                              : "circle")
                            .foregroundColor(.accentColor)

                        Text(device.name)

                        Spacer()

                        if device == micEngine.selectedDevice {
                            // Show level indicator for selected device
                            Circle()
                                .fill(micEngine.micLevel > 0.01 ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        micEngine.selectedDevice = device
                    }
                }
            }

            Divider()

            HStack {
                Text("Test your microphone by speaking")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 350, height: 300)
    }
}
```

---

### Task 5: Permission Handling (30 min)

**File:** `Sources/MyRec/Services/PermissionManager.swift`

**Update:**
```swift
@MainActor
class PermissionManager: ObservableObject {
    // ... existing screen recording permission ...

    @Published var microphonePermission: PermissionStatus = .notDetermined

    func checkMicrophonePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        await MainActor.run {
            switch status {
            case .authorized:
                microphonePermission = .granted
            case .notDetermined:
                microphonePermission = .notDetermined
            case .denied, .restricted:
                microphonePermission = .denied
            @unknown default:
                microphonePermission = .denied
            }
        }
    }

    func requestMicrophonePermission() async -> Bool {
        await checkMicrophonePermission()

        if microphonePermission == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            await checkMicrophonePermission()
            return granted
        }

        return microphonePermission == .granted
    }
}
```

---

## Testing Plan

### Unit Tests (45 min)

**File:** `Tests/MyRecTests/MicrophoneCaptureEngineTests.swift` (new)

```swift
import XCTest
@testable import MyRec

final class MicrophoneCaptureEngineTests: XCTestCase {
    func testMicrophoneEngineInitialization() {
        let engine = MicrophoneCaptureEngine()
        XCTAssertFalse(engine.isCapturing)
        XCTAssertEqual(engine.micLevel, 0.0)
        XCTAssertFalse(engine.availableDevices.isEmpty)
    }

    func testDeviceEnumeration() {
        let engine = MicrophoneCaptureEngine()
        XCTAssertNotNil(engine.selectedDevice)
        XCTAssertTrue(engine.availableDevices.count > 0)
    }

    func testPermissionRequest() async {
        let engine = MicrophoneCaptureEngine()
        let granted = await engine.requestPermission()
        // Result depends on system settings
        XCTAssertNotNil(granted)
    }
}
```

---

### Manual Testing (75 min)

**Test Scenarios:**

1. **Basic microphone capture:**
   - [ ] Enable microphone toggle
   - [ ] Start recording
   - [ ] Speak into microphone
   - [ ] Verify mic level indicator responds
   - [ ] Playback - voice is audible

2. **Device selection:**
   - [ ] Open mic settings
   - [ ] See list of input devices
   - [ ] Select different device
   - [ ] Verify correct device is used
   - [ ] Test with USB mic

3. **Combined audio:**
   - [ ] Enable system audio + microphone
   - [ ] Play music (system)
   - [ ] Speak (microphone)
   - [ ] Verify both sources in playback
   - [ ] Check levels don't clip

4. **Permission handling:**
   - [ ] Reset microphone permissions
   - [ ] Enable mic in app
   - [ ] Verify permission prompt appears
   - [ ] Grant permission
   - [ ] Verify capture works

5. **Edge cases:**
   - [ ] Unplug microphone during recording
   - [ ] Very loud input (shouting)
   - [ ] Very quiet input (whisper)
   - [ ] Background noise

**Verification Checklist:**
- [ ] Microphone audio captured
- [ ] Device selection working
- [ ] Permission flow correct
- [ ] Level indicator accurate
- [ ] Audio quality good
- [ ] No distortion or clipping

---

## Expected Outcomes

### Functional Outcomes
✅ Microphone capture working
✅ Device selection functional
✅ Mic level monitoring
✅ Permission handling correct

### Technical Outcomes
✅ MicrophoneCaptureEngine created
✅ AVAudioEngine integration
✅ Device enumeration working
✅ Permission flow implemented

### Quality Metrics
- Zero build errors/warnings
- All tests pass
- Audio quality: clear, no artifacts
- Mic level indicator responsive

---

## Time Breakdown

| Task | Estimated | Actual |
|------|-----------|--------|
| MicrophoneCaptureEngine | 90 min | - |
| RecordingManager update | 45 min | - |
| Settings toggle | 30 min | - |
| Device picker UI | 60 min | - |
| Permission handling | 30 min | - |
| Testing | 120 min | - |
| **Total** | **~6.25 hours** | - |

---

## Dependencies

### Required
- ✅ Day 25 system audio complete
- ✅ AudioCaptureEngine
- ✅ RecordingManager

---

## Results (End of Day)

**Status:** Not started

**Completed:**
- [ ] MicrophoneCaptureEngine created
- [ ] Microphone capture working
- [ ] Device selection functional
- [ ] Permission handling implemented
- [ ] Tests passing

**Next Day:** Audio mixing and synchronization

---

**Last Updated:** November 19, 2025
