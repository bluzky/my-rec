//
//  PreviewDialogViewModel.swift
//  MyRec
//
//  View model for preview dialog
//

import Foundation
import SwiftUI
import Combine
import AVKit
import AppKit

@MainActor
class PreviewDialogViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recording: VideoMetadata
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var volume: Double = 1.0
    @Published var isMuted: Bool = false
    @Published var playbackSpeed: Double = 1.0

    // MARK: - Private Properties

    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private let availablePlaybackSpeeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    private var volumeBeforeMute: Double = 1.0

    // MARK: - Initialization

    init(recording: VideoMetadata) {
        self.recording = recording
        print("🎬 Preview dialog initialized for: \(recording.filename)")
        setupPlayer()
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
        guard let player = player else { return }
        guard !isPlaying else { return }

        // Reset to beginning if at the end
        if currentTime >= recording.duration {
            player.seek(to: .zero)
            currentTime = 0
        }

        player.play()
        isPlaying = true
        print("▶️ Playing: \(recording.filename)")
    }

    /// Pause playback
    func pause() {
        guard let player = player else { return }
        guard isPlaying else { return }

        player.pause()
        isPlaying = false
        print("⏸ Paused: \(recording.filename)")
    }

    /// Seek to specific time
    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        let seekTime = min(max(time, 0), recording.duration)
        player.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
        currentTime = seekTime
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
        player?.volume = Float(clamped)

        if clamped == 0 {
            isMuted = true
            player?.isMuted = true
        } else {
            volumeBeforeMute = clamped
            isMuted = false
            player?.isMuted = false
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
            player?.isMuted = true
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
        NSWorkspace.shared.activateFileViewerSelecting([recording.fileURL])
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
            setPlaybackSpeed(availablePlaybackSpeeds[nextIndex])
        }
    }

    /// Set playback speed to a specific value
    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = speed
        player?.rate = Float(speed)
        print("⏩ Playback speed set to: \(playbackSpeedString)")
    }

    // MARK: - Private Methods

    private func setupPlayer() {
        print("🎬 Setting up player for: \(recording.filename)")

        // Create player with video URL
        player = AVPlayer(url: recording.fileURL)

        // Set initial volume
        player?.volume = Float(volume)

        // Add periodic time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }

            Task { @MainActor in
                self.currentTime = time.seconds

                // Auto-pause at end
                if let duration = self.player?.currentItem?.duration.seconds,
                   duration.isFinite,
                   self.currentTime >= duration {
                    self.pause()
                }
            }
        }

        // Observe player status
        statusObserver = player?.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }

            Task { @MainActor in
                if item.status == .readyToPlay {
                    print("✅ Player ready to play")
                    // Auto-play
                    self.play()
                } else if item.status == .failed {
                    print("❌ Player failed: \(item.error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }

    private func cleanup() {
        print("🗑 Cleaning up player")

        // Remove time observer
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        // Remove status observer
        statusObserver?.invalidate()
        statusObserver = nil

        // Pause and release player
        player?.pause()
        player = nil
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
            cleanup()
        }
        print("🗑 Preview dialog view model deallocated")
    }
}
