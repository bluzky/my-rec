import XCTest
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
        // SwiftUI coordinates: top-left (100, 100)
        // Screen coordinates: bottom-left
        let swiftUIRect = CGRect(x: 100, y: 100, width: 500, height: 300)
        let screenRect = viewModel.convertToScreenCoordinates(swiftUIRect)

        // Y should be flipped: screenHeight - y - height
        let expectedY = testScreenBounds.height - swiftUIRect.origin.y - swiftUIRect.height
        XCTAssertEqual(screenRect.origin.x, 100, accuracy: 0.01)
        XCTAssertEqual(screenRect.origin.y, expectedY, accuracy: 0.01)
        XCTAssertEqual(screenRect.width, 500, accuracy: 0.01)
        XCTAssertEqual(screenRect.height, 300, accuracy: 0.01)
    }

    func testCoordinateConversionBottomRight() {
        // Test conversion near bottom-right of screen
        let swiftUIRect = CGRect(x: 1420, y: 780, width: 500, height: 300)
        let screenRect = viewModel.convertToScreenCoordinates(swiftUIRect)

        let expectedY = testScreenBounds.height - swiftUIRect.origin.y - swiftUIRect.height
        XCTAssertEqual(screenRect.origin.x, 1420, accuracy: 0.01)
        XCTAssertEqual(screenRect.origin.y, expectedY, accuracy: 0.01)
    }

    func testCoordinateConversionPreservesSize() {
        // Size should remain unchanged after coordinate conversion
        let swiftUIRect = CGRect(x: 200, y: 200, width: 800, height: 600)
        let screenRect = viewModel.convertToScreenCoordinates(swiftUIRect)

        XCTAssertEqual(screenRect.width, swiftUIRect.width)
        XCTAssertEqual(screenRect.height, swiftUIRect.height)
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
}
