import SwiftUI
import Combine

public class RegionSelectionViewModel: ObservableObject {
    @Published var selectedRegion: CGRect?
    @Published var isDragging = false
    @Published var isResizing = false
    @Published var hoveredWindow: WindowInfo?
    @Published var isHoveringOverWindow = false

    private var dragStartPoint: CGPoint?
    private var resizeStartPoint: CGPoint?
    private var resizeStartRegion: CGRect?
    let screenBounds: CGRect // Coordinate space covered by the overlay window
    private let minimumSize: CGSize = CGSize(width: 50, height: 50)
    private let windowDetectionService = WindowDetectionService.shared

    public init(screenBounds: CGRect = NSScreen.main?.frame ?? .zero) {
        self.screenBounds = screenBounds
    }

    // MARK: - Drag Handling

    /// Handle drag gesture to create selection rectangle
    func handleDragChanged(_ value: DragGesture.Value) {
        isDragging = true

        if dragStartPoint == nil {
            dragStartPoint = value.startLocation
        }

        guard let startPoint = dragStartPoint else { return }

        // Calculate rectangle from start to current point
        let currentPoint = value.location
        let origin = CGPoint(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y)
        )
        let size = CGSize(
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )

        // Convert to screen coordinates (SwiftUI uses flipped coordinates)
        let screenRect = convertToScreenCoordinates(
            CGRect(origin: origin, size: size)
        )

        // Apply snapping and constraining
        selectedRegion = snapToEdges(constrainToScreen(screenRect))
    }

    /// Handle drag gesture end
    func handleDragEnded(_ value: DragGesture.Value) {
        isDragging = false
        dragStartPoint = nil

        // Enforce minimum size
        if let region = selectedRegion {
            if region.width < minimumSize.width || region.height < minimumSize.height {
                selectedRegion = nil
            }
        }
    }

    // MARK: - Coordinate Conversion

    /// Convert SwiftUI view coordinates to global screen coordinates
    internal func convertToScreenCoordinates(_ rect: CGRect) -> CGRect {
        return CGRect(
            x: rect.origin.x + screenBounds.origin.x,
            y: screenBounds.maxY - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: - Constraint Logic

    /// Constrain rectangle to screen bounds
    internal func constrainToScreen(_ rect: CGRect) -> CGRect {
        var constrainedRect = rect

        let minX = screenBounds.minX
        let minY = screenBounds.minY
        let maxX = screenBounds.maxX
        let maxY = screenBounds.maxY

        // Constrain origin within bounds
        constrainedRect.origin.x = max(minX, rect.origin.x)
        constrainedRect.origin.y = max(minY, rect.origin.y)

        // Constrain size so the rect stays within bounds
        constrainedRect.size.width = min(rect.width, maxX - constrainedRect.origin.x)
        constrainedRect.size.height = min(rect.height, maxY - constrainedRect.origin.y)

        return constrainedRect
    }

    /// Snap rectangle edges to screen bounds when close enough (magnetic effect)
    internal func snapToEdges(_ rect: CGRect, threshold: CGFloat = 15.0) -> CGRect {
        var snappedRect = rect

        let minX = screenBounds.minX
        let minY = screenBounds.minY
        let maxX = screenBounds.maxX
        let maxY = screenBounds.maxY

        // Snap left edge
        if abs(snappedRect.minX - minX) <= threshold {
            snappedRect.origin.x = minX
        }

        // Snap right edge
        if abs(snappedRect.maxX - maxX) <= threshold {
            snappedRect.origin.x = maxX - snappedRect.width
        }

        // Snap top edge
        if abs(snappedRect.maxY - maxY) <= threshold {
            snappedRect.origin.y = maxY - snappedRect.height
        }

        // Snap bottom edge
        if abs(snappedRect.minY - minY) <= threshold {
            snappedRect.origin.y = minY
        }

        return snappedRect
    }

    // MARK: - Multi-Monitor Support

    /// Get the display that contains the specified region
    func getDisplayForRegion(_ region: CGRect) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.intersects(region) {
                return screen
            }
        }
        return NSScreen.main
    }

    // MARK: - Resize Handling

    /// Handle resize gesture for a specific handle
    func handleResize(_ handle: ResizeHandle, dragValue: DragGesture.Value) {
        isResizing = true

        // Store initial state on first drag event
        if resizeStartPoint == nil {
            resizeStartPoint = dragValue.startLocation
            resizeStartRegion = selectedRegion
        }

        guard let startPoint = resizeStartPoint,
              let region = resizeStartRegion else { return }

        let rawDelta = CGPoint(
            x: dragValue.location.x - startPoint.x,
            y: dragValue.location.y - startPoint.y
        )

        // Convert SwiftUI (top-left origin) delta to screen-space delta
        let screenDelta = CGPoint(x: rawDelta.x, y: -rawDelta.y)

        let updatedRegion = resizedRegion(from: region, handle: handle, delta: screenDelta)

        // Enforce minimum size and constrain to screen with snapping
        if updatedRegion.width >= minimumSize.width && updatedRegion.height >= minimumSize.height {
            selectedRegion = snapToEdges(constrainToScreen(updatedRegion))
        }
    }

    /// Calculate the updated region when a resize handle moves by a delta
    internal func resizedRegion(from region: CGRect, handle: ResizeHandle, delta: CGPoint) -> CGRect {
        var minX = region.minX
        var maxX = region.maxX
        var minY = region.minY
        var maxY = region.maxY

        switch handle {
        case .topLeft:
            minX += delta.x
            maxY += delta.y

        case .topCenter:
            maxY += delta.y

        case .topRight:
            maxX += delta.x
            maxY += delta.y

        case .middleLeft:
            minX += delta.x

        case .middleRight:
            maxX += delta.x

        case .bottomLeft:
            minX += delta.x
            minY += delta.y

        case .bottomCenter:
            minY += delta.y

        case .bottomRight:
            maxX += delta.x
            minY += delta.y
        }

        return CGRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY)
        )
    }

    /// Determine the final region after a resize, enforcing the minimum size
    internal func validatedRegionAfterResize(originalRegion: CGRect?, updatedRegion: CGRect?) -> CGRect? {
        guard let updatedRegion = updatedRegion else {
            return originalRegion
        }

        if updatedRegion.width < minimumSize.width || updatedRegion.height < minimumSize.height {
            return originalRegion
        }

        return updatedRegion
    }

    /// Handle resize gesture end
    func handleResizeEnded(_ handle: ResizeHandle, dragValue: DragGesture.Value) {
        let originalRegion = resizeStartRegion
        isResizing = false
        resizeStartPoint = nil
        resizeStartRegion = nil

        // Enforce minimum size
        selectedRegion = validatedRegionAfterResize(
            originalRegion: originalRegion,
            updatedRegion: selectedRegion
        )
    }

    // MARK: - Window Detection

    /// Check for window under cursor and update hover state
    func updateHoveredWindow(at location: CGPoint) {
        // Don't detect windows during drag/resize operations
        guard !isDragging && !isResizing else {
            hoveredWindow = nil
            isHoveringOverWindow = false
            return
        }

        // Don't detect windows when a region is already selected
        // User must press ESC to cancel selection first
        guard selectedRegion == nil else {
            hoveredWindow = nil
            isHoveringOverWindow = false
            return
        }

        let window = windowDetectionService.getWindowAt(point: location)

        if let window = window, window.isUserWindow {
            if hoveredWindow?.windowNumber != window.windowNumber {
                hoveredWindow = window
                isHoveringOverWindow = true
            }
        } else {
            hoveredWindow = nil
            isHoveringOverWindow = false
        }
    }

    /// Select the currently hovered window
    func selectHoveredWindow() {
        guard let window = hoveredWindow else { return }

        // Window bounds from CGWindowListCopyWindowInfo are already in screen coordinates
        // (bottom-left origin), which is the same format that selectedRegion uses
        selectedRegion = constrainToScreen(window.bounds)

        // Clear window hover state since we're now in manual selection mode
        hoveredWindow = nil
        isHoveringOverWindow = false
    }

    /// Clear window hover state
    func clearWindowHover() {
        hoveredWindow = nil
        isHoveringOverWindow = false
    }

    // MARK: - State Management

    /// Reset all state
    func reset() {
        selectedRegion = nil
        isDragging = false
        isResizing = false
        isHoveringOverWindow = false
        hoveredWindow = nil
        dragStartPoint = nil
        resizeStartPoint = nil
        resizeStartRegion = nil
    }
}
