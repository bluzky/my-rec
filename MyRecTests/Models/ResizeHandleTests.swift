import XCTest
@testable import MyRecCore

class ResizeHandleTests: XCTestCase {

    // MARK: - isCorner Tests

    func testIsCorner_AllCornerHandlesReturnTrue() {
        // All corner handles should return true
        XCTAssertTrue(ResizeHandle.topLeft.isCorner, "topLeft should be a corner")
        XCTAssertTrue(ResizeHandle.topRight.isCorner, "topRight should be a corner")
        XCTAssertTrue(ResizeHandle.bottomLeft.isCorner, "bottomLeft should be a corner")
        XCTAssertTrue(ResizeHandle.bottomRight.isCorner, "bottomRight should be a corner")
    }

    func testIsCorner_AllEdgeHandlesReturnFalse() {
        // All edge handles should return false
        XCTAssertFalse(ResizeHandle.topCenter.isCorner, "topCenter should not be a corner")
        XCTAssertFalse(ResizeHandle.middleLeft.isCorner, "middleLeft should not be a corner")
        XCTAssertFalse(ResizeHandle.middleRight.isCorner, "middleRight should not be a corner")
        XCTAssertFalse(ResizeHandle.bottomCenter.isCorner, "bottomCenter should not be a corner")
    }

    func testIsCorner_ExhaustiveCheck() {
        // Verify all cases are covered
        let cornerHandles: [ResizeHandle] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        let edgeHandles: [ResizeHandle] = [.topCenter, .middleLeft, .middleRight, .bottomCenter]

        // All ResizeHandle cases should be either corner or edge
        let allHandles = Set(ResizeHandle.allCases)
        let categorizedHandles = Set(cornerHandles + edgeHandles)

        XCTAssertEqual(allHandles, categorizedHandles, "All ResizeHandle cases should be categorized as either corner or edge")
    }

    // MARK: - isEdge Tests

    func testIsEdge_AllEdgeHandlesReturnTrue() {
        // All edge handles should return true
        XCTAssertTrue(ResizeHandle.topCenter.isEdge, "topCenter should be an edge")
        XCTAssertTrue(ResizeHandle.middleLeft.isEdge, "middleLeft should be an edge")
        XCTAssertTrue(ResizeHandle.middleRight.isEdge, "middleRight should be an edge")
        XCTAssertTrue(ResizeHandle.bottomCenter.isEdge, "bottomCenter should be an edge")
    }

    func testIsEdge_AllCornerHandlesReturnFalse() {
        // All corner handles should return false
        XCTAssertFalse(ResizeHandle.topLeft.isEdge, "topLeft should not be an edge")
        XCTAssertFalse(ResizeHandle.topRight.isEdge, "topRight should not be an edge")
        XCTAssertFalse(ResizeHandle.bottomLeft.isEdge, "bottomLeft should not be an edge")
        XCTAssertFalse(ResizeHandle.bottomRight.isEdge, "bottomRight should not be an edge")
    }

    func testIsEdge_MutuallyExclusiveWithIsCorner() {
        // Every handle should be either a corner OR an edge, never both, never neither
        for handle in ResizeHandle.allCases {
            let isCorner = handle.isCorner
            let isEdge = handle.isEdge

            // XOR: exactly one should be true
            XCTAssertTrue(isCorner != isEdge, "\(handle) should be either a corner or an edge, not both or neither")
        }
    }

    // MARK: - Cursor Tests

    func testCursor_AllHandlesHaveCursor() {
        // Verify all handles return a cursor (no crashes)
        for handle in ResizeHandle.allCases {
            _ = handle.cursor
        }
    }

    func testCursor_VerticalEdgesHaveLeftRightCursor() {
        XCTAssertEqual(ResizeHandle.middleLeft.cursor, NSCursor.resizeLeftRight, "middleLeft should use left-right resize cursor")
        XCTAssertEqual(ResizeHandle.middleRight.cursor, NSCursor.resizeLeftRight, "middleRight should use left-right resize cursor")
    }

    func testCursor_HorizontalEdgesHaveUpDownCursor() {
        XCTAssertEqual(ResizeHandle.topCenter.cursor, NSCursor.resizeUpDown, "topCenter should use up-down resize cursor")
        XCTAssertEqual(ResizeHandle.bottomCenter.cursor, NSCursor.resizeUpDown, "bottomCenter should use up-down resize cursor")
    }

    // MARK: - Position Tests

    func testPosition_TopLeftCorner() {
        let region = CGRect(x: 100, y: 200, width: 300, height: 400)
        let position = ResizeHandle.topLeft.position(in: region)

        XCTAssertEqual(position.x, region.minX, accuracy: 0.01)
        XCTAssertEqual(position.y, region.minY, accuracy: 0.01)
    }

    func testPosition_TopRightCorner() {
        let region = CGRect(x: 100, y: 200, width: 300, height: 400)
        let position = ResizeHandle.topRight.position(in: region)

        XCTAssertEqual(position.x, region.maxX, accuracy: 0.01)
        XCTAssertEqual(position.y, region.minY, accuracy: 0.01)
    }

    func testPosition_BottomLeftCorner() {
        let region = CGRect(x: 100, y: 200, width: 300, height: 400)
        let position = ResizeHandle.bottomLeft.position(in: region)

        XCTAssertEqual(position.x, region.minX, accuracy: 0.01)
        XCTAssertEqual(position.y, region.maxY, accuracy: 0.01)
    }

    func testPosition_BottomRightCorner() {
        let region = CGRect(x: 100, y: 200, width: 300, height: 400)
        let position = ResizeHandle.bottomRight.position(in: region)

        XCTAssertEqual(position.x, region.maxX, accuracy: 0.01)
        XCTAssertEqual(position.y, region.maxY, accuracy: 0.01)
    }

    func testPosition_TopCenterEdge() {
        let region = CGRect(x: 100, y: 200, width: 300, height: 400)
        let position = ResizeHandle.topCenter.position(in: region)

        XCTAssertEqual(position.x, region.midX, accuracy: 0.01)
        XCTAssertEqual(position.y, region.minY, accuracy: 0.01)
    }

    func testPosition_BottomCenterEdge() {
        let region = CGRect(x: 100, y: 200, width: 300, height: 400)
        let position = ResizeHandle.bottomCenter.position(in: region)

        XCTAssertEqual(position.x, region.midX, accuracy: 0.01)
        XCTAssertEqual(position.y, region.maxY, accuracy: 0.01)
    }

    func testPosition_MiddleLeftEdge() {
        let region = CGRect(x: 100, y: 200, width: 300, height: 400)
        let position = ResizeHandle.middleLeft.position(in: region)

        XCTAssertEqual(position.x, region.minX, accuracy: 0.01)
        XCTAssertEqual(position.y, region.midY, accuracy: 0.01)
    }

    func testPosition_MiddleRightEdge() {
        let region = CGRect(x: 100, y: 200, width: 300, height: 400)
        let position = ResizeHandle.middleRight.position(in: region)

        XCTAssertEqual(position.x, region.maxX, accuracy: 0.01)
        XCTAssertEqual(position.y, region.midY, accuracy: 0.01)
    }

    // MARK: - Hashable Tests

    func testHashable_SameHandlesHaveSameHash() {
        let handle1 = ResizeHandle.topLeft
        let handle2 = ResizeHandle.topLeft

        XCTAssertEqual(handle1.hashValue, handle2.hashValue, "Same handles should have same hash")
    }

    func testHashable_DifferentHandlesHaveDifferentHash() {
        let uniqueHashes = Set(ResizeHandle.allCases.map { $0.hashValue })

        XCTAssertEqual(uniqueHashes.count, ResizeHandle.allCases.count, "All handles should have unique hashes")
    }

    func testHashable_CanBeUsedInSet() {
        let handleSet: Set<ResizeHandle> = [.topLeft, .topRight, .topLeft]

        XCTAssertEqual(handleSet.count, 2, "Set should deduplicate handles")
        XCTAssertTrue(handleSet.contains(.topLeft))
        XCTAssertTrue(handleSet.contains(.topRight))
    }
}
