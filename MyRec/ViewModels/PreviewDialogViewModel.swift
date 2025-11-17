//
//  PreviewDialogViewModel.swift
//  MyRec
//
//  View model for preview dialog
//

import Foundation
import SwiftUI
import Combine

@MainActor
class PreviewDialogViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recording: MockRecording
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var volume: Double = 1.0
    @Published var isMuted: Bool = false
    @Published var playbackSpeed: Double = 1.0

    // MARK: - Private Properties

    private var playbackTimer: Timer?
    private let availablePlaybackSpeeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    private var volumeBeforeMute: Double = 1.0

    // MARK: - Initialization

    init(recording: MockRecording) {
        self.recording = recording
        print("🎬 Preview dialog initialized for: \(recording.filename)")
    }

    // MARK: - Computed Properties

    /// Current time formatted as HH:MM:SS or MM:SS
    var currentTimeString: String {
        formatTime(currentTime)
    }

    /// Remaining time formatted as HH:MM:SS or MM:SS
    var remainingTimeString: String {
        formatTime(recording.duration - currentTime)
    }

    /// Playback progress (0.0 to 1.0)
    var progress: Double {
        guard recording.duration > 0 else { return 0 }
        return min(max(currentTime / recording.duration, 0), 1)
    }

    /// Playback speed as formatted string
    var playbackSpeedString: String {
        // Format to remove unnecessary decimals (e.g., "2x" instead of "2.0x")
        if playbackSpeed.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(playbackSpeed))x"
        } else {
            return "\(playbackSpeed)x"
        }
    }

    // MARK: - Playback Controls

    /// Toggle play/pause
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Start playback
    func play() {
        guard !isPlaying else { return }

        // Reset to beginning if at the end
        if currentTime >= recording.duration {
            currentTime = 0
        }

        isPlaying = true
        startPlaybackTimer()
        print("▶️ Playing: \(recording.filename)")
    }

    /// Pause playback
    func pause() {
        guard isPlaying else { return }

        isPlaying = false
        stopPlaybackTimer()
        print("⏸ Paused: \(recording.filename)")
    }

    /// Seek to specific time
    func seek(to time: TimeInterval) {
        currentTime = min(max(time, 0), recording.duration)
        print("⏩ Seeked to: \(currentTimeString)")
    }

    /// Seek by relative offset (e.g., +5s or -5s)
    func seek(by offset: TimeInterval) {
        seek(to: currentTime + offset)
    }

    /// Adjust volume (0.0 to 1.0)
    func setVolume(_ newVolume: Double) {
        let clamped = min(max(newVolume, 0), 1)
        volume = clamped

        if clamped == 0 {
            isMuted = true
        } else {
            volumeBeforeMute = clamped
            isMuted = false
        }
    }

    /// Toggle mute/unmute
    func toggleMute() {
        if isMuted {
            let restoredVolume = volumeBeforeMute > 0 ? volumeBeforeMute : 0.5
            setVolume(restoredVolume)
        } else {
            volumeBeforeMute = volume > 0 ? volume : volumeBeforeMute
            volume = 0
            isMuted = true
        }
    }

    // MARK: - Actions

    /// Open trim dialog
    func trimVideo() {
        print("✂️ Trim video clicked: \(recording.filename)")
        NotificationCenter.default.post(
            name: .openTrim,
            object: nil,
            userInfo: ["recording": recording]
        )
    }

    /// Share recording
    func shareRecording() {
        print("📤 Share recording: \(recording.filename)")
        // TODO: Show macOS share sheet
    }

    /// Show in Finder
    func showInFinder() {
        print("📂 Show in Finder: \(recording.filename)")
        // TODO: Open Finder to recording location
        // For now, just log the action
    }

    /// Delete recording
    func deleteRecording() {
        print("🗑 Delete recording: \(recording.filename)")
        // TODO: Show confirmation and delete
    }

    /// Rename recording
    func renameRecording() {
        print("✏️ Rename recording: \(recording.filename)")
        // TODO: Show rename dialog
    }

    /// Share to device (AirDrop, etc.)
    func shareToDevice() {
        print("📱 Share to device: \(recording.filename)")
        // TODO: Show device sharing options
    }

    /// Cycle through playback speeds
    func cyclePlaybackSpeed() {
        if let currentIndex = availablePlaybackSpeeds.firstIndex(of: playbackSpeed) {
            let nextIndex = (currentIndex + 1) % availablePlaybackSpeeds.count
            playbackSpeed = availablePlaybackSpeeds[nextIndex]
            print("⏩ Playback speed: \(playbackSpeedString)")

            // Restart timer with new speed if playing
            if isPlaying {
                stopPlaybackTimer()
                startPlaybackTimer()
            }
        }
    }

    /// Set playback speed to a specific value
    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = speed
        print("⏩ Playback speed set to: \(playbackSpeedString)")

        // Restart timer with new speed if playing
        if isPlaying {
            stopPlaybackTimer()
            startPlaybackTimer()
        }
    }

    // MARK: - Private Methods

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                // Increment time based on playback speed
                self.currentTime += (0.1 * self.playbackSpeed)

                // Stop at end
                if self.currentTime >= self.recording.duration {
                    self.currentTime = self.recording.duration
                    self.pause()
                }
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
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
        print("🗑 Preview dialog view model deallocated")
    }
}
