import AppKit
import SwiftUI

/// A transparent, full-screen window that hosts the region selection UI
public class RegionSelectionWindow: NSWindow {

    private let viewModel: RegionSelectionViewModel
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var dragMonitor: Any?
    private var recordingStateObserver: Any?

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
        self.hasShadow = false // Disable shadow to prevent ghost artifacts

        // Setup SwiftUI view
        setupContentView()
        restoreLastManualRegion()
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

                // Check if cancellation is allowed based on selection mode
                guard self.viewModel.canCancelSelection() else {
                    // In screen mode, ESC is disabled
                    return nil // Consume the event but do nothing
                }

                // If a region is selected, clear it (back to select mode)
                if self.viewModel.selectedRegion != nil {
                    self.viewModel.selectedRegion = nil
                    self.viewModel.clearWindowHover()
                    // Re-trigger window detection at current mouse position (for window mode)
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

        let dragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            let globalScreenPoint = NSEvent.mouseLocation
            self?.viewModel.updateHoveredWindow(at: globalScreenPoint)
            return event
        }

        // Store monitors for cleanup
        self.keyMonitor = keyMonitor
        self.mouseMonitor = mouseMonitor
        self.dragMonitor = dragMonitor

        // Listen for recording state changes to enable/disable mouse passthrough
        recordingStateObserver = NotificationCenter.default.addObserver(
            forName: .recordingStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let state = notification.object as? RecordingState else { return }

            switch state {
            case .recording:
                // During recording, allow mouse events to pass through
                self?.ignoresMouseEvents = true
                print("🖱 Window now ignores mouse events - user can interact with apps")

                // Force window invalidation to clear ghost artifacts
                self?.invalidateShadow()
                self?.contentView?.setNeedsDisplay(self?.contentView?.bounds ?? .zero)
            case .idle, .paused:
                // Not recording, capture mouse events again
                self?.ignoresMouseEvents = false
                print("🖱 Window captures mouse events - selection mode")
            }
        }
    }

    private func restoreLastManualRegion() {
        guard SettingsManager.shared.rememberLastManualRegion else { return }
        guard let lastRegion = RegionSelectionStore.shared.lastManualRegion() else { return }

        // Clamp to current screens to avoid restoring off-screen rectangles
        let constrained = viewModel.constrainToScreen(lastRegion)
        viewModel.selectionMode = .region
        viewModel.selectedRegion = constrained

        print("↩️ Restored last manual region: \(constrained)")
    }

    /// Show the window and activate the application
    public func show() {
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        viewModel.updateHoveredWindow(at: NSEvent.mouseLocation)

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
        if let dragMonitor = dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
            self.dragMonitor = nil
        }
        if let observer = recordingStateObserver {
            NotificationCenter.default.removeObserver(observer)
            self.recordingStateObserver = nil
        }
    }

    deinit {
        cleanup()
    }
}
