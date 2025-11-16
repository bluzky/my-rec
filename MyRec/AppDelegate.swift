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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Initialize status bar
        statusBarController = StatusBarController()

        // Initialize settings window controller
        settingsWindowController = SettingsWindowController(settingsManager: SettingsManager.shared)

        // Set up notification observers
        setupNotificationObservers()

        // Add test menu item to demonstrate system tray
        addTestMenuItems()

        print("✅ MyRec launched successfully")
        print("✅ Status bar controller initialized")
        print("✅ Settings window controller initialized")
        print("✅ Notification observers set up")
        print("💡 Test: Right-click status bar to see demo options")
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

        print("✅ Registered observer for startRecording notification")
        print("✅ Registered observer for openSettings notification")
    }

    private func addTestMenuItems() {
        // Add demo items to status bar menu for testing system tray states
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let menu = self.statusBarController?.statusItem?.menu {
                // Insert separator and demo items at the beginning
                menu.insertItem(NSMenuItem.separator(), at: 0)

                let demoRecording = NSMenuItem(
                    title: "🎬 Demo: Start Recording",
                    action: #selector(self.demoStartRecording),
                    keyEquivalent: ""
                )
                demoRecording.target = self
                menu.insertItem(demoRecording, at: 0)

                let demoPause = NSMenuItem(
                    title: "⏸ Demo: Pause Recording",
                    action: #selector(self.demoPauseRecording),
                    keyEquivalent: ""
                )
                demoPause.target = self
                menu.insertItem(demoPause, at: 1)

                let demoStop = NSMenuItem(
                    title: "⏹ Demo: Stop Recording",
                    action: #selector(self.demoStopRecording),
                    keyEquivalent: ""
                )
                demoStop.target = self
                menu.insertItem(demoStop, at: 2)

                menu.insertItem(NSMenuItem.separator(), at: 3)
            }
        }
    }

    @objc private func handleStartRecording() {
        print("📱 Record Screen clicked - showing region selection overlay")
        showRegionSelection()
    }

    @objc private func handleOpenSettings() {
        print("⚙️ Settings clicked - showing settings dialog")
        showSettings()
    }

    private func showRegionSelection() {
        // Hide existing window if any
        regionSelectionWindow?.close()

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

    // MARK: - Demo Methods for System Tray Testing

    @objc private func demoStartRecording() {
        print("🎬 Demo: Starting recording - posting notification")
        statusBarController?.simulateRecordingState(.recording(startTime: Date()))
    }

    @objc private func demoPauseRecording() {
        print("⏸ Demo: Pausing recording - posting notification")
        statusBarController?.simulateRecordingState(.paused(elapsedTime: 15.0))
    }

    @objc private func demoStopRecording() {
        print("⏹ Demo: Stopping recording - posting notification")
        statusBarController?.simulateRecordingState(.idle)
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
