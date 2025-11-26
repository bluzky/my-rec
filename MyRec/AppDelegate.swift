//
//  AppDelegate.swift
//  MyRec
//
//  Created by Flex on 11/14/25.
//

import Cocoa
import SwiftUI
import CoreMedia
import ScreenCaptureKit
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
    var floatingRecordingControlWindow: FloatingRecordingControlWindow?

    // MARK: - Recording Engine
    private var captureEngine: ScreenCaptureEngine?
    private var recordingStartTime: Date?
    private var recordingResolution: Resolution?
    private var recordingFrameRate: FrameRate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set dock icon visibility based on user preference
        if SettingsManager.shared.hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }

        // Initialize status bar
        statusBarController = StatusBarController()

        // Initialize settings window controller
        settingsWindowController = SettingsWindowController(settingsManager: SettingsManager.shared)

        // Initialize and show home page window
        homePageWindowController = HomePageWindowController()
        homePageWindowController?.show()

        // Initialize floating recording control window (hidden by default)
        floatingRecordingControlWindow = FloatingRecordingControlWindow()

        // Set up notification observers
        setupNotificationObservers()

        print("✅ MyRec launched successfully")
        print("✅ Status bar controller initialized")
        print("✅ Settings window controller initialized")
        print("✅ Home page window initialized and shown")
        print("✅ Floating recording control initialized")
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

        // Listen for preview dialog closed notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreviewDialogClosed),
            name: .previewDialogClosed,
            object: nil
        )

        // Listen for stop recording notification (keyboard shortcut safety net)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStopRecording),
            name: .stopRecording,
            object: nil
        )

        // Listen for recording state changes to control screen capture
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

        // Check screen recording permission before proceeding
        Task { @MainActor in
            let hasPermission = await checkScreenRecordingPermission()

            if hasPermission {
                // Permission granted, proceed with region selection
                print("✅ Screen recording permission granted")
                homePageWindowController?.hide()
                showRegionSelection()
            } else {
                // Permission denied - system dialog already shown
                // Just log and abort the action
                print("❌ Screen recording permission denied - action aborted")
            }
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

    @objc private func handleStopRecording() {
        print("⏹ Stop recording notification received - stopping capture")
        stopCapture()
    }

    @objc private func handleOpenPreview(_ notification: Notification) {
        print("🎬 Preview clicked - showing preview dialog")
        if let metadata = notification.userInfo?["recording"] as? VideoMetadata {
            openPreviewDialog(with: metadata)
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

    @objc private func handlePreviewDialogClosed() {
        print("🗑 Preview dialog closed - releasing reference")
        previewDialogWindowController = nil
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
        // Show dock icon when dashboard opens if setting is disabled
        if !SettingsManager.shared.hideDockIcon {
            NSApp.setActivationPolicy(.regular)
        }
        homePageWindowController?.show()
        print("✅ Dashboard shown")
    }

    private func openPreviewDialog(with metadata: VideoMetadata) {
        print("🎬 Opening preview dialog for: \(metadata.filename)")

        // Close existing preview dialog if one is open
        if let existingDialog = previewDialogWindowController {
            print("⚠️ Closing existing preview dialog before opening new one")
            existingDialog.close()
            previewDialogWindowController = nil
        }

        // Create new preview dialog window controller with real video
        previewDialogWindowController = PreviewDialogWindowController(recording: metadata)
        previewDialogWindowController?.show()
        print("✅ Preview dialog shown - Real video will play")
    }

    private func showTrimDialog(for recording: MockRecording) {
        // Create new trim dialog window controller
        trimDialogWindowController = TrimDialogWindowController(recording: recording)
        print("✅ Trim dialog shown for: \(recording.filename)")
    }

    // MARK: - Permission Handling

    private func checkScreenRecordingPermission() async -> Bool {
        do {
            // Use ScreenCaptureKit to check if we have permission
            // This will trigger the system permission dialog if not already granted
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            let hasPermission = !content.displays.isEmpty

            if hasPermission {
                print("✅ Screen recording permission check passed - \(content.displays.count) display(s) available")
            } else {
                print("⚠️ No displays available - permission may be denied")
            }

            return hasPermission

        } catch {
            // Error during permission check (likely denied or restricted)
            print("❌ Screen recording permission check error: \(error)")
            return false
        }
    }

    // MARK: - Screen Capture Integration

    @objc private func handleRecordingStateChanged(_ notification: Notification) {
        guard let state = notification.object as? RecordingState else {
            print("⚠️ Invalid recording state in notification")
            return
        }

        switch state {
        case .recording(let startTime):
            recordingStartTime = startTime
            startCapture()
        case .idle:
            stopCapture()
        case .paused:
            // Pause not implemented in Day 20
            break
        }
    }

    private func startCapture() {
        Task { @MainActor in
            do {
                // Get region from region selection window
                guard let region = regionSelectionWindow?.selectedRegion else {
                    print("⚠️ No region selected, using full screen")
                    // Use full screen as default
                    let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
                    try await startCaptureEngine(region: screen)
                    return
                }

                try await startCaptureEngine(region: region)

            } catch {
                print("❌ Failed to start recording: \(error)")
                showError("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }

    private func startCaptureEngine(region: CGRect) async throws {
        let resolution = SettingsManager.shared.defaultSettings.resolution
        let frameRate = SettingsManager.shared.defaultSettings.frameRate
        let audioEnabled = SettingsManager.shared.defaultSettings.audioEnabled
        let microphoneEnabled = SettingsManager.shared.defaultSettings.microphoneEnabled

        // Store recording settings for metadata
        self.recordingResolution = resolution
        self.recordingFrameRate = frameRate

        print("📹 Starting capture...")
        print("  📊 Stored for metadata - Resolution: \(resolution.displayName), Frame Rate: \(frameRate.displayName)")
        print("  Region: \(region)")
        print("  Resolution: \(resolution.displayName)")
        print("  Frame Rate: \(frameRate.displayName)")
        print("  System Audio: \(audioEnabled)")
        print("  Microphone: \(microphoneEnabled)")

        // Create and configure capture engine
        captureEngine = ScreenCaptureEngine()
        captureEngine?.onRecordingStarted = { [weak self] in
            self?.handleRecordingStarted()
        }
        captureEngine?.onRecordingFinished = { [weak self] duration, fileURL in
            self?.handleRecordingFinished(duration: duration, fileURL: fileURL)
        }
        captureEngine?.onError = { [weak self] error in
            self?.handleCaptureError(error)
        }

        // Start capture with audio and microphone settings
        try await captureEngine?.startCapture(
            region: region,
            resolution: resolution,
            frameRate: frameRate,
            withAudio: audioEnabled,
            withMicrophone: microphoneEnabled
        )

        print("✅ Recording started - Region: \(region)")
    }

    private func stopCapture() {
        Task { @MainActor in
            do {
                // Guard against duplicate stop calls
                guard captureEngine != nil else {
                    print("⚠️ AppDelegate: Stop capture called but no active capture engine - ignoring")
                    return
                }

                print("🔄 AppDelegate: Stopping capture...")

                // Stop capture + get output file
                guard let tempVideoURL = try await captureEngine?.stopCapture() else {
                    print("❌ AppDelegate: No video URL returned from capture engine")
                    resetRecordingState()
                    return
                }

                print("✅ AppDelegate: Recording stopped successfully")
                print("📁 Temp file: \(tempVideoURL.path)")

                // Use FileManagerService to save file permanently with actual recording settings
                print("📊 Passing metadata - Resolution: \(recordingResolution?.displayName ?? "nil"), Frame Rate: \(recordingFrameRate?.displayName ?? "nil")")
                let metadata = try await FileManagerService.shared.saveVideoFile(
                    from: tempVideoURL,
                    resolution: recordingResolution ?? .fullHD,
                    frameRate: recordingFrameRate ?? .fps30
                )

                print("✅ AppDelegate: File saved permanently")
                print("  Final location: \(metadata.fileURL.path)")
                print("  Filename: \(metadata.filename)")
                print("  Duration: \(metadata.formattedDuration)")
                print("  Size: \(metadata.formattedFileSize)")
                print("  Resolution: \(metadata.displayResolution)")

                // Notify that a new recording has been saved
                NotificationCenter.default.post(
                    name: .recordingSaved,
                    object: nil,
                    userInfo: ["metadata": metadata]
                )

                // Clean up temp file
                FileManagerService.shared.cleanupTempFile(tempVideoURL)

                // Show REAL preview with video (Day 23)
                openPreviewDialog(with: metadata)

                // Reset state
                resetRecordingState()

                print("🎉 Day 23 Success: Real video preview working!")

            } catch {
                print("❌ AppDelegate: Failed to stop recording: \(error)")
                // Reset state on error
                resetRecordingState()

                // Only show error dialog for critical failures
                let errorMessage = error.localizedDescription
                if !errorMessage.contains("unknown error occurred") {
                    showError("Failed to stop recording: \(errorMessage)")
                }
            }
        }
    }

    private func resetRecordingState() {
        captureEngine = nil
        recordingStartTime = nil
        recordingResolution = nil
        recordingFrameRate = nil
        print("🔄 AppDelegate: Recording state reset")
    }

    private func handleRecordingStarted() {
        print("✅ AppDelegate: Recording started")
        // Update status bar to show recording in progress
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .recordingStarted,
                object: nil
            )
        }
    }

    private func handleRecordingFinished(duration: TimeInterval, fileURL: URL) {
        Task { @MainActor in
            // Use FileManagerService to save file permanently with actual recording settings
            print("✅ Processing completed recording...")
            let metadata = try await FileManagerService.shared.saveVideoFile(
                from: fileURL,
                resolution: recordingResolution ?? .fullHD,
                frameRate: recordingFrameRate ?? .fps30
            )

            print("✅ Recording saved: \(metadata.filename)")

            // Notify that a new recording has been saved
            NotificationCenter.default.post(
                name: .recordingSaved,
                object: nil,
                userInfo: ["metadata": metadata]
            )

            // Clean up temp file
            FileManagerService.shared.cleanupTempFile(fileURL)

            // Show preview
            openPreviewDialog(with: metadata)

            // Reset state
            resetRecordingState()

            // Notify status bar of completion
            NotificationCenter.default.post(
                name: .recordingFinished,
                object: nil,
                userInfo: ["duration": duration]
            )
        }
    }

    private func handleCaptureError(_ error: Error) {
        print("❌ Capture error: \(error)")
        Task { @MainActor in
            showError("Recording error: \(error.localizedDescription)")
            // Stop recording on error
            NotificationCenter.default.post(
                name: .recordingStateChanged,
                object: RecordingState.idle
            )
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Recording Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.2f MB", mb)
    }


    func applicationWillTerminate(_ notification: Notification) {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
        print("👋 MyRec terminating")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Hide dock icon when dashboard closes if setting is enabled
        if SettingsManager.shared.hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
        }
        // Don't quit when windows close (menu bar app)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When dock icon is clicked and no windows are visible, show the dashboard
        if !flag {
            print("🏠 Dock icon clicked - showing dashboard")
            showDashboard()
        }
        return true
    }
}
