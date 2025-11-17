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

    convenience init() {
        // Create the SwiftUI view
        let homePageView = HomePageView()
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
}
