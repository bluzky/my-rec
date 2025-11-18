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

    @Published var recording: MockRecording?
    @Published var metadata: VideoMetadata?
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
        self.metadata = nil
        print("🎬 Preview dialog initialized for: \(recording.filename)")
    }

    init(metadata: VideoMetadata) {
        self.recording = nil
        self.metadata = metadata
        print("🎬 Preview dialog initialized for: \(metadata.filename)")
    }

    // MARK: - Computed Properties

    /// Duration from either recording or metadata
    var duration: TimeInterval {
        if let recording = recording {
            return recording.duration
        } else if let metadata = metadata {
            return metadata.duration
        }
        return 0
    }

    /// Filename from either recording or metadata
    var filename: String {
        if let recording = recording {
            return recording.filename
        } else if let metadata = metadata {
            return metadata.filename
        }
        return "Unknown"
    }

    /// File URL for real recordings (returns nil for mock recordings)
    var fileURL: URL? {
        return metadata?.fileURL
    }

    /// Current time formatted as HH:MM:SS or MM:SS
    var currentTimeString: String {
        formatTime(currentTime)
    }

    /// Remaining time formatted as HH:MM:SS or MM:SS
    var remainingTimeString: String {
        formatTime(duration - currentTime)
    }

    /// Playback progress (0.0 to 1.0)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
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
        if currentTime >= duration {
            currentTime = 0
        }

        isPlaying = true
        startPlaybackTimer()
        print("▶️ Playing: \(filename)")
    }

    /// Pause playback
    func pause() {
        guard isPlaying else { return }

        isPlaying = false
        stopPlaybackTimer()
        print("⏸ Paused: \(filename)")
    }

    /// Seek to specific time
    func seek(to time: TimeInterval) {
        currentTime = min(max(time, 0), duration)
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
        print("✂️ Trim video clicked: \(filename)")
        if let recording = recording {
            NotificationCenter.default.post(
                name: .openTrim,
                object: nil,
                userInfo: ["recording": recording]
            )
        } else if let metadata = metadata {
            // TODO: Support trim for real recordings in Week 9
            print("⚠️ Trim not yet supported for real recordings")
        }
    }

    /// Share recording
    func shareRecording() {
        print("📤 Share recording: \(filename)")
        // TODO: Show macOS share sheet
    }

    /// Show in Finder
    func showInFinder() {
        print("📂 Show in Finder: \(filename)")
        if let fileURL = fileURL {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        }
    }

    /// Delete recording
    func deleteRecording() {
        print("🗑 Delete recording: \(filename)")
        // TODO: Show confirmation and delete
    }

    /// Rename recording
    func renameRecording() {
        print("✏️ Rename recording: \(filename)")
        // TODO: Show rename dialog
    }

    /// Share to device (AirDrop, etc.)
    func shareToDevice() {
        print("📱 Share to device: \(filename)")
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
                if self.currentTime >= self.duration {
                    self.currentTime = self.duration
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
