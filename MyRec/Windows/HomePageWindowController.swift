//
//  HomePageWindowController.swift
//  MyRec
//
//  Window controller for the home page
//

import Cocoa
import SwiftUI

/// Window controller managing the home page window
class HomePageWindowController: NSWindowController {

    private var homePageView: HomePageView?
    private var viewModel: HomePageViewModel?

    convenience init() {
        // Create the view model
        let viewModel = HomePageViewModel()

        // Create the SwiftUI view
        let homePageView = HomePageView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: homePageView)

        // Create the window
        let window = NSWindow(contentViewController: hostingController)
        window.title = "MyRec"
        window.setContentSize(NSSize(width: 560, height: 600))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.isReleasedWhenClosed = false // Keep window in memory
        window.center()

        // Set minimum size
        window.minSize = NSSize(width: 480, height: 500)

        // Initialize with window
        self.init(window: window)
        self.homePageView = homePageView
        self.viewModel = viewModel
    }

    /// Show the home page window
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Close the home page window
    func hide() {
        window?.orderOut(nil)
    }

    /// Refresh the recordings list
    func refreshRecordings() {
        viewModel?.refresh()
    }
}
