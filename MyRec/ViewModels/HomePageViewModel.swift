//
//  HomePageViewModel.swift
//  MyRec
//
//  View model for home page
//

import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
class HomePageViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recentRecordings: [VideoMetadata] = []
    @Published var isLoading = false

    // MARK: - Private Properties

    private let settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        loadRecentRecordings()
        setupNotificationObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Data Management

    /// Setup notification observers for recording events
    private func setupNotificationObservers() {
        // Listen for new recordings being saved
        NotificationCenter.default.publisher(for: .recordingSaved)
            .sink { [weak self] notification in
                Task { @MainActor in
                    print("🏠 HomePageViewModel: New recording saved, refreshing list...")
                    self?.refresh()
                }
            }
            .store(in: &cancellables)

        // Listen for recordings being deleted
        NotificationCenter.default.publisher(for: .recordingDeleted)
            .sink { [weak self] notification in
                Task { @MainActor in
                    print("🏠 HomePageViewModel: Recording deleted, refreshing list...")
                    self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    /// Load all recordings from disk
    private func loadRecentRecordings() {
        isLoading = true
        print("📂 Loading recordings from: \(settingsManager.savePath.path)")

        Task {
            do {
                // Use FileManagerService to load all recordings
                let fileManagerService = FileManagerService.shared
                let allRecordings = try await fileManagerService.getSavedRecordings()

                await MainActor.run {
                    self.recentRecordings = allRecordings
                    isLoading = false
                    print("✅ Loaded \(self.recentRecordings.count) recordings")
                }

            } catch {
                print("❌ Failed to load recordings: \(error)")
                await MainActor.run {
                    recentRecordings = []
                    isLoading = false
                }
            }
        }
    }

    /// Refresh recordings list
    func refresh() {
        loadRecentRecordings()
    }

    // MARK: - Actions

    /// Start recording
    func startRecording() {
        print("▶️ Start Recording clicked from home page")
        NotificationCenter.default.post(name: .startRecording, object: nil)
    }

    /// Open settings
    func openSettings() {
        print("⚙️ Settings clicked from home page")
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    /// Open recording directory in Finder
    func openRecordingDirectory() {
        let savePath = settingsManager.savePath
        print("📁 Opening recording directory: \(savePath.path)")
        NSWorkspace.shared.open(savePath)
    }

    /// Play a recording
    func playRecording(_ recording: VideoMetadata) {
        print("▶️ Playing recording: \(recording.filename)")
        NotificationCenter.default.post(
            name: .openPreview,
            object: nil,
            userInfo: ["recording": recording]
        )
    }

    /// Trim a recording
    func trimRecording(_ recording: VideoMetadata) {
        print("✂️ Trimming recording: \(recording.filename)")
        // TODO: Implement trim dialog with VideoMetadata
        print("⚠️ Trim dialog not yet updated for VideoMetadata")
    }

    /// Delete a recording
    func deleteRecording(_ recording: VideoMetadata) {
        print("🗑 Deleting recording: \(recording.filename)")

        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Delete Recording?"
        alert.informativeText = "Are you sure you want to delete \"\(recording.filename)\"? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            do {
                // Delete file from disk
                try FileManager.default.removeItem(at: recording.fileURL)
                print("✅ File deleted from disk: \(recording.fileURL.path)")

                // Remove from list
                recentRecordings.removeAll { $0.id == recording.id }
                print("✅ Recording removed from list")
            } catch {
                print("❌ Failed to delete file: \(error)")
                // Show error alert
                let errorAlert = NSAlert()
                errorAlert.messageText = "Failed to Delete"
                errorAlert.informativeText = "Could not delete the recording: \(error.localizedDescription)"
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
            }
        }
    }
}
