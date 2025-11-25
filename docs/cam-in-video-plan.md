# ScreenCaptureKit Camera Overlay Integration Plan
**Project:** MyRec - macOS Screen Recording Application  
**Target Platform:** macOS 15.6+  
**Date:** 2024-11-24  
**Version:** 1.0  
---
## Table of Contents
1. [Executive Summary](#executive-summary)  
2. [Current State Analysis](#current-state-analysis)  
3. [Expected Architecture](#expected-architecture)  
4. [Technical Specifications](#technical-specifications)  
5. [API Design](#api-design)  
6. [Performance Expectations](#performance-expectations)  
7. [Trade-offs & Limitations](#trade-offs--limitations)  
---
## Executive Summary
### The Problem
- Current implementation lacks camera overlay support.  
- Native Presenter Overlay (macOS 14+) allows camera integration but positions it via system picker—**no programmatic or user-draggable control during recording**.  
- Manual composition is required for draggable overlays, adding complexity and partially reverting the SCRecordingOutput migration.  

### The Solution
- Integrate **AVCaptureSession** for camera capture.  
- Use **SCStreamOutput** to process screen samples (instead of direct SCRecordingOutput).  
- Composite camera feed onto screen buffers in real-time using **Core Image** or **Metal** for efficiency.  
- Allow user-draggable positioning via a custom **NSView** overlay in the app's UI.  
- Encode composited frames with **AVAssetWriter** for output (drops native SCRecordingOutput).  
- **Expected code addition:** +500-600 lines (total engine ~900-1,000 lines, up from 400).  
- **Expected CPU increase:** +5-10% due to composition.  

### Key Benefits
| Benefit | Impact |
|---------|--------|
| **Customizable Overlay** | User can drag/resize camera bubble during preview/recording |
| **Flexible Positioning** | Programmatic control over position, size, and style |
| **Seamless Integration** | Maintains most of the simplified lifecycle |
| **High-Quality Output** | Hardware-accelerated composition preserves quality |
| **User Experience** | Intuitive drag-to-position like modern video apps |

### Breaking Changes
| Change | Before | After |
|--------|--------|-------|
| **Encoding Pipeline** | Native SCRecordingOutput | Manual AVAssetWriter |
| **Sample Processing** | None | SCStreamOutput + composition |
| **Code Size** | ~400 lines | ~900-1,000 lines |
| **CPU Usage** | 11-16% | 16-26% |
| **macOS Requirement** | 15.0+ | **15.0+** (no change) |
---
## Current State Analysis
### Architecture Overview
Current simplified setup (post-migration):  
- SCStream + SCRecordingOutput for direct-to-file recording.  
- No sample buffer processing.  
- No camera integration.  

**Key Issues for Overlay:**  
- SCRecordingOutput doesn't expose samples for custom composition.  
- Native Presenter Overlay (via SCContentSharingPicker) is non-customizable: Fixed styles (bubble/large), no drag during recording, user must select via system picker.  
- No built-in API for draggable camera positions in ScreenCaptureKit.  

### What Works Well ✅
1. Simplified recording lifecycle.  
2. Native audio mixing and encoding.  
3. Low CPU/memory footprint.  

### What Needs Improvement ❌
1. No camera support.  
2. If using native overlay: No drag control.  
3. Reverting to manual processing increases complexity.  
---
## Expected Architecture
### New Architecture Overview
```
┌─────────────────────────────────────────────────────────────────┐
│ AppDelegate / UI Layer                                           │
│ - Manages draggable NSView for camera preview/positioning       │
│ - Passes position/size to ScreenCaptureEngine                   │
│ - Handles recording lifecycle callbacks                         │
└────────────────────────┬────────────────────────────────────────┘
                         │ (Position/Size Updates)
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ ScreenCaptureEngine (~900-1,000 lines)                           │
│ - SCStreamDelegate                                              │
│ - SCStreamOutput (for screen samples)                           │
│ - AVCaptureVideoDataOutputDelegate (for camera samples)         │
│ - ObservableObject (state)                                      │
│                                                                 │
│ ┌────────────────────────────────────────────────────────────┐  │
│ │ SCStream                                                    │  │
│ │ - Captures screen frames/audio                              │  │
│ └──────────────┬─────────────────────────────────────────────┘  │
│                │ (Screen Samples)                               │
│                ▼                                                │
│ ┌────────────────────────────────────────────────────────────┐  │
│ │ AVCaptureSession                                           │  │
│ │ - Captures camera frames                                    │  │
│ └──────────────┬─────────────────────────────────────────────┘  │
│                │ (Camera Samples)                               │
│                ▼                                                │
│ ┌────────────────────────────────────────────────────────────┐  │
│ │ Composition Pipeline                                       │  │
│ │ - Sync screen + camera buffers                              │  │
│ │ - Composite using CIImage/Metal                             │  │
│ │ - Apply user-dragged position/size                          │  │
│ └──────────────┬─────────────────────────────────────────────┘  │
│                │ (Composited Frames)                            │
│                ▼                                                │
│ ┌────────────────────────────────────────────────────────────┐  │
│ │ AVAssetWriter                                              │  │
│ │ - Encodes to MP4 (H.264/HEVC + AAC)                         │  │
│ │ - Handles A/V sync                                          │  │
│ └──────────────┬─────────────────────────────────────────────┘  │
└────────────────┼────────────────────────────────────────────────┘
                 │
                 ▼
        ┌─────────────────────┐
        │ Final MP4 File      │
        └─────────────────────┘
```
### Architecture Comparison
| Layer | Current | Expected | Change |
|-------|---------|----------|--------|
| **ScreenCaptureEngine** | ~400 lines | ~900-1,000 lines | +125% |
| **Sample Processing** | None | SCStreamOutput + composition | Added |
| **Camera Capture** | None | AVCaptureSession | Added |
| **Encoding** | SCRecordingOutput | AVAssetWriter | Manual |
| **Audio** | Native mixing | Native (via SCStream) + manual append | Minor addition |
| **Total Code** | ~400 lines | ~900-1,000 lines | +125% |
---
## Technical Specifications
### Prerequisites
- Add **AVFoundation** import: `@import AVFoundation;`.  
- Add **Camera** permission: `NSCameraUsageDescription` in Info.plist.  
- Request access: `AVCaptureDevice.requestAccess(for: .video)`.  
- For composition, use **Core Image** (simple) or **Metal** (high-perf). Recommend Core Image for starters.  

### Camera Session Setup
In `ScreenCaptureEngine`:  
```swift
private var cameraSession: AVCaptureSession?
private var cameraOutput: AVCaptureVideoDataOutput?
private var cameraQueue: DispatchQueue = DispatchQueue(label: "cameraQueue")
private var latestCameraBuffer: CMSampleBuffer? // For syncing

func setupCamera() throws {
    guard let camera = AVCaptureDevice.default(for: .video) else { throw CaptureError.noCamera }
    cameraSession = AVCaptureSession()
    let input = try AVCaptureDeviceInput(device: camera)
    cameraSession?.addInput(input)
    
    cameraOutput = AVCaptureVideoDataOutput()
    cameraOutput?.setSampleBufferDelegate(self, queue: cameraQueue)
    cameraSession?.addOutput(cameraOutput!)
    
    cameraSession?.startRunning()
}
```

### Draggable UI Integration
In AppDelegate/UI: Create a draggable `NSView` for camera preview.  
```swift
class DraggableCameraView: NSView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    // Add drag gestures (NSPanGestureRecognizer)
    @objc func handleDrag(_ gesture: NSPanGestureRecognizer) {
        // Update position, notify engine
        engine.updateOverlayPosition(newPosition: frame.origin)
    }
}
```
// Pass position to engine (e.g., `@Published var overlayRect: CGRect = .zero`).

### Composition in SCStreamOutput
Implement `SCStreamOutput` to composite:  
```swift
func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .screen else { return } // Handle audio separately if needed
    
    guard let screenImage = CMSampleBufferGetImageBuffer(sampleBuffer),
          let cameraBuffer = latestCameraBuffer,
          let cameraImage = CMSampleBufferGetImageBuffer(cameraBuffer) else { return }
    
    // Composite using Core Image
    let ciScreen = CIImage(cvPixelBuffer: screenImage)
    let ciCamera = CIImage(cvPixelBuffer: cameraImage)
        .transformed(by: CGAffineTransform(scaleX: overlayRect.width / ciCamera.extent.width,
                                           y: overlayRect.height / ciCamera.extent.height))
        .transformed(by: CGAffineTransform(translationX: overlayRect.origin.x, y: overlayRect.origin.y))
    
    let context = CIContext()
    let composited = ciCamera.composited(over: ciScreen)
    context.render(composited, to: screenImage) // Overwrite screen buffer
    
    // Append to AVAssetWriter
    videoWriterInput?.append(sampleBuffer)
}
```

### AVCapture Delegate for Camera Buffers
```swift
extension ScreenCaptureEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        latestCameraBuffer = sampleBuffer // Use in composition
    }
}
```

### Update startCapture
- Call `setupCamera()` before starting stream.  
- Add `try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)`.  
- Setup AVAssetWriter for output (similar to old VideoEncoder).  

### Sync Considerations
- Use timestamps to sync screen/camera buffers (drop if desynced > threshold).  
- Handle resolution/orientation matching.  
---
## API Design
### Updated ScreenCaptureEngine API
#### Properties
```swift
@Published var overlayRect: CGRect = CGRect(x: 20, y: 20, width: 200, height: 150) // Default position/size
private var assetWriter: AVAssetWriter?
private var videoWriterInput: AVAssetWriterInput?
// ... existing properties ...
```

#### Methods
```swift
func updateOverlayPosition(_ rect: CGRect) {
    overlayRect = rect // Dynamic updates during recording
}

func startCapture(..., enableCamera: Bool = false) async throws {
    if enableCamera { try setupCamera() }
    // ... create stream, add SCStreamOutput, setup AVAssetWriter ...
}
```
#### Usage Example
```swift
engine.updateOverlayPosition(draggedRect) // From UI drag handler
try await engine.startCapture(..., enableCamera: true)
```
---
## Performance Expectations
### CPU Usage
| Scenario | Current | Expected | Change |
|----------|---------|----------|--------|
| **1080p @ 30fps (no camera)** | 11-16% | 11-16% | None |
| **1080p @ 30fps (with camera)** | N/A | 16-26% | +5-10% |
**Breakdown:** Composition adds overhead; use Metal for optimization (<5% increase).  

### Memory Usage
| Component | Current | Expected | Change |
|-----------|---------|----------|--------|
| **Total** | 110-160 MB | 140-220 MB | +30% |
**Breakdown:** Extra buffers for camera/composition.  

### File Size/Quality
- Comparable to current, with optional HEVC for better compression.  
---
## Trade-offs & Limitations
### What You Gain ✅
| Benefit | Description |
|---------|-------------|
| **Draggable Overlay** | Full user control over position/size |
| **Customization** | Add effects (e.g., rounded corners, opacity) |
| **Flexibility** | Works without system picker |

### What You Lose ⚠️
| Limitation | Impact | Mitigation |
|------------|--------|------------|
| **Code Complexity** | Back to manual processing (+500 lines) | Modularize composition |
| **Performance Hit** | +5-10% CPU, +30% memory | Optimize with Metal |
| **Reliability** | Manual sync risks drift | Use timestamps rigorously |
| **Native Features** | Lose SCRecordingOutput simplicity | Fallback to native if drag not essential |
| **Privacy/UX** | No system picker consent flow | Add custom preview/permissions UI |

### Recommendation Matrix
| Priority | Recommendation |
|----------|----------------|
| **Simplicity/Performance** | Use native Presenter Overlay (no drag) |
| **Custom UX (Draggable)** | Implement manual composition |
**Final Recommendation:** ✅ Proceed with manual if drag is critical; otherwise, stick to native for simplicity.  
---
## Conclusion
This plan adds draggable camera overlay but increases complexity. If drag isn't essential, revert to native Presenter Overlay (simpler, system-managed). Next: Prototype composition performance.  

**Document Version:** 1.0  
**Last Updated:** 2024-11-24  
**Author:** Grok  
**Status:** ✅ Ready for Review
