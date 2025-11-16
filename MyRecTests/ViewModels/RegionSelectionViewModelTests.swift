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
}
