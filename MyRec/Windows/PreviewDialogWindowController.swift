//
//  PreviewDialogWindowController.swift
//  MyRec
//
//  Window controller for the preview dialog
//

import Cocoa
import SwiftUI

/// Window controller managing the preview dialog window
class PreviewDialogWindowController: NSWindowController {

    private var previewDialogView: PreviewDialogView?
    private var viewModel: PreviewDialogViewModel?

    convenience init(recording: MockRecording) {
        // Create the view model
        let viewModel = PreviewDialogViewModel(recording: recording)

        // Create the SwiftUI view
        let previewDialogView = PreviewDialogView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: previewDialogView)

        // Create the window
        let window = NSWindow(contentViewController: hostingController)
        window.title = recording.filename
        window.setContentSize(NSSize(width: 900, height: 600))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.isReleasedWhenClosed = true // Release when closed
        window.center()

        // Set minimum size
        window.minSize = NSSize(width: 800, height: 500)

        // Initialize with window
        self.init(window: window)
        self.previewDialogView = previewDialogView
        self.viewModel = viewModel
    }

    convenience init(metadata: VideoMetadata) {
        // Create the view model with real metadata
        let viewModel = PreviewDialogViewModel(metadata: metadata)

        // Create the SwiftUI view
        let previewDialogView = PreviewDialogView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: previewDialogView)

        // Create the window
        let window = NSWindow(contentViewController: hostingController)
        window.title = metadata.filename
        window.setContentSize(NSSize(width: 900, height: 600))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.isReleasedWhenClosed = true // Release when closed
        window.center()

        // Set minimum size
        window.minSize = NSSize(width: 800, height: 500)

        // Initialize with window
        self.init(window: window)
        self.previewDialogView = previewDialogView
        self.viewModel = viewModel
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
}
