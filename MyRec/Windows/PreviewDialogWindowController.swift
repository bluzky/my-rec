//  PreviewDialogWindowController.swift
//  MyRec
//
//  Window controller for the preview dialog
//

import Cocoa
import SwiftUI
import AVFoundation

/// Window controller managing the preview dialog window
class PreviewDialogWindowController: NSWindowController, NSWindowDelegate {

    private var previewDialogView: PreviewDialogView?
    private var viewModel: PreviewDialogViewModel?

    convenience init(recording: VideoMetadata) {
        // Create the view model
        let viewModel = PreviewDialogViewModel(recording: recording)

        // Create the SwiftUI view
        let previewDialogView = PreviewDialogView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: previewDialogView.applyMonoFont())

        // Create the window
        let window = NSWindow(contentViewController: hostingController)
        window.title = recording.filename
        // Default window size tuned to 16:10 content area
        window.setContentSize(NSSize(width: 960, height: 600))
        window.styleMask = [NSWindow.StyleMask.titled, NSWindow.StyleMask.closable, NSWindow.StyleMask.resizable, NSWindow.StyleMask.miniaturizable]
        window.isReleasedWhenClosed = true // Release when closed
        window.center()
        window.title = recording.filename

        // Set minimum size
        window.minSize = NSSize(width: 600, height: 400)

        // Initialize with window
        self.init(window: window)
        self.previewDialogView = previewDialogView
        self.viewModel = viewModel

        // Set callback to close window when requested
        viewModel.setOnCloseWindow { [weak self] in
            self?.close()
        }

        // Set self as window delegate to detect when it closes
        window.delegate = self
    }

    /// Show the preview dialog window
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Close the preview dialog window
    override func close() {
        window?.close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        print("🗑 Preview dialog window closing - stopping playback")

        // Stop playback immediately when window closes
        viewModel?.player?.pause()
        viewModel?.player = nil

        // Clean up references
        previewDialogView = nil
        viewModel = nil

        // Notify AppDelegate to release its reference
        NotificationCenter.default.post(name: .previewDialogClosed, object: nil)
    }
}
