//
//  AppDelegate.swift
//  MyRec
//
//  Created by Flex on 11/14/25.
//

import Cocoa
import SwiftUI
#if canImport(MyRecCore)
import MyRecCore
#endif

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var regionSelectionWindow: RegionSelectionWindow?
    var settingsWindowController: SettingsWindowController?
    var homePageWindowController: HomePageWindowController?
    var previewDialogWindowController: PreviewDialogWindowController?
    var trimDialogWindowController: TrimDialogWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show dock icon for window-based app
        NSApp.setActivationPolicy(.regular)

        // Initialize status bar
        statusBarController = StatusBarController()

        // Initialize settings window controller
        settingsWindowController = SettingsWindowController(settingsManager: SettingsManager.shared)

        // Initialize and show home page window
        homePageWindowController = HomePageWindowController()
        homePageWindowController?.show()

        // Set up notification observers
        setupNotificationObservers()

        print("✅ MyRec launched successfully")
        print("✅ Status bar controller initialized")
        print("✅ Settings window controller initialized")
        print("✅ Home page window initialized and shown")
        print("✅ Notification observers set up")
    }

    private func setupNotificationObservers() {
        // Listen for start recording notification to show region selection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartRecording),
            name: .startRecording,
            object: nil
        )

        // Listen for open settings notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettings,
            object: nil
        )

        // Listen for show dashboard notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowDashboard),
            name: .showDashboard,
            object: nil
        )

        // Listen for open preview notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenPreview(_:)),
            name: .openPreview,
            object: nil
        )

        // Listen for open trim notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenTrim(_:)),
            name: .openTrim,
            object: nil
        )

        // Listen for stop recording notification to show preview
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStopRecording),
            name: .stopRecording,
            object: nil
        )

        print("✅ Registered observer for startRecording notification")
        print("✅ Registered observer for openSettings notification")
        print("✅ Registered observer for showDashboard notification")
        print("✅ Registered observer for openPreview notification")
        print("✅ Registered observer for openTrim notification")
        print("✅ Registered observer for stopRecording notification")
    }

    @objc private func handleStartRecording() {
        print("📱 Record Screen clicked - hiding home page and showing region selection overlay")
        // Hide home page window before showing region selection
        homePageWindowController?.hide()
        showRegionSelection()
    }

    @objc private func handleOpenSettings() {
        print("⚙️ Settings clicked - showing settings dialog")
        showSettings()
    }

    @objc private func handleShowDashboard() {
        print("🏠 Dashboard clicked - showing home page")
        showDashboard()
    }

    @objc private func handleOpenPreview(_ notification: Notification) {
        print("🎬 Preview clicked - showing preview dialog")
        if let recording = notification.userInfo?["recording"] as? MockRecording {
            showPreviewDialog(for: recording)
        } else {
            print("⚠️ No recording data found in notification")
        }
    }

    @objc private func handleOpenTrim(_ notification: Notification) {
        print("✂️ Trim clicked - showing trim dialog")
        if let recording = notification.userInfo?["recording"] as? MockRecording {
            showTrimDialog(for: recording)
        } else {
            print("⚠️ No recording data found in notification")
        }
    }

    @objc private func handleStopRecording() {
        print("⏹ Recording stopped - creating mock recording and showing preview")

        // Create filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let timestamp = dateFormatter.string(from: Date())

        // Create a mock recording for the just-completed session
        let mockRecording = MockRecording(
            id: UUID(),
            filename: "MyRecord-\(timestamp).mp4",
            duration: statusBarController?.elapsedTime ?? 30.0,
            resolution: SettingsManager.shared.defaultSettings.resolution,
            frameRate: SettingsManager.shared.defaultSettings.frameRate,
            fileSize: statusBarController?.simulatedFileSize ?? Int64(150_000_000),
            createdDate: Date(),
            thumbnailColor: .blue
        )

        // Show preview dialog for this recording
        showPreviewDialog(for: mockRecording)
    }

    private func showRegionSelection() {
        // Clean up existing window if any
        if let existingWindow = regionSelectionWindow {
            existingWindow.cleanup() // Remove event monitors first
            existingWindow.orderOut(nil) // Hide the window
            regionSelectionWindow = nil
        }

        // Create and show new region selection window
        regionSelectionWindow = RegionSelectionWindow()
        regionSelectionWindow?.makeKeyAndOrderFront(nil)
        regionSelectionWindow?.orderFrontRegardless()

        // Bring the app to front to make the overlay visible
        NSApp.activate(ignoringOtherApps: true)

        print("✅ Region selection window shown")
    }

    private func showSettings() {
        settingsWindowController?.show()
        print("✅ Settings dialog shown")
    }

    private func showDashboard() {
        homePageWindowController?.show()
        print("✅ Dashboard shown")
    }

    private func showPreviewDialog(for recording: MockRecording) {
        // Create new preview dialog window controller
        previewDialogWindowController = PreviewDialogWindowController(recording: recording)
        previewDialogWindowController?.show()
        print("✅ Preview dialog shown for: \(recording.filename)")
    }

    private func showTrimDialog(for recording: MockRecording) {
        // Create new trim dialog window controller
        trimDialogWindowController = TrimDialogWindowController(recording: recording)
        print("✅ Trim dialog shown for: \(recording.filename)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
        print("👋 MyRec terminating")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when windows close (menu bar app)
        return false
    }
}
