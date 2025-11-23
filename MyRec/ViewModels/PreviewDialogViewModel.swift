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

    // MARK: - Private Properties

    private var statusObserver: NSKeyValueObservation?

    // MARK: - Initialization

    init(recording: VideoMetadata) {
        self.recording = recording
        print("🎬 Preview dialog initialized for: \(recording.filename)")
        setupPlayer()
    }

    // MARK: - Playback Controls

    /// Start playback
    func play() {
        guard let player = player else { return }
        player.play()
        print("▶️ Playing: \(recording.filename)")
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

    // MARK: - Private Methods

    private func setupPlayer() {
        print("🎬 Setting up player for: \(recording.filename)")

        // Create player with video URL
        player = AVPlayer(url: recording.fileURL)

        // Observe player status
        statusObserver = player?.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard self != nil else { return }

            Task { @MainActor in
                if item.status == .readyToPlay {
                    print("✅ Player ready to play")
                } else if item.status == .failed {
                    print("❌ Player failed: \(item.error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }

    private func cleanup() {
        print("🗑 Cleaning up player")

        // Remove status observer
        statusObserver?.invalidate()
        statusObserver = nil

        // Pause and release player
        player?.pause()
        player = nil
    }

    // MARK: - Cleanup

    nonisolated deinit {
        MainActor.assumeIsolated {
            cleanup()
        }
        print("🗑 Preview dialog view model deallocated")
    }
}
