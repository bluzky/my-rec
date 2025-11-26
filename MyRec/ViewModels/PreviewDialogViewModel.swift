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
    private var onCloseWindow: (() -> Void)?

    // MARK: - Initialization

    init(recording: VideoMetadata) {
        self.recording = recording
        print("🎬 Preview dialog initialized for: \(recording.filename)")
        setupPlayer()
    }

    /// Set callback to be called when window should close
    func setOnCloseWindow(_ callback: @escaping (() -> Void)) {
        self.onCloseWindow = callback
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

    /// Show in Finder
    func showInFinder() {
        print("📂 Show in Finder: \(recording.filename)")
        NSWorkspace.shared.activateFileViewerSelecting([recording.fileURL])
    }

    /// Delete recording with confirmation
    func deleteRecording() {
        print("🗑 Delete recording: \(recording.filename)")

        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Delete Recording"
        alert.informativeText = "Are you sure you want to delete \"\(recording.filename)\"? This action cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        // Run as modal dialog (not sheet) to avoid window reference issues
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // User confirmed deletion
            Task { @MainActor in
                await self.performDelete()
            }
        }
    }

    /// Perform the actual deletion
    private func performDelete() async {
        let success = await FileManagerService.shared.deleteRecording(recording)

        if success {
            print("✅ Recording deleted successfully")

            // Notify home page to refresh
            NotificationCenter.default.post(
                name: .recordingDeleted,
                object: nil,
                userInfo: ["recording": recording]
            )

            // Close preview window using callback
            onCloseWindow?()
        } else {
            // Show error alert
            let errorAlert = NSAlert()
            errorAlert.messageText = "Delete Failed"
            errorAlert.informativeText = "Could not delete \"\(recording.filename)\". Please check file permissions."
            errorAlert.alertStyle = .warning
            errorAlert.addButton(withTitle: "OK")
            errorAlert.runModal()
        }
    }

    /// Rename recording
    func renameRecording() {
        print("✏️ Rename recording: \(recording.filename)")
        // TODO: Show rename dialog
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
