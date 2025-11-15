import AppKit
import SwiftUI

/// A transparent, full-screen window that hosts the region selection UI
class RegionSelectionWindow: NSWindow {

    private let viewModel: RegionSelectionViewModel

    init() {
        // Get the main screen (or first screen if main is unavailable)
        let mainScreen = NSScreen.main ?? NSScreen.screens[0]

        // Create view model with screen bounds
        self.viewModel = RegionSelectionViewModel(screenBounds: mainScreen.frame)

        // Initialize window with full-screen borderless style
        super.init(
            contentRect: mainScreen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure window appearance
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating // Float above other windows
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false

        // Setup SwiftUI view
        setupContentView()
    }

    private func setupContentView() {
        let contentView = RegionSelectionView(viewModel: viewModel)
        self.contentView = NSHostingView(rootView: contentView)
    }

    /// Show the window and activate the application
    func show() {
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Hide the window
    func hide() {
        self.orderOut(nil)
    }

    /// Get the selected region from the view model
    var selectedRegion: CGRect? {
        return viewModel.selectedRegion
    }

    /// Reset the selection state
    func resetSelection() {
        viewModel.reset()
    }
}
