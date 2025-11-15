import SwiftUI
import Combine

class RegionSelectionViewModel: ObservableObject {
    @Published var selectedRegion: CGRect?
    @Published var isDragging = false
    @Published var isResizing = false

    private var dragStartPoint: CGPoint?
    private let screenBounds: CGRect
    private let minimumSize: CGSize = CGSize(width: 100, height: 100)

    init(screenBounds: CGRect = NSScreen.main?.frame ?? .zero) {
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

        selectedRegion = constrainToScreen(screenRect)
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

    /// Convert SwiftUI coordinates (top-left origin) to screen coordinates (bottom-left origin)
    internal func convertToScreenCoordinates(_ rect: CGRect) -> CGRect {
        // Use screenBounds instead of NSScreen.main to support testing
        let screenHeight = screenBounds.height

        // SwiftUI origin is top-left, screen coordinates are bottom-left
        let flippedY = screenHeight - rect.origin.y - rect.height

        return CGRect(
            x: rect.origin.x,
            y: flippedY,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: - Constraint Logic

    /// Constrain rectangle to screen bounds
    internal func constrainToScreen(_ rect: CGRect) -> CGRect {
        var constrainedRect = rect

        // First, constrain origin to be non-negative
        constrainedRect.origin.x = max(0, rect.origin.x)
        constrainedRect.origin.y = max(0, rect.origin.y)

        // Then constrain size to fit within screen bounds from the origin
        constrainedRect.size.width = min(rect.width, screenBounds.width - constrainedRect.origin.x)
        constrainedRect.size.height = min(rect.height, screenBounds.height - constrainedRect.origin.y)

        return constrainedRect
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

    // MARK: - State Management

    /// Reset all state
    func reset() {
        selectedRegion = nil
        isDragging = false
        isResizing = false
        dragStartPoint = nil
    }
}
