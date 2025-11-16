//
//  SettingsWindowController.swift
//  MyRec
//
//  Window controller for the Settings dialog
//

import AppKit
import SwiftUI

public class SettingsWindowController {
    private var window: NSWindow?
    private let settingsManager: SettingsManager

    public init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    public func show() {
        // Reuse existing window if available
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create new window
        let contentView = SettingsDialogView(settingsManager: settingsManager)
        let hostingController = NSHostingController(rootView: contentView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Settings"
        newWindow.styleMask = [.titled, .closable, .fullSizeContentView]
        newWindow.titlebarAppearsTransparent = false
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        newWindow.setFrameAutosaveName("SettingsWindow")
        newWindow.isMovableByWindowBackground = true

        // Remove minimize and zoom buttons
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true

        // Set window level to float above other windows
        newWindow.level = .floating

        // Show window
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = newWindow
    }

    public func close() {
        window?.close()
    }
}
