import AppKit
import SwiftUI

/// A transparent, full-screen window that hosts the region selection UI
public class RegionSelectionWindow: NSWindow {

    private let viewModel: RegionSelectionViewModel
    private var keyMonitor: Any?
    private var mouseMonitor: Any?

    /// Access to the view model for external mouse tracking
    public var selectionViewModel: RegionSelectionViewModel {
        return viewModel
    }

    public init() {
        // Get the union of all screen frames for multi-monitor support
        let allScreens = NSScreen.screens
        let totalFrame = allScreens.reduce(CGRect.null) { union, screen in
            union.isEmpty ? screen.frame : union.union(screen.frame)
        }

        // Create view model using the total frame for accurate coordinate conversions
        self.viewModel = RegionSelectionViewModel(screenBounds: totalFrame)

        // Initialize window to cover entire desktop area
        super.init(
            contentRect: totalFrame,
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
        let contentView = RegionSelectionView(viewModel: viewModel) { [weak self] in
            // Closure for when user wants to close the window
            self?.hide()
        }
        self.contentView = NSHostingView(rootView: contentView)

        // Set up escape key monitoring
        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key code
                guard let self = self else { return event }

                // If a region is selected, clear it (back to select mode)
                if self.viewModel.selectedRegion != nil {
                    self.viewModel.selectedRegion = nil
                    self.viewModel.clearWindowHover()
                    // Re-trigger window detection at current mouse position
                    let currentMouseLocation = NSEvent.mouseLocation
                    self.viewModel.updateHoveredWindow(at: currentMouseLocation)
                } else {
                    // If no region selected, close the window
                    self.hide()
                }
                return nil // Consume the event
            }
            return event // Let other key events pass through
        }

        // Set up mouse movement monitoring for window detection
        let mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            // Use NSEvent.mouseLocation which gives global screen coordinates
            let globalScreenPoint = NSEvent.mouseLocation

            // NSEvent.mouseLocation uses bottom-left origin screen coordinates
            // This should match the coordinate system used by CGWindowListCopyWindowInfo
            self?.viewModel.updateHoveredWindow(at: globalScreenPoint)

            return event // Let mouse events pass through
        }

        // Store monitors for cleanup
        self.keyMonitor = keyMonitor
        self.mouseMonitor = mouseMonitor
    }

    /// Show the window and activate the application
    public func show() {
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Note: Microphone monitoring will be started by SettingsBarView.onAppear
        // if permission is granted and toggle is enabled
    }

    /// Hide the window
    public func hide() {
        // No need to stop microphone monitoring - ScreenCaptureKit handles it during recording
        self.orderOut(nil)
    }

    /// Get the selected region from the view model
    public var selectedRegion: CGRect? {
        return viewModel.selectedRegion
    }

    /// Reset the selection state
    public func resetSelection() {
        viewModel.reset()
    }

    /// Clean up event monitors
    public func cleanup() {
        if let keyMonitor = keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let mouseMonitor = mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }

    deinit {
        cleanup()
    }
}
