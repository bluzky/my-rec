//
//  TrimDialogWindowController.swift
//  MyRec
//
//  Window controller for trim dialog
//

import SwiftUI
import AppKit

@MainActor
class TrimDialogWindowController: NSWindowController {

    private var viewModel: TrimDialogViewModel?
    private var closeTrimObserver: NSObjectProtocol?

    convenience init(recording: MockRecording) {
        let window = Self.createWindow()
        self.init(window: window)

        // Create view model
        let viewModel = TrimDialogViewModel(recording: recording)
        self.viewModel = viewModel

        // Create SwiftUI view
        let trimView = TrimDialogView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: trimView)

        // Set content view controller
        window.contentViewController = hostingController

        // Observe close notification
        closeTrimObserver = NotificationCenter.default.addObserver(
            forName: .closeTrim,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.close()
        }

        print("🪟 Trim dialog window created")
    }

    private static func createWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .unifiedTitleAndToolbar],
            backing: .buffered,
            defer: false
        )

        window.title = "Trim Video"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        // Compact title bar settings
        window.titlebarSeparatorStyle = .none

        // Create and configure toolbar for compact appearance
        let toolbar = NSToolbar(identifier: "TrimToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = .small
        window.toolbar = toolbar

        // Make window key and bring to front
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        return window
    }

    @MainActor
    override func close() {
        print("🪟 Trim dialog window closing")

        // Remove observer
        if let observer = closeTrimObserver {
            NotificationCenter.default.removeObserver(observer)
            closeTrimObserver = nil
        }

        // Clean up view model
        viewModel = nil

        super.close()
    }

    deinit {
        print("🗑 Trim dialog window controller deallocated")
    }
}
