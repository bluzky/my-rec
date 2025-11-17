//
//  TrimDialogViewModel.swift
//  MyRec
//
//  View model for trim dialog
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TrimDialogViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recording: MockRecording
    @Published var startTime: TimeInterval = 0
    @Published var endTime: TimeInterval
    @Published var playheadPosition: TimeInterval = 0
    @Published var isPlaying: Bool = false
    @Published var isTrimming: Bool = false
    @Published var trimProgress: Double = 0
    @Published var isMuted: Bool = false

    // MARK: - Private Properties

    private var playbackTimer: Timer?

    // MARK: - Initialization

    init(recording: MockRecording) {
        self.recording = recording
        self.endTime = recording.duration
        self.playheadPosition = 0
        print("✂️ Trim dialog initialized for: \(recording.filename)")
    }

    // MARK: - Computed Properties

    /// Selected duration (end - start)
    var selectedDuration: TimeInterval {
        max(0, endTime - startTime)
    }

    /// Start time formatted as HH:MM:SS
    var startTimeString: String {
        formatTime(startTime)
    }

    /// End time formatted as HH:MM:SS
    var endTimeString: String {
        formatTime(endTime)
    }

    /// Duration formatted as HH:MM:SS
    var durationString: String {
        formatTime(selectedDuration)
    }

    /// Playhead time formatted as HH:MM:SS
    var playheadTimeString: String {
        formatTime(playheadPosition)
    }

    /// Output filename for trimmed video
    var outputFilename: String {
        let basename = recording.filename.replacingOccurrences(of: ".mp4", with: "")
        return "\(basename)-trimmed.mp4"
    }

    /// Normalized start position (0.0 to 1.0)
    var normalizedStartPosition: Double {
        guard recording.duration > 0 else { return 0 }
        return startTime / recording.duration
    }

    /// Normalized end position (0.0 to 1.0)
    var normalizedEndPosition: Double {
        guard recording.duration > 0 else { return 1 }
        return endTime / recording.duration
    }

    /// Normalized playhead position (0.0 to 1.0)
    var normalizedPlayheadPosition: Double {
        guard recording.duration > 0 else { return 0 }
        return playheadPosition / recording.duration
    }

    // MARK: - Timeline Controls

    /// Update start time from normalized position (0.0 to 1.0)
    func setStartPosition(_ normalizedPosition: Double) {
        let newStartTime = normalizedPosition * recording.duration

        // Ensure start is before end (with minimum gap)
        let minGap: TimeInterval = 1.0 // Minimum 1 second
        startTime = min(newStartTime, endTime - minGap)
        startTime = max(0, startTime)

        // Move playhead if it's before start
        if playheadPosition < startTime {
            playheadPosition = startTime
        }

        print("📍 Start time: \(startTimeString)")
    }

    /// Update end time from normalized position (0.0 to 1.0)
    func setEndPosition(_ normalizedPosition: Double) {
        let newEndTime = normalizedPosition * recording.duration

        // Ensure end is after start (with minimum gap)
        let minGap: TimeInterval = 1.0 // Minimum 1 second
        endTime = max(newEndTime, startTime + minGap)
        endTime = min(recording.duration, endTime)

        // Move playhead if it's after end
        if playheadPosition > endTime {
            playheadPosition = endTime
        }

        print("📍 End time: \(endTimeString)")
    }

    /// Update playhead position from normalized position (0.0 to 1.0)
    func setPlayheadPosition(_ normalizedPosition: Double) {
        playheadPosition = normalizedPosition * recording.duration
        playheadPosition = max(0, min(recording.duration, playheadPosition))

        print("📍 Playhead: \(playheadTimeString)")
    }

    /// Seek to specific time
    func seek(to time: TimeInterval) {
        playheadPosition = max(0, min(recording.duration, time))
    }

    /// Seek by relative offset (e.g., +15s or -15s)
    func seek(by offset: TimeInterval) {
        seek(to: playheadPosition + offset)
    }

    /// Seek by frame (assuming 30fps for mock)
    func seekByFrame(_ direction: Int) {
        let frameDuration = 1.0 / 30.0
        seek(to: playheadPosition + (frameDuration * Double(direction)))
    }

    // MARK: - Playback Controls

    /// Toggle play/pause for selected range
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Play selected range
    func play() {
        guard !isPlaying else { return }

        // Reset to start if playhead is outside selected range
        if playheadPosition < startTime || playheadPosition >= endTime {
            playheadPosition = startTime
        }

        isPlaying = true
        startPlaybackTimer()
        print("▶️ Playing trimmed range: \(startTimeString) - \(endTimeString)")
    }

    /// Pause playback
    func pause() {
        guard isPlaying else { return }

        isPlaying = false
        stopPlaybackTimer()
        print("⏸ Paused")
    }

    // MARK: - Trim Actions

    /// Reset trim points to full video
    func resetTrim() {
        startTime = 0
        endTime = recording.duration
        playheadPosition = 0
        print("🔄 Reset trim points to full video")
    }

    /// Save trimmed video (replaces original)
    func save() {
        guard !isTrimming else { return }

        isTrimming = true
        trimProgress = 0

        print("💾 Saving trimmed video (replace original):")
        print("   File: \(recording.filename)")
        print("   Range: \(startTimeString) - \(endTimeString)")
        print("   Duration: \(durationString)")

        // Simulate trim progress
        simulateTrimProgress(replaceOriginal: true)
    }

    /// Save trimmed video as new file
    func saveAs() {
        guard !isTrimming else { return }

        isTrimming = true
        trimProgress = 0

        print("💾 Saving trimmed video as new file:")
        print("   Input: \(recording.filename)")
        print("   Output: \(outputFilename)")
        print("   Range: \(startTimeString) - \(endTimeString)")
        print("   Duration: \(durationString)")

        // Simulate trim progress
        simulateTrimProgress(replaceOriginal: false)
    }

    /// Cancel trim operation
    func cancel() {
        print("❌ Trim cancelled")
        NotificationCenter.default.post(name: .closeTrim, object: nil)
    }

    /// Delete selection (reset to full video)
    func deleteSelection() {
        print("🗑 Delete selection")
        // For now, same as reset
        resetTrim()
    }

    /// Toggle mute/unmute
    func toggleMute() {
        isMuted.toggle()
        print(isMuted ? "🔇 Muted" : "🔊 Unmuted")
    }

    // MARK: - Preview Frame

    /// Get placeholder color for current playhead frame
    var currentFrameColor: Color {
        // Cycle through colors based on playhead position
        let progress = playheadPosition / recording.duration

        if progress < 0.2 {
            return recording.thumbnailColor
        } else if progress < 0.4 {
            return recording.thumbnailColor.opacity(0.8)
        } else if progress < 0.6 {
            return recording.thumbnailColor.opacity(0.6)
        } else if progress < 0.8 {
            return recording.thumbnailColor.opacity(0.4)
        } else {
            return recording.thumbnailColor.opacity(0.2)
        }
    }

    // MARK: - Private Methods

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                // Increment playhead
                self.playheadPosition += 0.033

                // Loop or stop at end of selected range
                if self.playheadPosition >= self.endTime {
                    self.playheadPosition = self.startTime
                }
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func simulateTrimProgress(replaceOriginal: Bool) {
        // Simulate trim operation with progress updates
        var progress: Double = 0

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                progress += 0.05
                self.trimProgress = min(progress, 1.0)

                if progress >= 1.0 {
                    timer.invalidate()

                    // Simulate completion delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.completeTrim(replaceOriginal: replaceOriginal)
                    }
                }
            }
        }
    }

    private func completeTrim(replaceOriginal: Bool) {
        if replaceOriginal {
            print("✅ Trim completed (original replaced): \(recording.filename)")
        } else {
            print("✅ Trim completed (saved as new): \(outputFilename)")
        }

        // Reset state
        isTrimming = false
        trimProgress = 0

        // Close dialog
        NotificationCenter.default.post(name: .closeTrim, object: nil)

        // TODO: Add trimmed recording to history
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Cleanup

    nonisolated deinit {
        MainActor.assumeIsolated {
            playbackTimer?.invalidate()
            playbackTimer = nil
        }
        print("🗑 Trim dialog view model deallocated")
    }
}
