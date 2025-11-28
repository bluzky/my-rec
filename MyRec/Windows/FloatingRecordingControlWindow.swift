//
//  FloatingRecordingControlWindow.swift
//  MyRec
//
//  Window controller for floating recording control
//

import Cocoa
import SwiftUI
import Combine

/// Floating window that displays recording controls at bottom right corner
class FloatingRecordingControlWindow: NSWindow {

    private var viewModel: FloatingRecordingControlViewModel
    private var recordingStateObserver: Any?
    private var countdownObserver: Any?
    private var stopRecordingObserver: Any?
    private var cancelCountdownObserver: Any?
    private let controlSize = NSSize(width: 240, height: 60)
    private let collapsedWidth: CGFloat = 24  // Width when collapsed (just the handle)
    private let margin: CGFloat = 12  // Reduced from 20 to 12
    private var expandedFrame: NSRect = .zero  // Store full-size frame to restore after collapsing
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Create view model
        self.viewModel = FloatingRecordingControlViewModel()

        // Create the SwiftUI view
        let contentView = FloatingRecordingControlView(viewModel: viewModel).applyMonoFont()
        let hostingController = NSHostingController(rootView: contentView)

        // Calculate initial position (default bottom right corner)
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let xPosition = screenFrame.maxX - controlSize.width - margin
        let yPosition = screenFrame.minY + margin

        let initialFrame = NSRect(
            x: xPosition,
            y: yPosition,
            width: controlSize.width,
            height: controlSize.height
        )

        self.expandedFrame = initialFrame

        // Initialize window
        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure window appearance
        self.contentViewController = hostingController
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating  // Float above other windows
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.hasShadow = false  // Shadow handled by SwiftUI view

        // Setup observers
        setupObservers()
        setupBindings()
    }

    private func setupObservers() {
        // Listen for countdown start to show control bar early
        countdownObserver = NotificationCenter.default.addObserver(
            forName: .countdownStarted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Get the selected region from userInfo
            let selectedRegion = notification.userInfo?[NotificationUserInfoKey.selectedRegion] as? CGRect
            self?.positionAndShow(relativeTo: selectedRegion)
        }

        // Listen for recording state changes to show/hide window
        recordingStateObserver = NotificationCenter.default.addObserver(
            forName: .recordingStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let state = notification.object as? RecordingState else { return }

            switch state {
            case .recording:
                // Already shown during countdown, just keep it visible
                break
            case .idle:
                self?.hide()
            case .paused:
                // Keep window visible during pause
                break
            }
        }

        // Listen for stopRecording notification
        stopRecordingObserver = NotificationCenter.default.addObserver(
            forName: .stopRecording,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }

        // Listen for cancelCountdown notification
        cancelCountdownObserver = NotificationCenter.default.addObserver(
            forName: .cancelCountdown,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }

    /// Bind view model changes so window frame matches collapsed state
    private func setupBindings() {
        viewModel.$isCollapsed
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isCollapsed in
                self?.updateWindowSize(collapsed: isCollapsed)
            }
            .store(in: &cancellables)
    }

    /// Position the window intelligently based on selected region and show it
    /// - Parameter selectedRegion: The recording region in screen coordinates (optional)
    private func positionAndShow(relativeTo selectedRegion: CGRect?) {
        guard let selectedRegion = selectedRegion else {
            // No region provided, use default position (bottom right of screen)
            viewModel.shouldShowCollapsible = false
            positionAtDefaultLocation()
            self.orderFrontRegardless()
            print("✅ Floating recording control shown at default bottom right corner")
            return
        }

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let (position, isInside) = calculateOptimalPosition(for: selectedRegion, in: screenFrame)
        viewModel.shouldShowCollapsible = isInside

        setFrameOriginAndRemember(position)
        updateWindowSize(collapsed: viewModel.isCollapsed)
        self.orderFrontRegardless()
        print("✅ Floating recording control positioned at \(position), inside region: \(isInside)")
    }

    /// Calculate the optimal position for the control bar
    /// Priority: Bottom-right → Top-right → Right side → Left side → Default
    /// Returns: (position, isInsideSelectedRegion)
    private func calculateOptimalPosition(for region: CGRect, in screenFrame: CGRect) -> (CGPoint, Bool) {
        // Option 1: Bottom-right of selected region (preferred)
        let bottomRightY = region.minY - controlSize.height - margin
        if bottomRightY >= screenFrame.minY + margin {
            let x = region.maxX - controlSize.width
            // Ensure it doesn't go off screen on the right
            let clampedX = min(max(x, screenFrame.minX + margin), screenFrame.maxX - controlSize.width - margin)
            return (CGPoint(x: clampedX, y: bottomRightY), false)
        }

        // Option 2: Top-right of selected region
        let topRightY = region.maxY + margin
        if topRightY + controlSize.height <= screenFrame.maxY - margin {
            let x = region.maxX - controlSize.width
            let clampedX = min(max(x, screenFrame.minX + margin), screenFrame.maxX - controlSize.width - margin)
            return (CGPoint(x: clampedX, y: topRightY), false)
        }

        // Option 3: Right side of selected region (vertically centered)
        let rightX = region.maxX + margin
        if rightX + controlSize.width <= screenFrame.maxX - margin {
            let y = region.midY - controlSize.height / 2
            let clampedY = min(max(y, screenFrame.minY + margin), screenFrame.maxY - controlSize.height - margin)
            return (CGPoint(x: rightX, y: clampedY), false)
        }

        // Option 4: Left side of selected region (vertically centered)
        let leftX = region.minX - controlSize.width - margin
        if leftX >= screenFrame.minX + margin {
            let y = region.midY - controlSize.height / 2
            let clampedY = min(max(y, screenFrame.minY + margin), screenFrame.maxY - controlSize.height - margin)
            return (CGPoint(x: leftX, y: clampedY), false)
        }

        // Fallback: Position at 1/3 from bottom of screen (INSIDE recording region)
        // Calculate 1/3 height from bottom
        let screenHeight = screenFrame.height
        let yPosition = screenFrame.minY + (screenHeight / 3) - (controlSize.height / 2)

        return (
            CGPoint(
                x: screenFrame.maxX - controlSize.width - margin,  // Right side with margin when expanded
                y: yPosition
            ),
            true  // Mark as inside recording region
        )
    }

    /// Position at default location (bottom right of screen)
    private func positionAtDefaultLocation() {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let position = CGPoint(
            x: screenFrame.maxX - controlSize.width - margin,
            y: screenFrame.minY + margin
        )
        setFrameOriginAndRemember(position)
    }

    /// Show the floating control window
    func show() {
        self.orderFrontRegardless()
        print("✅ Floating recording control shown")
    }

    /// Hide the floating control window
    func hide() {
        self.orderOut(nil)
        print("✅ Floating recording control hidden")
    }

    /// Resize and reposition the window when collapsing/expanding so it does not block clicks
    private func updateWindowSize(collapsed: Bool) {
        if collapsed {
            // Capture latest expanded position before shrinking (in case the user dragged it)
            expandedFrame = frame
            // Shrink width to handle size while keeping right edge anchored
            let newOrigin = CGPoint(x: expandedFrame.maxX - collapsedWidth, y: expandedFrame.origin.y)
            let newFrame = NSRect(origin: newOrigin, size: NSSize(width: collapsedWidth, height: expandedFrame.size.height))
            setFrame(newFrame, display: true, animate: true)
        } else {
            // Restore to stored expanded position and size
            setFrame(expandedFrame, display: true, animate: true)
            // Capture any rounding applied by the system during animation
            expandedFrame = frame
        }
    }

    /// Set frame origin and remember it for future restores when expanded
    private func setFrameOriginAndRemember(_ origin: CGPoint) {
        setFrameOrigin(origin)
        if !viewModel.isCollapsed {
            expandedFrame = NSRect(origin: origin, size: controlSize)
        }
    }

    deinit {
        if let observer = recordingStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = countdownObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = stopRecordingObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = cancelCountdownObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        cancellables.forEach { $0.cancel() }
    }
}
