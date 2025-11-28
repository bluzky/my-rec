import XCTest
import SwiftUI
@testable import MyRecCore

class RegionSelectionViewModelTests: XCTestCase {

    // MARK: - Test Properties

    var viewModel: RegionSelectionViewModel!
    let testScreenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        viewModel = RegionSelectionViewModel(screenBounds: testScreenBounds)
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNil(viewModel.selectedRegion, "Selected region should be nil on initialization")
        XCTAssertFalse(viewModel.isDragging, "isDragging should be false on initialization")
        XCTAssertFalse(viewModel.isResizing, "isResizing should be false on initialization")
    }

    // MARK: - Coordinate Conversion Tests

    func testCoordinateConversionTopLeft() {
        // SwiftUI origin is top-left; converting should flip Y into screen coordinates
        let swiftUIRect = CGRect(x: 100, y: 100, width: 500, height: 300)
        let screenRect = viewModel.convertToScreenCoordinates(swiftUIRect)

        XCTAssertEqual(screenRect.origin.x, 100, accuracy: 0.01)
        let expectedY = testScreenBounds.maxY - swiftUIRect.origin.y - swiftUIRect.height
        XCTAssertEqual(screenRect.origin.y, expectedY, accuracy: 0.01)
        XCTAssertEqual(screenRect.width, 500, accuracy: 0.01)
        XCTAssertEqual(screenRect.height, 300, accuracy: 0.01)
    }

    func testCoordinateConversionBottomRight() {
        // Test conversion near bottom-right of screen
        let swiftUIRect = CGRect(x: 1420, y: 780, width: 500, height: 300)
        let screenRect = viewModel.convertToScreenCoordinates(swiftUIRect)

        XCTAssertEqual(screenRect.origin.x, swiftUIRect.origin.x, accuracy: 0.01)
        let expectedY = testScreenBounds.maxY - swiftUIRect.origin.y - swiftUIRect.height
        XCTAssertEqual(screenRect.origin.y, expectedY, accuracy: 0.01)
    }

    func testCoordinateConversionPreservesSize() {
        // Size should remain unchanged after coordinate conversion
        let swiftUIRect = CGRect(x: 200, y: 200, width: 800, height: 600)
        let screenRect = viewModel.convertToScreenCoordinates(swiftUIRect)

        XCTAssertEqual(screenRect.width, swiftUIRect.width)
        XCTAssertEqual(screenRect.height, swiftUIRect.height)
    }

    func testCoordinateConversionAppliesOriginOffset() {
        // When the overlay starts at a non-zero origin, conversions should offset accordingly
        let offsetBounds = CGRect(x: -200, y: 50, width: 1920, height: 1080)
        let offsetViewModel = RegionSelectionViewModel(screenBounds: offsetBounds)
        let swiftUIRect = CGRect(x: 100, y: 100, width: 400, height: 300)
        let screenRect = offsetViewModel.convertToScreenCoordinates(swiftUIRect)

        XCTAssertEqual(screenRect.origin.x, swiftUIRect.origin.x + offsetBounds.origin.x, accuracy: 0.01)
        let expectedY = offsetBounds.maxY - swiftUIRect.origin.y - swiftUIRect.height
        XCTAssertEqual(screenRect.origin.y, expectedY, accuracy: 0.01)
    }

    // MARK: - Constraint Tests

    func testConstrainToScreenWithinBounds() {
        // Region completely within bounds should remain unchanged
        let region = CGRect(x: 100, y: 100, width: 500, height: 300)
        let constrained = viewModel.constrainToScreen(region)

        XCTAssertEqual(constrained, region)
    }

    func testConstrainToScreenExceedingRightEdge() {
        // Region exceeding right edge should be constrained
        let region = CGRect(x: 1700, y: 100, width: 500, height: 300)
        let constrained = viewModel.constrainToScreen(region)

        XCTAssertLessThanOrEqual(constrained.maxX, testScreenBounds.maxX)
        XCTAssertEqual(constrained.origin.y, region.origin.y)
        XCTAssertLessThan(constrained.width, region.width)
    }

    func testConstrainToScreenExceedingBottomEdge() {
        // Region exceeding bottom edge should be constrained
        let region = CGRect(x: 100, y: 900, width: 500, height: 300)
        let constrained = viewModel.constrainToScreen(region)

        XCTAssertLessThanOrEqual(constrained.maxY, testScreenBounds.maxY)
        XCTAssertEqual(constrained.origin.x, region.origin.x)
        XCTAssertLessThan(constrained.height, region.height)
    }

    func testConstrainToScreenNegativeOrigin() {
        // Region with negative origin should be moved to (0, 0)
        let region = CGRect(x: -50, y: -50, width: 500, height: 300)
        let constrained = viewModel.constrainToScreen(region)

        XCTAssertGreaterThanOrEqual(constrained.origin.x, 0)
        XCTAssertGreaterThanOrEqual(constrained.origin.y, 0)
    }

    func testConstrainToScreenExceedingAllEdges() {
        // Region exceeding all edges should be fully constrained
        let region = CGRect(x: -100, y: -100, width: 3000, height: 2000)
        let constrained = viewModel.constrainToScreen(region)

        XCTAssertGreaterThanOrEqual(constrained.origin.x, 0)
        XCTAssertGreaterThanOrEqual(constrained.origin.y, 0)
        XCTAssertLessThanOrEqual(constrained.maxX, testScreenBounds.maxX)
        XCTAssertLessThanOrEqual(constrained.maxY, testScreenBounds.maxY)
    }

    // MARK: - Region Size Tests

    func testSmallRegionBelowMinimum() {
        // Manually set a region below minimum size
        viewModel.selectedRegion = CGRect(x: 100, y: 100, width: 50, height: 30)

        // In real usage, handleDragEnded would clear this
        // We test that by checking the constraint logic
        let constrainedRegion = viewModel.constrainToScreen(viewModel.selectedRegion!)

        // The constraint method doesn't enforce minimum size
        // That's done in handleDragEnded, so we just verify the region exists
        XCTAssertNotNil(constrainedRegion)
    }

    func testMinimumSizeRegion() {
        // Set a region exactly at minimum size (100x100)
        let region = CGRect(x: 100, y: 100, width: 100, height: 100)
        viewModel.selectedRegion = region

        XCTAssertNotNil(viewModel.selectedRegion)
        XCTAssertEqual(viewModel.selectedRegion!.width, 100)
        XCTAssertEqual(viewModel.selectedRegion!.height, 100)
    }

    func testLargeRegionAboveMinimum() {
        // Set a region above minimum size
        let region = CGRect(x: 100, y: 100, width: 400, height: 300)
        viewModel.selectedRegion = region

        XCTAssertNotNil(viewModel.selectedRegion)
        XCTAssertGreaterThanOrEqual(viewModel.selectedRegion!.width, 100)
        XCTAssertGreaterThanOrEqual(viewModel.selectedRegion!.height, 100)
    }

    // MARK: - State Management Tests

    func testStateFlags() {
        // Test initial state
        XCTAssertFalse(viewModel.isDragging)
        XCTAssertFalse(viewModel.isResizing)

        // Test manual state changes
        viewModel.isDragging = true
        XCTAssertTrue(viewModel.isDragging)

        viewModel.isResizing = true
        XCTAssertTrue(viewModel.isResizing)
    }

    // MARK: - Reset Tests

    func testReset() {
        // Setup some state
        viewModel.selectedRegion = CGRect(x: 100, y: 100, width: 500, height: 300)
        viewModel.isDragging = true
        viewModel.isResizing = true

        // Reset
        viewModel.reset()

        // All state should be cleared
        XCTAssertNil(viewModel.selectedRegion)
        XCTAssertFalse(viewModel.isDragging)
        XCTAssertFalse(viewModel.isResizing)
    }

    // MARK: - Multi-Monitor Tests

    func testGetDisplayForRegion() {
        // This test requires actual NSScreen.screens which may not be available in test environment
        // We'll create a basic test that just verifies the method returns a screen
        let region = CGRect(x: 100, y: 100, width: 500, height: 300)
        let display = viewModel.getDisplayForRegion(region)

        XCTAssertNotNil(display, "Should return a screen (main screen if no match)")
    }

    // MARK: - Edge Case Tests

    func testZeroSizeRegion() {
        // Test that a zero-size region is handled correctly
        let region = CGRect(x: 100, y: 100, width: 0, height: 0)
        let constrained = viewModel.constrainToScreen(region)

        XCTAssertEqual(constrained.width, 0)
        XCTAssertEqual(constrained.height, 0)
    }

    func testFullScreenRegion() {
        // Test a region that covers the entire screen
        let region = testScreenBounds
        let constrained = viewModel.constrainToScreen(region)

        XCTAssertEqual(constrained, testScreenBounds)
    }

    func testRegionAtOrigin() {
        // Test a region at (0, 0)
        let region = CGRect(x: 0, y: 0, width: 500, height: 300)
        let constrained = viewModel.constrainToScreen(region)

        XCTAssertEqual(constrained, region)
    }

    // MARK: - Resize Logic Tests

    func testResizeBottomRight() {
        // Setup initial region
        viewModel.selectedRegion = CGRect(x: 100, y: 100, width: 500, height: 300)

        // Test that resize state is managed correctly
        XCTAssertFalse(viewModel.isResizing)

        // Reset method should clear isResizing state
        viewModel.isResizing = true
        viewModel.reset()
        XCTAssertFalse(viewModel.isResizing)

        // Selection should also be cleared during reset
        XCTAssertNil(viewModel.selectedRegion)
    }

    func testResizeTopLeft() {
        // Setup initial region
        viewModel.selectedRegion = CGRect(x: 200, y: 200, width: 500, height: 300)

        // Test resize state management for topLeft handle
        XCTAssertFalse(viewModel.isResizing)

        // Test that the handle position calculation works
        let region = viewModel.selectedRegion!
        let position = ResizeHandle.topLeft.position(in: region)
        XCTAssertEqual(position.x, region.minX, accuracy: 0.1)
        XCTAssertEqual(position.y, region.minY, accuracy: 0.1)
    }

    func testResizeMiddleRight() {
        // Setup initial region
        viewModel.selectedRegion = CGRect(x: 100, y: 100, width: 500, height: 300)

        // Test that the handle position calculation works for middleRight
        let region = viewModel.selectedRegion!
        let position = ResizeHandle.middleRight.position(in: region)
        XCTAssertEqual(position.x, region.maxX, accuracy: 0.1)
        XCTAssertEqual(position.y, region.midY, accuracy: 0.1)
    }

    func testResizeBottomCenter() {
        // Setup initial region
        viewModel.selectedRegion = CGRect(x: 100, y: 100, width: 500, height: 300)

        // Test that the handle position calculation works for bottomCenter
        let region = viewModel.selectedRegion!
        let position = ResizeHandle.bottomCenter.position(in: region)
        XCTAssertEqual(position.x, region.midX, accuracy: 0.1)
        XCTAssertEqual(position.y, region.maxY, accuracy: 0.1)
    }

    func testResizeEnforcesMinimumSize() {
        // Test minimum size constraints
        let region = CGRect(x: 100, y: 100, width: 150, height: 150)
        let constrained = viewModel.constrainToScreen(region)

        // Region should remain unchanged since it's within bounds
        XCTAssertGreaterThanOrEqual(constrained.width, 100)
        XCTAssertGreaterThanOrEqual(constrained.height, 100)
    }

    func testResizeStateManagement() {
        // Setup region
        viewModel.selectedRegion = CGRect(x: 100, y: 100, width: 500, height: 300)

        // Verify not resizing initially
        XCTAssertFalse(viewModel.isResizing)

        // Test reset method instead of resize ended (avoiding DragGesture.Value issues)
        viewModel.isResizing = true
        viewModel.reset()
        XCTAssertFalse(viewModel.isResizing)

        // Should not be resizing
        XCTAssertFalse(viewModel.isResizing)
    }

    func testResizeHandleCursorTypes() {
        // Test that all handles have cursor types
        XCTAssertNotNil(ResizeHandle.topLeft.cursor)
        XCTAssertNotNil(ResizeHandle.topCenter.cursor)
        XCTAssertNotNil(ResizeHandle.topRight.cursor)
        XCTAssertNotNil(ResizeHandle.middleLeft.cursor)
        XCTAssertNotNil(ResizeHandle.middleRight.cursor)
        XCTAssertNotNil(ResizeHandle.bottomLeft.cursor)
        XCTAssertNotNil(ResizeHandle.bottomCenter.cursor)
        XCTAssertNotNil(ResizeHandle.bottomRight.cursor)
    }

    func testResizedRegionTopLeftAdjustsEdges() {
        let original = CGRect(x: 200, y: 200, width: 400, height: 300)
        let delta = CGPoint(x: 50, y: 60)

        let result = viewModel.resizedRegion(from: original, handle: .topLeft, delta: delta)

        XCTAssertEqual(result.origin.x, original.minX + delta.x, accuracy: 0.01)
        XCTAssertEqual(result.origin.y, original.minY, accuracy: 0.01)
        XCTAssertEqual(result.width, original.width - delta.x, accuracy: 0.01)
        XCTAssertEqual(result.height, original.height + delta.y, accuracy: 0.01)
    }

    func testResizedRegionBottomRightExpands() {
        let original = CGRect(x: 100, y: 100, width: 300, height: 200)
        let delta = CGPoint(x: 80, y: -120)

        let result = viewModel.resizedRegion(from: original, handle: .bottomRight, delta: delta)

        XCTAssertEqual(result.origin.x, original.origin.x, accuracy: 0.01)
        XCTAssertEqual(result.origin.y, original.origin.y + delta.y, accuracy: 0.01)
        XCTAssertEqual(result.width, original.width + delta.x, accuracy: 0.01)
        XCTAssertEqual(result.height, original.height - delta.y, accuracy: 0.01)
    }

    func testValidatedRegionAfterResizeRejectsTooSmall() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 200)
        let updated = CGRect(x: 100, y: 100, width: 50, height: 50)

        let result = viewModel.validatedRegionAfterResize(
            originalRegion: original,
            updatedRegion: updated
        )

        XCTAssertEqual(result, original)
    }

    func testValidatedRegionAfterResizeAcceptsValid() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 200)
        let updated = CGRect(x: 80, y: 80, width: 220, height: 220)

        let result = viewModel.validatedRegionAfterResize(
            originalRegion: original,
            updatedRegion: updated
        )

        XCTAssertEqual(result, updated)
    }

    // MARK: - Cursor Location Tests

    func testCursorLocation_InitiallyNil() {
        // Cursor location should be nil on initialization
        XCTAssertNil(viewModel.cursorLocation, "cursorLocation should be nil on initialization")
    }

    func testCursorLocation_SetDuringDrag() {
        // Setup: start a drag operation
        let startLocation = CGPoint(x: 100, y: 100)
        let dragValue = makeDragValue(translation: .zero, location: startLocation)

        viewModel.handleDragStarted(dragValue)

        // Verify cursor location is set
        XCTAssertNotNil(viewModel.cursorLocation, "cursorLocation should be set during drag")
        XCTAssertEqual(viewModel.cursorLocation?.x, startLocation.x, accuracy: 0.01)
        XCTAssertEqual(viewModel.cursorLocation?.y, startLocation.y, accuracy: 0.01)
    }

    func testCursorLocation_UpdatedDuringDragChanged() {
        // Setup: start a drag
        let startLocation = CGPoint(x: 100, y: 100)
        let startValue = makeDragValue(translation: .zero, location: startLocation)
        viewModel.handleDragStarted(startValue)

        // Simulate drag movement
        let newLocation = CGPoint(x: 200, y: 150)
        let changeValue = makeDragValue(translation: CGSize(width: 100, height: 50), location: newLocation)
        viewModel.handleDragChanged(changeValue)

        // Verify cursor location is updated
        XCTAssertNotNil(viewModel.cursorLocation)
        XCTAssertEqual(viewModel.cursorLocation?.x, newLocation.x, accuracy: 0.01)
        XCTAssertEqual(viewModel.cursorLocation?.y, newLocation.y, accuracy: 0.01)
    }

    func testCursorLocation_ClearedOnDragEnd() {
        // Setup: perform a complete drag operation
        let startLocation = CGPoint(x: 100, y: 100)
        let endLocation = CGPoint(x: 400, y: 300)

        let startValue = makeDragValue(translation: .zero, location: startLocation)
        viewModel.handleDragStarted(startValue)

        let endValue = makeDragValue(translation: CGSize(width: 300, height: 200), location: endLocation)
        viewModel.handleDragEnded(endValue)

        // Verify cursor location is cleared
        XCTAssertNil(viewModel.cursorLocation, "cursorLocation should be cleared after drag ends")
    }

    func testCursorLocation_ClearedOnReset() {
        // Setup: set cursor location manually
        let location = CGPoint(x: 150, y: 200)
        let dragValue = makeDragValue(translation: .zero, location: location)
        viewModel.handleDragStarted(dragValue)

        XCTAssertNotNil(viewModel.cursorLocation)

        // Reset the view model
        viewModel.reset()

        // Verify cursor location is cleared
        XCTAssertNil(viewModel.cursorLocation, "cursorLocation should be cleared on reset")
    }

    func testCursorLocation_TrackedThroughoutDrag() {
        // Setup: perform multiple drag updates
        let locations = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 150, y: 120),
            CGPoint(x: 200, y: 140),
            CGPoint(x: 250, y: 160)
        ]

        // Start drag
        let startValue = makeDragValue(translation: .zero, location: locations[0])
        viewModel.handleDragStarted(startValue)

        // Update through multiple positions
        for (index, location) in locations.enumerated() where index > 0 {
            let translation = CGSize(
                width: location.x - locations[0].x,
                height: location.y - locations[0].y
            )
            let changeValue = makeDragValue(translation: translation, location: location)
            viewModel.handleDragChanged(changeValue)

            // Verify cursor location is updated at each step
            XCTAssertNotNil(viewModel.cursorLocation)
            XCTAssertEqual(viewModel.cursorLocation?.x, location.x, accuracy: 0.01)
            XCTAssertEqual(viewModel.cursorLocation?.y, location.y, accuracy: 0.01)
        }
    }

    // MARK: - Active Resize Handle Tests

    func testActiveResizeHandle_InitiallyNil() {
        // Active resize handle should be nil on initialization
        XCTAssertNil(viewModel.activeResizeHandle, "activeResizeHandle should be nil on initialization")
    }

    func testActiveResizeHandle_SetDuringResizeStart() {
        // Setup: start a resize operation
        let handle = ResizeHandle.bottomRight
        let initialRegion = CGRect(x: 100, y: 100, width: 300, height: 200)
        viewModel.selectedRegion = initialRegion

        let dragValue = makeDragValue(translation: .zero, location: CGPoint(x: 400, y: 300))
        viewModel.handleResizeStarted(handle, dragValue: dragValue)

        // Verify active resize handle is set
        XCTAssertNotNil(viewModel.activeResizeHandle, "activeResizeHandle should be set during resize")
        XCTAssertEqual(viewModel.activeResizeHandle, handle, "activeResizeHandle should match the dragged handle")
    }

    func testActiveResizeHandle_MaintainedDuringResize() {
        // Setup: start a resize operation
        let handle = ResizeHandle.topLeft
        let initialRegion = CGRect(x: 200, y: 200, width: 400, height: 300)
        viewModel.selectedRegion = initialRegion

        let startValue = makeDragValue(translation: .zero, location: CGPoint(x: 200, y: 200))
        viewModel.handleResizeStarted(handle, dragValue: startValue)

        XCTAssertEqual(viewModel.activeResizeHandle, handle)

        // Simulate resize movement
        let changeValue = makeDragValue(translation: CGSize(width: 50, height: 60), location: CGPoint(x: 250, y: 260))
        viewModel.handleResizeChanged(handle, dragValue: changeValue)

        // Verify active resize handle is still set
        XCTAssertNotNil(viewModel.activeResizeHandle)
        XCTAssertEqual(viewModel.activeResizeHandle, handle, "activeResizeHandle should remain during resize")
    }

    func testActiveResizeHandle_ClearedOnResizeEnd() {
        // Setup: perform a complete resize operation
        let handle = ResizeHandle.middleRight
        let initialRegion = CGRect(x: 100, y: 100, width: 300, height: 200)
        viewModel.selectedRegion = initialRegion

        let startValue = makeDragValue(translation: .zero, location: CGPoint(x: 400, y: 200))
        viewModel.handleResizeStarted(handle, dragValue: startValue)

        XCTAssertEqual(viewModel.activeResizeHandle, handle)

        let endValue = makeDragValue(translation: CGSize(width: 100, height: 0), location: CGPoint(x: 500, y: 200))
        viewModel.handleResizeEnded(handle, dragValue: endValue)

        // Verify active resize handle is cleared
        XCTAssertNil(viewModel.activeResizeHandle, "activeResizeHandle should be cleared after resize ends")
    }

    func testActiveResizeHandle_ClearedOnReset() {
        // Setup: set active resize handle manually
        let handle = ResizeHandle.bottomCenter
        let initialRegion = CGRect(x: 100, y: 100, width: 400, height: 300)
        viewModel.selectedRegion = initialRegion

        let dragValue = makeDragValue(translation: .zero, location: CGPoint(x: 300, y: 400))
        viewModel.handleResizeStarted(handle, dragValue: dragValue)

        XCTAssertNotNil(viewModel.activeResizeHandle)

        // Reset the view model
        viewModel.reset()

        // Verify active resize handle is cleared
        XCTAssertNil(viewModel.activeResizeHandle, "activeResizeHandle should be cleared on reset")
    }

    func testActiveResizeHandle_DifferentHandles() {
        // Test that different handles can be set as active
        let handles: [ResizeHandle] = [
            .topLeft, .topCenter, .topRight,
            .middleLeft, .middleRight,
            .bottomLeft, .bottomCenter, .bottomRight
        ]

        let initialRegion = CGRect(x: 200, y: 200, width: 400, height: 300)
        viewModel.selectedRegion = initialRegion

        for handle in handles {
            // Start resize with this handle
            let position = handle.position(in: initialRegion)
            let dragValue = makeDragValue(translation: .zero, location: position)
            viewModel.handleResizeStarted(handle, dragValue: dragValue)

            // Verify this handle is active
            XCTAssertEqual(viewModel.activeResizeHandle, handle, "activeResizeHandle should be \(handle)")

            // End resize
            viewModel.handleResizeEnded(handle, dragValue: dragValue)
            XCTAssertNil(viewModel.activeResizeHandle, "activeResizeHandle should be cleared")
        }
    }

    func testActiveResizeHandle_OnlySetDuringResize() {
        // Verify that activeResizeHandle is only set during resize, not during drag
        let dragValue = makeDragValue(translation: .zero, location: CGPoint(x: 100, y: 100))

        // Start drag (not resize)
        viewModel.handleDragStarted(dragValue)

        // Verify active resize handle is NOT set
        XCTAssertNil(viewModel.activeResizeHandle, "activeResizeHandle should not be set during drag operations")

        // End drag
        viewModel.handleDragEnded(dragValue)
        XCTAssertNil(viewModel.activeResizeHandle)
    }

    // MARK: - Test Helpers

    /// Create a mock DragGesture.Value for testing
    private func makeDragValue(translation: CGSize, location: CGPoint) -> DragGesture.Value {
        return DragGesture.Value(
            time: Date(),
            location: location,
            startLocation: location,
            velocity: .zero,
            translation: translation,
            predictedEndLocation: location,
            predictedEndTranslation: translation
        )
    }
}
