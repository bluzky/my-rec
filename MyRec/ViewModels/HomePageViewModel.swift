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

    @Published var recentRecordings: [MockRecording] = []

    // MARK: - Initialization

    init() {
        loadRecentRecordings()
    }

    // MARK: - Data Management

    /// Load recent recordings (limit to 5 for home page)
    private func loadRecentRecordings() {
        // Generate mock recordings for UI development
        let allRecordings = MockRecordingGenerator.generate(count: 15)
        recentRecordings = Array(allRecordings.prefix(5))
        print("🏠 Loaded \(recentRecordings.count) recent recordings for home page")
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

    /// Play a recording
    func playRecording(_ recording: MockRecording) {
        print("▶️ Playing recording: \(recording.filename)")
        NotificationCenter.default.post(
            name: .openPreview,
            object: nil,
            userInfo: ["recording": recording]
        )
    }

    /// Share a recording
    func shareRecording(_ recording: MockRecording) {
        print("📤 Sharing recording: \(recording.filename)")
        // TODO: Show macOS share sheet
    }

    /// Delete a recording
    func deleteRecording(_ recording: MockRecording) {
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
            // Remove from list
            recentRecordings.removeAll { $0.id == recording.id }
            print("✅ Recording deleted: \(recording.filename)")
        }
    }
}
