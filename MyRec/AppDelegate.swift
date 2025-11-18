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

    // Real recording manager
    private let recordingManager = RecordingManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show dock icon for window-based app
        NSApp.setActivationPolicy(.regular)

        // Initialize status bar with recording manager
        statusBarController = StatusBarController(recordingManager: recordingManager)

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

        // Listen for recording state changes (when countdown completes)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingStateChanged(_:)),
            name: .recordingStateChanged,
            object: nil
        )

        print("✅ Registered observer for startRecording notification")
        print("✅ Registered observer for openSettings notification")
        print("✅ Registered observer for showDashboard notification")
        print("✅ Registered observer for openPreview notification")
        print("✅ Registered observer for openTrim notification")
        print("✅ Registered observer for stopRecording notification")
        print("✅ Registered observer for recordingStateChanged notification")
    }

    @objc private func handleStartRecording() {
        print("📱 Record Screen clicked - checking permissions first")

        Task { @MainActor in
            // Check Screen Recording permission BEFORE showing region selection
            if #available(macOS 13.0, *) {
                print("🔒 [DEBUG] Checking Screen Recording permission...")
                let hasPermission = await ScreenCaptureEngine.checkPermission()

                if !hasPermission {
                    print("⚠️ [DEBUG] Screen Recording permission not granted")
                    print("⚠️ [DEBUG] Showing permission dialog - user must enable in System Settings and restart")

                    // Show permission instructions dialog
                    await showPermissionRequestDialog()
                    return
                }

                print("✅ [DEBUG] Screen Recording permission already granted")
            }

            // Permission granted - proceed with region selection
            print("📱 Hiding home page and showing region selection overlay")
            homePageWindowController?.hide()
            showRegionSelection()
        }
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

    @objc private func handleRecordingStateChanged(_ notification: Notification) {
        guard let state = notification.object as? RecordingState else {
            print("⚠️ Invalid recording state in notification")
            return
        }

        // Only handle the transition to recording state
        switch state {
        case .recording:
            // Get selected region from region selection window
            guard let region = regionSelectionWindow?.selectedRegion else {
                print("⚠️ No region selected, cannot start recording")
                return
            }

            print("🎬 Starting recording with region: \(region)")

            Task { @MainActor in
                do {
                    print("🎬 [DEBUG] Calling recordingManager.startRecording with region: \(region)")
                    try await recordingManager.startRecording(region: region)
                    print("✅ [DEBUG] Recording started successfully")

                    // Close region selection window
                    regionSelectionWindow?.close()
                    regionSelectionWindow = nil
                } catch {
                    print("❌ [DEBUG] Recording failed: \(error)")
                    print("❌ [DEBUG] Error type: \(type(of: error))")
                    print("❌ [DEBUG] Error details: \(String(describing: error))")

                    showErrorAlert(
                        title: "Failed to Start Recording",
                        message: "\(error.localizedDescription)\n\nDetails: \(String(describing: error))"
                    )
                    // Close region selection on error
                    regionSelectionWindow?.close()
                    regionSelectionWindow = nil
                }
            }

        case .idle, .paused:
            // These states are handled elsewhere
            break
        }
    }

    @objc private func handleStopRecording() {
        print("⏹ [DEBUG] Recording stopped - finalizing recording with RecordingManager")

        Task { @MainActor in
            do {
                print("⏹ [DEBUG] Calling recordingManager.stopRecording()")
                let metadata = try await recordingManager.stopRecording()
                print("✅ [DEBUG] Recording saved: \(metadata.filename)")
                print("✅ [DEBUG] File location: \(metadata.fileURL.path)")
                print("✅ [DEBUG] File size: \(metadata.fileSize) bytes")
                print("✅ [DEBUG] Duration: \(metadata.duration) seconds")

                // Show preview dialog with real recording
                showPreviewDialog(for: metadata)

                // Refresh home page recordings list
                homePageWindowController?.refreshRecordings()
            } catch {
                print("❌ [DEBUG] Stop recording failed: \(error)")
                print("❌ [DEBUG] Error type: \(type(of: error))")
                print("❌ [DEBUG] Error details: \(String(describing: error))")

                showErrorAlert(
                    title: "Failed to Stop Recording",
                    message: "\(error.localizedDescription)\n\nDetails: \(String(describing: error))"
                )
            }
        }
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

    private func showPreviewDialog(for metadata: VideoMetadata) {
        // Create new preview dialog window controller with real metadata
        previewDialogWindowController = PreviewDialogWindowController(metadata: metadata)
        previewDialogWindowController?.show()
        print("✅ Preview dialog shown for: \(metadata.filename)")
    }

    private func showTrimDialog(for recording: MockRecording) {
        // Create new trim dialog window controller
        trimDialogWindowController = TrimDialogWindowController(recording: recording)
        print("✅ Trim dialog shown for: \(recording.filename)")
    }

    private func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @MainActor
    private func showPermissionRequestDialog() async -> Bool {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
        MyRec needs permission to record your screen.

        Steps:
        1. Click "Open Settings" below
        2. In System Settings → Privacy & Security → Screen Recording
        3. Enable the checkbox next to MyRec
        4. RESTART MyRec (quit and relaunch)

        Note: macOS requires apps to restart after granting Screen Recording permission.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings to Privacy & Security
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
        return false // Always return false since user needs to restart anyway
    }

    @MainActor
    private func showPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Denied"
        alert.informativeText = """
        MyRec cannot record your screen without permission.

        To enable Screen Recording:
        1. Open System Settings
        2. Go to Privacy & Security → Screen Recording
        3. Enable the checkbox next to MyRec
        4. Restart MyRec

        You can also click "Open Settings" below to go directly to the Privacy & Security settings.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings to Privacy & Security
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
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
